<?php
// hanapp_backend/api/chat/send_message.php
// Inserts a new message into a conversation.

// --- DEBUGGING ---
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
// --- END DEBUGGING ---

require_once '../config/db_connect.php';

// Set MySQL session timezone to Asia/Manila for this script only
$conn->query("SET time_zone = '+08:00'");

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    if (!isset($conn) || $conn->connect_error) {
        error_log("send_message.php: Database connection not established: " . ($conn->connect_error ?? 'Unknown error'), 0);
        if (ob_get_length()) ob_clean();
        echo json_encode(["success" => false, "message" => "Database connection not established. Please check server logs."]);
        exit();
    }

    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log("send_message.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        if (ob_get_length()) ob_clean();
        echo json_encode(["success" => false, "message" => "Invalid JSON payload."]);
        exit();
    }

    $conversationId = $data['conversation_id'] ?? null;
    $senderId = $data['sender_id'] ?? null;
    $receiverId = $data['receiver_id'] ?? null;
    $content = $data['message_content'] ?? null;
    $messageType = $data['message_type'] ?? 'text';
    $locationData = $data['location_data'] ?? null;
    $listingTitle = $data['listing_title'] ?? null;
    $conversationListerId = $data['conversation_lister_id'] ?? null;
    $conversationDoerId = $data['conversation_doer_id'] ?? null;
    $applicationId = $data['application_id'] ?? null;

    if (empty($conversationId) || !is_numeric($conversationId) ||
        empty($senderId) || !is_numeric($senderId) ||
        empty($receiverId) || !is_numeric($receiverId) ||
        empty($content))
    {
        error_log("send_message.php: Validation failed - Missing or invalid required fields. Data: " . json_encode($data), 0);
        if (ob_get_length()) ob_clean();
        echo json_encode(["success" => false, "message" => "Conversation ID, Sender ID, Receiver ID, and Content are required."]);
        exit();
    }

    $conn->begin_transaction();

    // Set timezone to Philippines time
    date_default_timezone_set('Asia/Manila');

    // Debug log: PHP timezone and current time
    error_log('PHP timezone: ' . date_default_timezone_get() . ' | PHP time: ' . date('Y-m-d H:i:s'), 0);

    // Get current timestamp in +08:00
    $currentTimestamp = date('Y-m-d H:i:s');

    // Prepare location data for storage if it exists
    $serializedLocationData = null;
    if ($locationData !== null && is_array($locationData)) {
        $serializedLocationData = json_encode($locationData);
        if (json_last_error() !== JSON_ERROR_NONE) {
            error_log("send_message.php: JSON encode error for location_data: " . json_last_error_msg(), 0);
            $serializedLocationData = null; // Revert to null if encoding fails
        }
    }

    // Insert into messagesv2 table with explicit UTC timestamp
    $insertStmt = $conn->prepare("INSERT INTO messagesv2 (conversation_id, sender_id, receiver_id, content, sent_at, type, extra_data) VALUES (?, ?, ?, ?, ?, ?, ?)");
    if ($insertStmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $insertStmt->bind_param("iiissss", $conversationId, $senderId, $receiverId, $content, $currentTimestamp, $messageType, $serializedLocationData);

    if (!$insertStmt->execute()) {
        throw new Exception("Failed to send message: " . $insertStmt->error);
    }

    $newMessageId = $conn->insert_id;

    // Update last_message_at in conversationsv2 table with same UTC timestamp
    $updateConvStmt = $conn->prepare("UPDATE conversationsv2 SET last_message_at = ? WHERE id = ?");
    if ($updateConvStmt === false) {
        throw new Exception("Failed to prepare conversation update statement: " . $conn->error);
    }
    $updateConvStmt->bind_param("si", $currentTimestamp, $conversationId);
    $updateConvStmt->execute();
    $updateConvStmt->close();

    $conn->commit();

    // Create notification for the receiver
    try {
        // Get sender's name for the notification
        $senderName = '';
        $senderStmt = $conn->prepare("SELECT full_name FROM users WHERE id = ?");
        if ($senderStmt) {
            $senderStmt->bind_param("i", $senderId);
            $senderStmt->execute();
            $senderResult = $senderStmt->get_result();
            if ($senderRow = $senderResult->fetch_assoc()) {
                $senderName = $senderRow['full_name'];
            }
            $senderStmt->close();
        }

        // Get receiver's role to determine which notification table to use
        $receiverRole = '';
        $roleStmt = $conn->prepare("SELECT role FROM users WHERE id = ?");
        if ($roleStmt) {
            $roleStmt->bind_param("i", $receiverId);
            $roleStmt->execute();
            $roleResult = $roleStmt->get_result();
            if ($roleRow = $roleResult->fetch_assoc()) {
                $receiverRole = $roleRow['role'];
            }
            $roleStmt->close();
        }

        // Prepare notification data
        $notificationTitle = "New Message";
        $notificationContent = "$senderName sent you a message";
        $notificationType = "message";

        if ($receiverRole === 'doer') {
            // Insert into doer_notifications table
            $doerNotificationSql = "
                INSERT INTO doer_notifications (
                    user_id, sender_id, type, title, content, associated_id,
                    conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                    related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            ";
            
            $doerNotificationStmt = $conn->prepare($doerNotificationSql);
            if ($doerNotificationStmt) {
                $doerNotificationStmt->bind_param("iisssiiissiiss",
                    $receiverId,           // user_id (receiver)
                    $senderId,              // sender_id
                    $notificationType,      // type
                    $notificationTitle,     // title
                    $notificationContent,   // content
                    $newMessageId,          // associated_id (message_id)
                    $conversationId,        // conversation_id_for_chat_nav
                    $conversationListerId,  // conversation_lister_id
                    $conversationDoerId,    // conversation_doer_id
                    $listingTitle,          // related_listing_title
                    null,                   // listing_id
                    null,                   // listing_type
                    null,                   // lister_id
                    null                    // lister_name
                );
                
                $doerNotificationStmt->execute();
                $doerNotificationStmt->close();
                error_log("send_message.php: Doer notification created for user $receiverId", 0);
            }
        } else {
            // Insert into notificationsv2 table for lister or other roles
            $listerNotificationSql = "
                INSERT INTO notificationsv2 (
                    user_id, sender_id, type, title, content, associated_id,
                    conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                    related_listing_title, is_read
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            ";
            
            $listerNotificationStmt = $conn->prepare($listerNotificationSql);
            if ($listerNotificationStmt) {
                $listerNotificationStmt->bind_param("iisssiiiss",
                    $receiverId,           // user_id (receiver)
                    $senderId,              // sender_id
                    $notificationType,      // type
                    $notificationTitle,     // title
                    $notificationContent,   // content
                    $newMessageId,          // associated_id (message_id)
                    $conversationId,        // conversation_id_for_chat_nav
                    $conversationListerId,  // conversation_lister_id
                    $conversationDoerId,    // conversation_doer_id
                    $listingTitle           // related_listing_title
                );
                
                $listerNotificationStmt->execute();
                $listerNotificationStmt->close();
                error_log("send_message.php: Lister notification created for user $receiverId", 0);
            }
        }
    } catch (Exception $notificationError) {
        // Log notification error but don't fail the message send
        error_log("send_message.php: Failed to create notification: " . $notificationError->getMessage(), 0);
    }

    if (ob_get_length()) ob_clean();
    echo json_encode([
        "success" => true, 
        "message" => "Message sent successfully.", 
        "message_id" => $newMessageId,
        "timestamp" => $currentTimestamp
    ]);

    $insertStmt->close();

} catch (Exception $e) {
    if (isset($conn) && $conn instanceof mysqli && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("send_message.php: Caught exception: " . $e->getMessage(), 0);
    if (ob_get_length()) ob_clean();
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 