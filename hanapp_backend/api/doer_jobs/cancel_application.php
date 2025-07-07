<?php
// hanapp_backend/api/doer_jobs/cancel_application.php
// Allows a Doer to cancel a pending application and creates notifications for both doer and lister

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
        throw new Exception("Invalid JSON payload.");
    }

    $applicationId = $data['application_id'] ?? null;
    $doerId = $data['doer_id'] ?? null;
    $cancellationReason = $data['cancellation_reason'] ?? null;

    // Validation
    if (empty($applicationId) || !is_numeric($applicationId)) {
        throw new Exception("Application ID is required and must be numeric.");
    }
    if (empty($doerId) || !is_numeric($doerId)) {
        throw new Exception("Doer ID is required and must be numeric.");
    }

    $conn->begin_transaction();

    // Get application details
    $getAppStmt = $conn->prepare("
        SELECT a.*, l.title as listing_title, l.lister_id, l.price,
               u1.full_name as lister_name, u2.full_name as doer_name,
               a.conversation_id, a.listing_type
        FROM applicationsv2 a
        JOIN listingsv2 l ON a.listing_id = l.id
        JOIN users u1 ON a.lister_id = u1.id
        JOIN users u2 ON a.doer_id = u2.id
        WHERE a.id = ? AND a.doer_id = ?
    ");
    if ($getAppStmt === false) {
        throw new Exception("Failed to prepare application query: " . $conn->error);
    }
    $getAppStmt->bind_param("ii", $applicationId, $doerId);
    $getAppStmt->execute();
    $appResult = $getAppStmt->get_result();
    
    if ($appResult->num_rows === 0) {
        throw new Exception("Application not found or access denied.");
    }
    
    $application = $appResult->fetch_assoc();
    $getAppStmt->close();

    // Check if application can be cancelled (only pending applications)
    if ($application['status'] !== 'pending') {
        throw new Exception("Only pending applications can be cancelled. Current status: {$application['status']}");
    }

    // Update application status to cancelled
    $updateStmt = $conn->prepare("UPDATE applicationsv2 SET status = 'cancelled', cancellation_reason = ? WHERE id = ?");
    if ($updateStmt === false) {
        throw new Exception("Failed to prepare update statement: " . $conn->error);
    }
    $reasonToBind = empty($cancellationReason) ? null : $cancellationReason;
    $updateStmt->bind_param("si", $reasonToBind, $applicationId);
    
    if (!$updateStmt->execute()) {
        throw new Exception("Failed to cancel application: " . $updateStmt->error);
    }
    $updateStmt->close();

    // Create notification for doer (application cancellation)
    $doerNotificationTitle = 'Application Cancelled';
    $doerNotificationContent = "Your application for '{$application['listing_title']}' has been cancelled.";
    if ($cancellationReason) {
        $doerNotificationContent .= " Reason: $cancellationReason";
    }
    $doerNotificationType = 'application_cancelled';
    
    $doerNotificationSql = "
        INSERT INTO doer_notifications (
            user_id, sender_id, type, title, content, associated_id,
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
            related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ";
    
    $doerNotificationStmt = $conn->prepare($doerNotificationSql);
    if ($doerNotificationStmt === false) {
        error_log("cancel_application.php: Failed to prepare doer notification insert: " . $conn->error, 0);
    } else {
        $doerNotificationStmt->bind_param("iisssiiissiiss",
            $doerId,                    // user_id (doer)
            $application['lister_id'],  // sender_id (lister)
            $doerNotificationType,      // type
            $doerNotificationTitle,     // title
            $doerNotificationContent,   // content
            $applicationId,             // associated_id
            $application['conversation_id'], // conversation_id_for_chat_nav
            $application['lister_id'],       // conversation_lister_id
            $application['doer_id'],         // conversation_doer_id
            $application['listing_title'],   // related_listing_title
            $application['listing_id'],      // listing_id
            $application['listing_type'],    // listing_type
            $application['lister_id'],       // lister_id
            $application['lister_name']      // lister_name
        );
        
        if (!$doerNotificationStmt->execute()) {
            error_log("cancel_application.php: Failed to insert doer notification: " . $doerNotificationStmt->error, 0);
        } else {
            error_log("cancel_application.php: Doer application cancellation notification created successfully", 0);
        }
        $doerNotificationStmt->close();
    }

    // Create notification for lister (application cancelled by doer)
    $listerNotificationTitle = 'Application Cancelled by Doer';
    $listerNotificationContent = "A doer has cancelled their application for '{$application['listing_title']}'.";
    if ($cancellationReason) {
        $listerNotificationContent .= " Reason: $cancellationReason";
    }
    $listerNotificationType = 'application_cancelled_by_doer';
    
    $listerNotificationSql = "
        INSERT INTO notificationsv2 (
            user_id, sender_id, type, title, content, associated_id,
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
            related_listing_title, is_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ";
    
    $listerNotificationStmt = $conn->prepare($listerNotificationSql);
    if ($listerNotificationStmt === false) {
        error_log("cancel_application.php: Failed to prepare lister notification insert: " . $conn->error, 0);
    } else {
        $listerNotificationStmt->bind_param("iisssiiiss",
            $application['lister_id'],  // user_id (lister)
            $doerId,                     // sender_id (doer)
            $listerNotificationType,     // type
            $listerNotificationTitle,    // title
            $listerNotificationContent,  // content
            $applicationId,              // associated_id
            $application['conversation_id'], // conversation_id_for_chat_nav
            $application['lister_id'],       // conversation_lister_id
            $application['doer_id'],         // conversation_doer_id
            $application['listing_title']    // related_listing_title
        );
        
        if (!$listerNotificationStmt->execute()) {
            error_log("cancel_application.php: Failed to insert lister notification: " . $listerNotificationStmt->error, 0);
        } else {
            error_log("cancel_application.php: Lister application cancellation notification created successfully", 0);
        }
        $listerNotificationStmt->close();
    }

    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "Application cancelled successfully."
    ]);

} catch (Exception $e) {
    if (isset($conn) && $conn instanceof mysqli && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("cancel_application.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to cancel application: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 