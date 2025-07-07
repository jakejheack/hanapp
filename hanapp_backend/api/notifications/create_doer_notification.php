<?php
// hanapp_backend/api/notifications/create_doer_notification.php
// Creates notifications for doers in the doer_notifications table

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

require_once '../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log("create_doer_notification.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        throw new Exception("Invalid JSON payload.");
    }

    // Extract data from payload
    $userId = $data['user_id'] ?? null;
    $senderId = $data['sender_id'] ?? null;
    $type = $data['type'] ?? null;
    $title = $data['title'] ?? null;
    $content = $data['content'] ?? null;
    $associatedId = $data['associated_id'] ?? null;
    $conversationId = $data['conversation_id_for_chat_nav'] ?? null;
    $conversationListerId = $data['conversation_lister_id'] ?? null;
    $conversationDoerId = $data['conversation_doer_id'] ?? null;
    $relatedListingTitle = $data['related_listing_title'] ?? null;
    $listingId = $data['listing_id'] ?? null;
    $listingType = $data['listing_type'] ?? null;
    $listerId = $data['lister_id'] ?? null;
    $listerName = $data['lister_name'] ?? null;

    // Validation
    if (empty($userId) || !is_numeric($userId)) {
        throw new Exception("User ID is required and must be numeric.");
    }
    if (empty($type)) {
        throw new Exception("Notification type is required.");
    }
    if (empty($title)) {
        throw new Exception("Notification title is required.");
    }
    if (empty($content)) {
        throw new Exception("Notification content is required.");
    }

    $sql = "
        INSERT INTO doer_notifications (
            user_id, sender_id, type, title, content, associated_id,
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
            related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ";

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $stmt->bind_param("iisssiiissiiss",
        $userId,
        $senderId,
        $type,
        $title,
        $content,
        $associatedId,
        $conversationId,
        $conversationListerId,
        $conversationDoerId,
        $relatedListingTitle,
        $listingId,
        $listingType,
        $listerId,
        $listerName
    );

    if (!$stmt->execute()) {
        throw new Exception("Failed to create notification: " . $stmt->error);
    }

    $notificationId = $conn->insert_id;
    $stmt->close();

    echo json_encode([
        "success" => true,
        "message" => "Notification created successfully",
        "notification_id" => $notificationId
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("create_doer_notification.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to create notification: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 