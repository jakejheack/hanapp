<?php
// hanapp_backend/api/applications/create_application.php
// Handles the creation of a new application for a listing.

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

require_once '../config/db_connect.php'; // Adjust path

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
        error_log("create_application.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        throw new Exception("Invalid JSON payload.");
    }

    // Extracting data from the payload
    $listingId = $data['listing_id'] ?? null;
    $listingType = $data['listing_type'] ?? null; // CORRECTLY EXTRACTING listing_type
    $listerId = $data['lister_id'] ?? null;
    $doerId = $data['doer_id'] ?? null;
    $message = $data['message'] ?? ''; // Message can be empty
    $listingTitle = $data['listing_title'] ?? null;

    // Basic validation
    if (empty($listingId) || !is_numeric($listingId)) {
        throw new Exception("Listing ID is required and must be numeric.");
    }
    if (empty($listingType)) { // Ensure listing_type is not empty
        throw new Exception("Listing Type is required.");
    }
    if (empty($listerId) || !is_numeric($listerId)) {
        throw new Exception("Lister ID is required and must be numeric.");
    }
    if (empty($doerId) || !is_numeric($doerId)) {
        throw new Exception("Doer ID is required and must be numeric.");
    }
    if (empty($listingTitle)) {
        throw new Exception("Listing Title is required.");
    }

    $conn->begin_transaction();

    // Check if an application already exists for this doer and listing (including listing_type)
    $check_stmt = $conn->prepare("SELECT id FROM applicationsv2 WHERE listing_id = ? AND doer_id = ? AND listing_type = ?");
    if ($check_stmt === false) {
        throw new Exception("Failed to prepare check statement: " . $conn->error);
    }
    $check_stmt->bind_param("iis", $listingId, $doerId, $listingType);
    $check_stmt->execute();
    $check_stmt->store_result();

    if ($check_stmt->num_rows > 0) {
        throw new Exception("You have already applied for this listing.");
    }
    $check_stmt->close();

    // Insert new application
    $stmt = $conn->prepare("
        INSERT INTO applicationsv2 (
            listing_id, listing_type, lister_id, doer_id, listing_title, message, applied_at, status
        ) VALUES (?, ?, ?, ?, ?, ?, NOW(), 'pending')
    ");
    if ($stmt === false) {
        throw new Exception("Failed to prepare insert statement: " . $conn->error);
    }

    // IMPORTANT: 's' for listing_type (string)
    $stmt->bind_param("isisss", $listingId, $listingType, $listerId, $doerId, $listingTitle, $message);

    if (!$stmt->execute()) {
        throw new Exception("Failed to create application: " . $stmt->error);
    }

    $applicationId = $conn->insert_id; // Get the ID of the newly inserted application

    $stmt->close();

    // Create or get conversation for this listing/lister/doer pair
    $convSql = "
        SELECT id FROM conversationsv2
        WHERE listing_id = ? AND listing_type = ? AND lister_id = ? AND doer_id = ?
    ";
    $convStmt = $conn->prepare($convSql);
    $conversationId = null;
    
    if ($convStmt === false) {
        error_log("create_application.php: Failed to prepare conversation check statement: " . $conn->error, 0);
        // Try to create a new conversation anyway
        $insertConvSql = "
            INSERT INTO conversationsv2 (listing_id, listing_type, lister_id, doer_id, created_at, last_message_at)
            VALUES (?, ?, ?, ?, NOW(), NOW())
        ";
        $insertConvStmt = $conn->prepare($insertConvSql);
        if ($insertConvStmt === false) {
            error_log("create_application.php: Failed to prepare conversation insert statement: " . $conn->error, 0);
        } else {
            $insertConvStmt->bind_param("isii", $listingId, $listingType, $listerId, $doerId);
            if (!$insertConvStmt->execute()) {
                error_log("create_application.php: Failed to create conversation: " . $insertConvStmt->error, 0);
            } else {
                $conversationId = $conn->insert_id;
                error_log("create_application.php: Created new conversation with ID: $conversationId", 0);
            }
            $insertConvStmt->close();
        }
    } else {
        $convStmt->bind_param("isii", $listingId, $listingType, $listerId, $doerId);
        $convStmt->execute();
        $convResult = $convStmt->get_result();

        if ($convResult->num_rows > 0) {
            $conversationId = $convResult->fetch_assoc()['id'];
            error_log("create_application.php: Found existing conversation with ID: $conversationId", 0);
        } else {
            $insertConvSql = "
                INSERT INTO conversationsv2 (listing_id, listing_type, lister_id, doer_id, created_at, last_message_at)
                VALUES (?, ?, ?, ?, NOW(), NOW())
            ";
            $insertConvStmt = $conn->prepare($insertConvSql);
            if ($insertConvStmt === false) {
                error_log("create_application.php: Failed to prepare conversation insert statement: " . $conn->error, 0);
            } else {
                $insertConvStmt->bind_param("isii", $listingId, $listingType, $listerId, $doerId);
                if (!$insertConvStmt->execute()) {
                    error_log("create_application.php: Failed to create conversation: " . $insertConvStmt->error, 0);
                } else {
                    $conversationId = $conn->insert_id;
                    error_log("create_application.php: Created new conversation with ID: $conversationId", 0);
                }
                $insertConvStmt->close();
            }
        }
        $convStmt->close();
    }

    // Link conversation_id to application
    if ($conversationId) {
        error_log("create_application.php: Conversation ID exists ($conversationId), proceeding with message sending", 0);
        
        $updateAppSql = "UPDATE applicationsv2 SET conversation_id = ? WHERE id = ?";
        $updateAppStmt = $conn->prepare($updateAppSql);
        if ($updateAppStmt === false) {
            error_log("create_application.php: Failed to prepare application conversation update statement: " . $conn->error, 0);
        } else {
            $updateAppStmt->bind_param("ii", $conversationId, $applicationId);
            if (!$updateAppStmt->execute()) {
                error_log("create_application.php: Failed to link conversation to application: " . $updateAppStmt->error, 0);
            } else {
                error_log("create_application.php: Successfully linked conversation $conversationId to application $applicationId", 0);
            }
            $updateAppStmt->close();
        }
        
        // Send automatic message to lister when doer applies
        $autoMessageContent = $message ?: "I'm interested in your $listingTitle. Please let me know if you'd like to proceed.";
        error_log("create_application.php: Preparing to send auto message: '$autoMessageContent'", 0);
        
        $autoMessageSql = "
            INSERT INTO messagesv2 (
                conversation_id, sender_id, receiver_id, content, type, sent_at, extra_data
            ) VALUES (?, ?, ?, ?, 'text', NOW(), ?)
        ";
        
        // Store additional data in extra_data as JSON
        $extraData = json_encode([
            'listing_title' => $listingTitle,
            'conversation_lister_id' => $listerId,
            'conversation_doer_id' => $doerId,
            'application_id' => $applicationId
        ]);
        
        $autoMessageStmt = $conn->prepare($autoMessageSql);
        if ($autoMessageStmt === false) {
            error_log("create_application.php: Failed to prepare auto message insert statement: " . $conn->error, 0);
        } else {
            $autoMessageStmt->bind_param("iiiss", 
                $conversationId,     // conversation_id
                $doerId,             // sender_id (doer)
                $listerId,           // receiver_id (lister)
                $autoMessageContent, // content
                $extraData           // extra_data
            );
            
            if (!$autoMessageStmt->execute()) {
                error_log("create_application.php: Failed to insert auto message: " . $autoMessageStmt->error, 0);
            } else {
                error_log("create_application.php: Auto message sent successfully from doer $doerId to lister $listerId", 0);
            }
            $autoMessageStmt->close();
        }
    } else {
        error_log("create_application.php: No conversation ID available, skipping message sending", 0);
    }

    // Get doer's full name for notification
    $senderFullName = '';
    $doerInfoStmt = $conn->prepare("SELECT full_name FROM users WHERE id = ?");
    if ($doerInfoStmt === false) {
        error_log("create_application.php: Failed to prepare doer info statement: " . $conn->error, 0);
    } else {
        $doerInfoStmt->bind_param("i", $doerId);
        $doerInfoStmt->execute();
        $doerInfoResult = $doerInfoStmt->get_result();
        if ($doerInfoRow = $doerInfoResult->fetch_assoc()) {
            $senderFullName = $doerInfoRow['full_name'];
        }
        $doerInfoStmt->close();
    }

    // Create notification for the lister with all fields
    $notificationTitle = "New Application";
    $notificationContent = "$senderFullName applied for your $listingTitle. Click here to view.";
    $notificationType = "application";
    
    $notificationSql = "
        INSERT INTO notificationsv2 (
            user_id, sender_id, type, title, content, associated_id, 
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id, 
            related_listing_title, is_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ";
    
    $notificationStmt = $conn->prepare($notificationSql);
    if ($notificationStmt === false) {
        error_log("create_application.php: Failed to prepare notification insert statement: " . $conn->error, 0);
        // Don't throw exception here as the application was successful
    } else {
        $notificationStmt->bind_param("iisssiiiss", 
            $listerId,           // user_id (lister)
            $doerId,             // sender_id (doer)
            $notificationType,   // type
            $notificationTitle,  // title
            $notificationContent, // content
            $applicationId,      // associated_id
            $conversationId,     // conversation_id_for_chat_nav
            $listerId,           // conversation_lister_id
            $doerId,             // conversation_doer_id
            $listingTitle        // related_listing_title
        );
        
        if (!$notificationStmt->execute()) {
            error_log("create_application.php: Failed to insert notification: " . $notificationStmt->error, 0);
            // Don't throw exception here as the application was successful
        } else {
            error_log("create_application.php: Notification inserted successfully for lister $listerId", 0);
        }
        $notificationStmt->close();
    }

    // Create notification in doer_notifications table
    $doerNotificationTitle = "Application Submitted";
    $doerNotificationContent = "You applied to $listingTitle.";
    $doerNotificationType = "application_submitted";
    
    // Get lister's name for the doer notification
    $listerName = '';
    $listerInfoStmt = $conn->prepare("SELECT full_name FROM users WHERE id = ?");
    if ($listerInfoStmt === false) {
        error_log("create_application.php: Failed to prepare lister info statement: " . $conn->error, 0);
    } else {
        $listerInfoStmt->bind_param("i", $listerId);
        $listerInfoStmt->execute();
        $listerInfoResult = $listerInfoStmt->get_result();
        if ($listerInfoRow = $listerInfoResult->fetch_assoc()) {
            $listerName = $listerInfoRow['full_name'];
        }
        $listerInfoStmt->close();
    }
    
    $doerNotificationSql = "
        INSERT INTO doer_notifications (
            user_id, sender_id, type, title, content, associated_id, 
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id, 
            related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ";
    
    $doerNotificationStmt = $conn->prepare($doerNotificationSql);
    if ($doerNotificationStmt === false) {
        error_log("create_application.php: Failed to prepare doer_notifications insert statement: " . $conn->error, 0);
        // Don't throw exception here as the application was successful
    } else {
        $doerNotificationStmt->bind_param("iisssiiissiiss", 
            $doerId,             // user_id (doer - receives notification)
            $doerId,             // sender_id (doer - sent the application)
            $doerNotificationType,   // type
            $doerNotificationTitle,  // title
            $doerNotificationContent, // content
            $applicationId,      // associated_id
            $conversationId,     // conversation_id_for_chat_nav
            $listerId,           // conversation_lister_id
            $doerId,             // conversation_doer_id
            $listingTitle,       // related_listing_title
            $listingId,          // listing_id
            $listingType,        // listing_type
            $listerId,           // lister_id
            $listerName          // lister_name
        );
        
        if (!$doerNotificationStmt->execute()) {
            error_log("create_application.php: Failed to insert doer_notifications: " . $doerNotificationStmt->error, 0);
            // Don't throw exception here as the application was successful
        } else {
            error_log("create_application.php: Doer notification inserted successfully in doer_notifications for doer $doerId", 0);
        }
        $doerNotificationStmt->close();
    }

    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "Application submitted successfully!",
        "application_id" => $applicationId // Return the new application ID
    ]);

} catch (Exception $e) {
    if (isset($conn) && $conn instanceof mysqli && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("create_application.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to submit application: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 