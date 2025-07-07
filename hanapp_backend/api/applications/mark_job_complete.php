<?php
// hanapp_backend/api/applications/mark_job_complete.php
// Marks a job application as 'completed', creates notifications, and optionally creates a review placeholder

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

require_once '../../config/db_connect.php';

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
        error_log("mark_job_complete.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        throw new Exception("Invalid JSON payload.");
    }

    $applicationId = $data['application_id'] ?? null;
    $listerId = $data['lister_id'] ?? null; // Lister marking complete
    $doerId = $data['doer_id'] ?? null;   // Doer for this application
    $listingTitle = $data['listing_title'] ?? 'Job'; // For notifications/messages

    // CRITICAL FIX: Explicitly check for empty AND non-numeric values
    if (empty($applicationId) || !is_numeric($applicationId)) {
        error_log("mark_job_complete.php: Validation failed - application_id is missing or invalid. Received: " . var_export($applicationId, true), 0);
        throw new Exception("Application ID is required and must be numeric.");
    }
    if (empty($listerId) || !is_numeric($listerId)) {
        error_log("mark_job_complete.php: Validation failed - lister_id is missing or invalid. Received: " . var_export($listerId, true), 0);
        throw new Exception("Lister ID is required and must be numeric.");
    }
    if (empty($doerId) || !is_numeric($doerId)) {
        error_log("mark_job_complete.php: Validation failed - doer_id is missing or invalid. Received: " . var_export($doerId, true), 0);
        throw new Exception("Doer ID is required and must be numeric.");
    }

    $conn->begin_transaction();

    // Get application details for notifications
    $getAppStmt = $conn->prepare("
        SELECT a.*, l.title as listing_title, l.lister_id, l.price,
               u1.full_name as lister_name, u2.full_name as doer_name,
               a.conversation_id, a.listing_type
        FROM applicationsv2 a
        JOIN listingsv2 l ON a.listing_id = l.id
        JOIN users u1 ON a.lister_id = u1.id
        JOIN users u2 ON a.doer_id = u2.id
        WHERE a.id = ? AND a.lister_id = ?
    ");
    if ($getAppStmt === false) {
        throw new Exception("Failed to prepare application query: " . $conn->error);
    }
    $getAppStmt->bind_param("ii", $applicationId, $listerId);
    $getAppStmt->execute();
    $appResult = $getAppStmt->get_result();
    
    if ($appResult->num_rows === 0) {
        throw new Exception("Application not found or access denied.");
    }
    
    $application = $appResult->fetch_assoc();
    $getAppStmt->close();

    // Check if application is in in_progress status
    if ($application['status'] !== 'in_progress') {
        throw new Exception("Only in-progress applications can be marked as complete. Current status: {$application['status']}");
    }

    // 1. Update application status
    $updateSql = "UPDATE applicationsv2 SET status = 'completed', project_end_date = NOW() WHERE id = ? AND lister_id = ?";
    $updateStmt = $conn->prepare($updateSql);
    if ($updateStmt === false) {
        error_log("mark_job_complete.php: Failed to prepare update statement: " . $conn->error, 0);
        throw new Exception("Database query preparation failed for update: " . $conn->error);
    }
    $updateStmt->bind_param("ii", $applicationId, $listerId);
    if (!$updateStmt->execute()) {
        error_log("mark_job_complete.php: Failed to execute update statement: " . $updateStmt->error, 0);
        throw new Exception("Failed to update application status: " . $updateStmt->error);
    }
    if ($updateStmt->affected_rows === 0) {
        throw new Exception("Application not found, already completed, or not authorized to complete.");
    }
    $updateStmt->close();

    // 2. Get listing_id and listing_type from the application for review creation
    $getListingDetailsSql = "SELECT listing_id, listing_type FROM applicationsv2 WHERE id = ?";
    $getListingDetailsStmt = $conn->prepare($getListingDetailsSql);
    if ($getListingDetailsStmt === false) {
        error_log("mark_job_complete.php: Failed to prepare get listing details statement: " . $conn->error, 0);
        throw new Exception("Database query preparation failed for listing details: " . $conn->error);
    }
    $getListingDetailsStmt->bind_param("i", $applicationId);
    $getListingDetailsStmt->execute();
    $listingResult = $getListingDetailsStmt->get_result();
    $listingDetails = $listingResult->fetch_assoc();
    $getListingDetailsStmt->close();

    if (!$listingDetails) {
        throw new Exception("Listing details not found for application $applicationId.");
    }
    $listingIdForReview = $listingDetails['listing_id'];
    $listingTypeForReview = $listingDetails['listing_type'];

    // 3. Create a placeholder review entry
    $checkReviewSql = "SELECT id FROM reviews WHERE application_id = ? LIMIT 1";
    $checkReviewStmt = $conn->prepare($checkReviewSql);
    if ($checkReviewStmt === false) {
        throw new Exception("Failed to prepare review check statement: " . $conn->error);
    }
    $checkReviewStmt->bind_param("i", $applicationId);
    $checkReviewStmt->execute();
    $existingReview = $checkReviewStmt->get_result()->fetch_assoc();
    $checkReviewStmt->close();

    if (!$existingReview) {
        $insertReviewSql = "INSERT INTO reviews (listing_id, listing_type, lister_id, doer_id, application_id, rating, review_message, reviewed_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?, NOW())";
        $insertReviewStmt = $conn->prepare($insertReviewSql);
        if ($insertReviewStmt === false) {
            throw new Exception("Failed to prepare review insertion statement: " . $conn->error);
        }
        $defaultRating = 0.0;
        $defaultMessage = "Awaiting review from Lister.";
        $insertReviewStmt->bind_param("isiiids",
            $listingIdForReview, $listingTypeForReview, $listerId, $doerId, $applicationId, $defaultRating, $defaultMessage
        );
        if (!$insertReviewStmt->execute()) {
            throw new Exception("Failed to create review placeholder: " . $insertReviewStmt->error);
        }
        $insertReviewStmt->close();
    } else {
        error_log("mark_job_complete.php: Review placeholder already exists for application $applicationId. Skipping creation.", 0);
    }

    // 4. Create notification for doer (job completed by lister)
    $doerNotificationTitle = 'Job Completed by Lister';
    $doerNotificationContent = "Congratulations! The lister has marked the job '{$application['listing_title']}' as completed.";
    $doerNotificationType = 'job_completed_by_lister';
    
    $doerNotificationSql = "
        INSERT INTO doer_notifications (
            user_id, sender_id, type, title, content, associated_id,
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
            related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ";
    
    $doerNotificationStmt = $conn->prepare($doerNotificationSql);
    if ($doerNotificationStmt === false) {
        error_log("mark_job_complete.php: Failed to prepare doer notification insert: " . $conn->error, 0);
    } else {
        $doerNotificationStmt->bind_param("iisssiiissiiss",
            $doerId,                    // user_id (doer)
            $listerId,                   // sender_id (lister)
            $doerNotificationType,       // type
            $doerNotificationTitle,      // title
            $doerNotificationContent,    // content
            $applicationId,              // associated_id
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
            error_log("mark_job_complete.php: Failed to insert doer notification: " . $doerNotificationStmt->error, 0);
        } else {
            error_log("mark_job_complete.php: Doer job completion notification created successfully", 0);
        }
        $doerNotificationStmt->close();
    }

    // 5. Create notification for lister (job completion confirmation)
    $listerNotificationTitle = 'Job Marked as Complete';
    $listerNotificationContent = "You have successfully marked the job '{$application['listing_title']}' as completed. Please leave a review for the doer.";
    $listerNotificationType = 'job_marked_complete';
    
    $listerNotificationSql = "
        INSERT INTO notificationsv2 (
            user_id, sender_id, type, title, content, associated_id,
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
            related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ";
    
    $listerNotificationStmt = $conn->prepare($listerNotificationSql);
    if ($listerNotificationStmt === false) {
        error_log("mark_job_complete.php: Failed to prepare lister notification insert: " . $conn->error, 0);
    } else {
        $listerNotificationStmt->bind_param("iisssiiissiiss",
            $listerId,                   // user_id (lister)
            $doerId,                      // sender_id (doer)
            $listerNotificationType,      // type
            $listerNotificationTitle,     // title
            $listerNotificationContent,   // content
            $applicationId,               // associated_id
            $application['conversation_id'], // conversation_id_for_chat_nav
            $application['lister_id'],       // conversation_lister_id
            $application['doer_id'],         // conversation_doer_id
            $application['listing_title'],   // related_listing_title
            $application['listing_id'],      // listing_id
            $application['listing_type'],    // listing_type
            $application['lister_id'],       // lister_id
            $application['lister_name']      // lister_name
        );
        
        if (!$listerNotificationStmt->execute()) {
            error_log("mark_job_complete.php: Failed to insert lister notification: " . $listerNotificationStmt->error, 0);
        } else {
            error_log("mark_job_complete.php: Lister job completion notification created successfully", 0);
        }
        $listerNotificationStmt->close();
    }

    $conn->commit();

    echo json_encode(["success" => true, "message" => "Job '$listingTitle' marked as complete!"]);

} catch (Exception $e) {
    if (isset($conn) && $conn instanceof mysqli && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("mark_job_complete.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An internal server error occurred: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 