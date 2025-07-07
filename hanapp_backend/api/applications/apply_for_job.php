<?php
// hanapp_backend/api/applications/apply_for_job.php
// Handles a Doer applying for a job listing, inserts lister_id, listing_title, and creates a notification.

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

require_once '../db_connect.php';

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
        error_log("apply_for_job.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        throw new Exception("Invalid JSON payload.");
    }

    $listingId = $data['listing_id'] ?? null;
    $listingType = $data['listing_type'] ?? null;
    $listerId = $data['lister_id'] ?? null;
    $doerId = $data['doer_id'] ?? null;
    $message = $data['message'] ?? '';
    $listingTitle = $data['listing_title'] ?? null;

    // Debug logging
    error_log("DEBUG apply_for_job.php: Raw input data: " . $input, 0);

    // Basic validation
    if (empty($listingId) || !is_numeric($listingId) ||
        empty($listingType) ||
        empty($listerId) || !is_numeric($listerId) ||
        empty($doerId) || !is_numeric($doerId) ||
        empty($listingTitle)) {
        error_log("apply_for_job.php: Validation failed - Missing or invalid required fields. Data: " . json_encode($data), 0);
        throw new Exception("Listing ID, type, Lister ID, Doer ID, and Listing Title are required.");
    }

    // Check for duplicate application
    $checkStmt = $conn->prepare("SELECT id FROM applicationsv2 WHERE listing_id = ? AND doer_id = ? AND listing_type = ?");
    if ($checkStmt === false) {
        throw new Exception("Failed to prepare check statement: " . $conn->error);
    }
    $checkStmt->bind_param("iis", $listingId, $doerId, $listingType);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    if ($checkResult->num_rows > 0) {
        error_log("apply_for_job.php: Duplicate application attempt by Doer $doerId for Listing $listingId ($listingType)", 0);
        throw new Exception("You have already applied for this job.");
    }
    $checkStmt->close();

    // 1. Insert into applicationsv2 table
    $insertSql = "
        INSERT INTO applicationsv2 (
            listing_id, listing_type, lister_id, doer_id, listing_title, message, status, applied_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'pending', NOW())
    ";
    $insertStmt = $conn->prepare($insertSql);
    if ($insertStmt === false) {
        throw new Exception("Failed to prepare application insert statement: " . $conn->error);
    }
    $insertStmt->bind_param("iisiss", $listingId, $listingType, $listerId, $doerId, $listingTitle, $message);
    if (!$insertStmt->execute()) {
        error_log("apply_for_job.php: Failed to record application: " . $insertStmt->error, 0);
        throw new Exception("Failed to record application: " . $insertStmt->error);
    }
    $applicationId = $conn->insert_id;
    $insertStmt->close();

    // 2. Create or get conversation for this listing/lister/doer pair
    $convSql = "
        SELECT id FROM conversationsv2
        WHERE listing_id = ? AND listing_type = ? AND lister_id = ? AND doer_id = ?
    ";
    $convStmt = $conn->prepare($convSql);
    if ($convStmt === false) {
        throw new Exception("Failed to prepare conversation check statement: " . $conn->error);
    }
    $convStmt->bind_param("isii", $listingId, $listingType, $listerId, $doerId);
    $convStmt->execute();
    $convResult = $convStmt->get_result();
    $conversationId = null;

    if ($convResult->num_rows > 0) {
        $conversationId = $convResult->fetch_assoc()['id'];
    } else {
        $insertConvSql = "
            INSERT INTO conversationsv2 (listing_id, listing_type, lister_id, doer_id, created_at, last_message_at)
            VALUES (?, ?, ?, ?, NOW(), NOW())
        ";
        $insertConvStmt = $conn->prepare($insertConvSql);
        if ($insertConvStmt === false) {
            throw new Exception("Failed to prepare conversation insert statement: " . $conn->error);
        }
        $insertConvStmt->bind_param("isii", $listingId, $listingType, $listerId, $doerId);
        if (!$insertConvStmt->execute()) {
            error_log("apply_for_job.php: Failed to create conversation: " . $insertConvStmt->error, 0);
            throw new Exception("Failed to create conversation: " . $insertConvStmt->error);
        }
        $conversationId = $conn->insert_id;
        $insertConvStmt->close();
    }
    $convStmt->close();

    // 3. Link conversation_id to application
    $updateAppSql = "UPDATE applicationsv2 SET conversation_id = ? WHERE id = ?";
    $updateAppStmt = $conn->prepare($updateAppSql);
    if ($updateAppStmt === false) {
        throw new Exception("Failed to prepare application conversation update statement: " . $conn->error);
    }
    $updateAppStmt->bind_param("ii", $conversationId, $applicationId);
    if (!$updateAppStmt->execute()) {
        error_log("apply_for_job.php: Failed to link conversation to application: " . $updateAppStmt->error, 0);
        throw new Exception("Failed to link conversation to application: " . $updateAppStmt->error);
    }
    $updateAppStmt->close();

    // 4. Get doer's full name for notification
    $senderFullName = '';
    $doerInfoStmt = $conn->prepare("SELECT full_name FROM users WHERE id = ?");
    if ($doerInfoStmt === false) {
        throw new Exception("Failed to prepare doer info statement for notification: " . $conn->error);
    }
    $doerInfoStmt->bind_param("i", $doerId);
    $doerInfoStmt->execute();
    $doerInfoResult = $doerInfoStmt->get_result();
    if ($doerInfoRow = $doerInfoResult->fetch_assoc()) {
        $senderFullName = $doerInfoRow['full_name'];
    }
    $doerInfoStmt->close();

    // 5. Directly insert notification into database
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
        error_log("apply_for_job.php: Failed to prepare notification insert statement: " . $conn->error, 0);
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
            error_log("apply_for_job.php: Failed to insert notification: " . $notificationStmt->error, 0);
            // Don't throw exception here as the application was successful
        } else {
            error_log("apply_for_job.php: Notification inserted successfully for lister $listerId", 0);
        }
        $notificationStmt->close();
    }

    echo json_encode(["success" => true, "message" => "Application submitted successfully!", "application_id" => $applicationId]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("apply_for_job.php: Caught exception: " . $e->getMessage(), 0);
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