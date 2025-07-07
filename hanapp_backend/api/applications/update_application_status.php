<?php
// hanapp_backend/api/applications/update_application_status.php
// Updates the status of a specific application and creates notifications for both doers and listers

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
        error_log("update_application_status.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        throw new Exception("Invalid JSON payload.");
    }

    // Debug: Log the received data
    error_log("update_application_status.php: Received data: " . json_encode($data), 0);

    $applicationId = $data['application_id'] ?? null;
    $newStatus = $data['new_status'] ?? null;
    $initiatorId = $data['current_user_id'] ?? null;

    // Debug: Log the extracted values
    error_log("update_application_status.php: Extracted values - applicationId: $applicationId, newStatus: $newStatus, initiatorId: $initiatorId", 0);

    if (empty($applicationId) || !is_numeric($applicationId) || empty($newStatus) || empty($initiatorId) || !is_numeric($initiatorId)) {
        error_log("update_application_status.php: Validation failed - Missing or invalid required fields. Data: " . json_encode($data), 0);
        throw new Exception("Application ID, new status, and current user ID are required.");
    }

    $allowedStatuses = ['pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled'];
    if (!in_array($newStatus, $allowedStatuses)) {
        throw new Exception("Invalid status provided. Allowed statuses: " . implode(', ', $allowedStatuses));
    }

    $conn->begin_transaction();

    // Debug: Log the application ID being searched
    error_log("update_application_status.php: Searching for application ID: $applicationId", 0);

    // Get application details and verify authorization
    $getAppStmt = $conn->prepare("
        SELECT a.*, 
               COALESCE(pl.title, al.title) as listing_title,
               COALESCE(pl.lister_id, al.lister_id) as lister_id,
               COALESCE(pl.price, al.price) as price,
               u1.full_name as lister_name, 
               u2.full_name as doer_name
        FROM applicationsv2 a
        LEFT JOIN listingsv2 pl ON a.listing_id = pl.id AND a.listing_type = 'PUBLIC'
        LEFT JOIN asap_listings al ON a.listing_id = al.id AND a.listing_type = 'ASAP'
        JOIN users u1 ON COALESCE(pl.lister_id, al.lister_id) = u1.id
        JOIN users u2 ON a.doer_id = u2.id
        WHERE a.id = ?
    ");
    if ($getAppStmt === false) {
        throw new Exception("Failed to prepare application query: " . $conn->error);
    }
    $getAppStmt->bind_param("i", $applicationId);
    $getAppStmt->execute();
    $appResult = $getAppStmt->get_result();
    
    // Debug: Log the number of rows found
    error_log("update_application_status.php: Found " . $appResult->num_rows . " rows for application ID: $applicationId", 0);
    
    if ($appResult->num_rows === 0) {
        // Debug: Check if the application exists without joins
        $checkAppStmt = $conn->prepare("SELECT id, listing_id, listing_type, lister_id, doer_id, status FROM applicationsv2 WHERE id = ?");
        if ($checkAppStmt === false) {
            error_log("update_application_status.php: Failed to prepare check application statement: " . $conn->error, 0);
        } else {
            $checkAppStmt->bind_param("i", $applicationId);
            $checkAppStmt->execute();
            $checkResult = $checkAppStmt->get_result();
            error_log("update_application_status.php: Application exists in applicationsv2: " . ($checkResult->num_rows > 0 ? "YES" : "NO"), 0);
            
            if ($checkResult->num_rows > 0) {
                $appData = $checkResult->fetch_assoc();
                error_log("update_application_status.php: Application data: " . json_encode($appData), 0);
                
                // Check if listing exists
                $checkListingStmt = $conn->prepare("SELECT id, title FROM listingsv2 WHERE id = ?");
                if ($checkListingStmt === false) {
                    error_log("update_application_status.php: Failed to prepare check listing statement: " . $conn->error, 0);
                } else {
                    $checkListingStmt->bind_param("i", $appData['listing_id']);
                    $checkListingStmt->execute();
                    $listingResult = $checkListingStmt->get_result();
                    error_log("update_application_status.php: Listing exists: " . ($listingResult->num_rows > 0 ? "YES" : "NO"), 0);
                    
                    if ($listingResult->num_rows > 0) {
                        $listingData = $listingResult->fetch_assoc();
                        error_log("update_application_status.php: Listing data: " . json_encode($listingData), 0);
                    }
                    $checkListingStmt->close();
                }
            }
            $checkAppStmt->close();
        }
        
        throw new Exception("Application not found.");
    }
    
    $application = $appResult->fetch_assoc();
    $getAppStmt->close();

    $listerId = $application['lister_id'];
    $doerId = $application['doer_id'];
    $currentApplicationStatus = $application['status'];

    $isLister = ($initiatorId == $listerId);
    $isDoer = ($initiatorId == $doerId);

    $authorized = false;
    $message = "";

    switch ($newStatus) {
        case 'accepted':
            if ($isLister && $currentApplicationStatus == 'pending') {
                $authorized = true;
            } else {
                $message = "Only the lister can accept a pending application.";
            }
            break;
        case 'rejected':
            if ($isLister && ($currentApplicationStatus == 'pending' || $currentApplicationStatus == 'accepted' || $currentApplicationStatus == 'in_progress')) {
                $authorized = true;
            } else {
                $message = "Only the lister can reject an application from pending/accepted/in-progress status.";
            }
            break;
        case 'in_progress':
            if ($isLister && ($currentApplicationStatus == 'pending' || $currentApplicationStatus == 'accepted')) {
                $authorized = true;
            } else {
                $message = "Only the lister can set status to 'in_progress' from pending or accepted status.";
            }
            break;
        case 'completed':
            if ($isLister && $currentApplicationStatus == 'in_progress') {
                $authorized = true;
            } else {
                $message = "Only the lister can mark an 'in_progress' project as completed.";
            }
            break;
        case 'cancelled':
            if (($isLister || $isDoer) && ($currentApplicationStatus == 'pending' || $currentApplicationStatus == 'accepted' || $currentApplicationStatus == 'in_progress')) {
                $authorized = true;
            } else {
                $message = "Only the lister or doer can cancel an active application/project.";
            }
            break;
        case 'pending':
            $message = "Cannot set status directly to 'pending' via this endpoint.";
            break;
        default:
            $message = "Invalid status update requested.";
            break;
    }

    if (!$authorized) {
        throw new Exception("Unauthorized or invalid status transition: " . $message);
    }

    // Update application status
    $updateSql = "UPDATE applicationsv2 SET status = ?";
    $params = [$newStatus];
    $types = "s";

    if ($newStatus === 'in_progress' && ($currentApplicationStatus == 'pending' || $currentApplicationStatus == 'accepted')) {
        $updateSql .= ", project_start_date = NOW()";
    }

    if ($newStatus === 'completed' && $currentApplicationStatus === 'in_progress') {
        $updateSql .= ", project_end_date = NOW()";
    }

    $updateSql .= " WHERE id = ?";
    $params[] = $applicationId;
    $types .= "i";

    $updateStmt = $conn->prepare($updateSql);
    if ($updateStmt === false) {
        throw new Exception("Failed to prepare update statement: " . $conn->error);
    }

    call_user_func_array([$updateStmt, 'bind_param'], array_merge([$types], $params));

    if (!$updateStmt->execute()) {
        throw new Exception("Failed to update application status: " . $updateStmt->error);
    }

    if ($updateStmt->affected_rows === 0) {
        error_log("update_application_status.php: No rows affected for application $applicationId to $newStatus. Current status: $currentApplicationStatus", 0);
    }

    $updateStmt->close();

    // Create notifications based on status change
    $doerNotificationTitle = '';
    $doerNotificationContent = '';
    $doerNotificationType = '';
    $listerNotificationTitle = '';
    $listerNotificationContent = '';
    $listerNotificationType = '';

    switch ($newStatus) {
        case 'accepted':
            $doerNotificationTitle = 'Application Accepted';
            $doerNotificationContent = "Your application for '{$application['listing_title']}' has been accepted!";
            $doerNotificationType = 'application_accepted';
            break;
            
        case 'rejected':
            $doerNotificationTitle = 'Application Rejected';
            $doerNotificationContent = "Your application for '{$application['listing_title']}' was not selected.";
            $doerNotificationType = 'application_rejected';
            break;
            
        case 'in_progress':
            $doerNotificationTitle = 'Project Started';
            $doerNotificationContent = "The project '{$application['listing_title']}' has started. Good luck!";
            $doerNotificationType = 'project_started';
            break;
            
        case 'completed':
            $doerNotificationTitle = 'Job Completed';
            $doerNotificationContent = "Congratulations! The job '{$application['listing_title']}' has been completed.";
            $doerNotificationType = 'job_completed';
            break;
            
        case 'cancelled':
            if ($isLister) {
                $doerNotificationTitle = 'Application Cancelled by Lister';
                $doerNotificationContent = "Your application for '{$application['listing_title']}' has been cancelled by the lister.";
                $doerNotificationType = 'application_cancelled_by_lister';
            } else {
                $doerNotificationTitle = 'Application Cancelled';
                $doerNotificationContent = "Your application for '{$application['listing_title']}' has been cancelled.";
                $doerNotificationType = 'application_cancelled';
                
                $listerNotificationTitle = 'Application Cancelled by Doer';
                $listerNotificationContent = "A doer has cancelled their application for '{$application['listing_title']}'.";
                $listerNotificationType = 'application_cancelled_by_doer';
            }
            break;
    }

    // Insert doer notification if we have one to send
    if ($doerNotificationTitle && $doerId) {
        $doerNotificationSql = "
            INSERT INTO doer_notifications (
                user_id, sender_id, type, title, content, associated_id,
                conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        ";
        
        $doerNotificationStmt = $conn->prepare($doerNotificationSql);
        if ($doerNotificationStmt === false) {
            error_log("update_application_status.php: Failed to prepare doer notification insert: " . $conn->error, 0);
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
                $application['listing_type'],    // listing_type (from applicationsv2)
                $application['lister_id'],       // lister_id
                $application['lister_name']      // lister_name
            );
            
            if (!$doerNotificationStmt->execute()) {
                error_log("update_application_status.php: Failed to insert doer notification: " . $doerNotificationStmt->error, 0);
            } else {
                error_log("update_application_status.php: Doer notification created successfully for status: $newStatus", 0);
            }
            $doerNotificationStmt->close();
        }
    }

    // Insert lister notification if we have one to send
    if ($listerNotificationTitle && $listerId) {
        $listerNotificationSql = "
            INSERT INTO notificationsv2 (
                user_id, sender_id, type, title, content, associated_id,
                conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                related_listing_title, is_read
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        ";
        
        $listerNotificationStmt = $conn->prepare($listerNotificationSql);
        if ($listerNotificationStmt === false) {
            error_log("update_application_status.php: Failed to prepare lister notification insert: " . $conn->error, 0);
        } else {
            $listerNotificationStmt->bind_param("iisssiiiss",
                $listerId,                   // user_id (lister)
                $doerId,                      // sender_id (doer)
                $listerNotificationType,      // type
                $listerNotificationTitle,     // title
                $listerNotificationContent,   // content
                $applicationId,               // associated_id
                $application['conversation_id'], // conversation_id_for_chat_nav
                $application['lister_id'],       // conversation_lister_id
                $application['doer_id'],         // conversation_doer_id
                $application['listing_title']    // related_listing_title
            );
            
            if (!$listerNotificationStmt->execute()) {
                error_log("update_application_status.php: Failed to insert lister notification: " . $listerNotificationStmt->error, 0);
            } else {
                error_log("update_application_status.php: Lister notification created successfully for status: $newStatus", 0);
            }
            $listerNotificationStmt->close();
        }
    }

    // Add additional lister notifications for other status changes
    if (!$listerNotificationTitle && $listerId) {
        switch ($newStatus) {
            case 'accepted':
                $listerNotificationTitle = 'Application Accepted';
                $listerNotificationContent = "You have accepted an application for '{$application['listing_title']}'.";
                $listerNotificationType = 'application_accepted_by_lister';
                break;
                
            case 'rejected':
                $listerNotificationTitle = 'Application Rejected';
                $listerNotificationContent = "You have rejected an application for '{$application['listing_title']}'.";
                $listerNotificationType = 'application_rejected_by_lister';
                break;
                
            case 'in_progress':
                $listerNotificationTitle = 'Project Started';
                $listerNotificationContent = "The project '{$application['listing_title']}' has been started.";
                $listerNotificationType = 'project_started_by_lister';
                break;
                
            case 'completed':
                $listerNotificationTitle = 'Job Completed';
                $listerNotificationContent = "The job '{$application['listing_title']}' has been marked as completed.";
                $listerNotificationType = 'job_completed_by_lister';
                break;
        }

        if ($listerNotificationTitle) {
            $listerNotificationSql = "
                INSERT INTO notificationsv2 (
                    user_id, sender_id, type, title, content, associated_id,
                    conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                    related_listing_title, is_read
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
            ";
            
            $listerNotificationStmt = $conn->prepare($listerNotificationSql);
            if ($listerNotificationStmt === false) {
                error_log("update_application_status.php: Failed to prepare additional lister notification insert: " . $conn->error, 0);
            } else {
                $listerNotificationStmt->bind_param("iisssiiiss",
                    $listerId,                   // user_id (lister)
                    $doerId,                      // sender_id (doer)
                    $listerNotificationType,      // type
                    $listerNotificationTitle,     // title
                    $listerNotificationContent,   // content
                    $applicationId,               // associated_id
                    $application['conversation_id'], // conversation_id_for_chat_nav
                    $application['lister_id'],       // conversation_lister_id
                    $application['doer_id'],         // conversation_doer_id
                    $application['listing_title']    // related_listing_title
                );
                
                if (!$listerNotificationStmt->execute()) {
                    error_log("update_application_status.php: Failed to insert additional lister notification: " . $listerNotificationStmt->error, 0);
                } else {
                    error_log("update_application_status.php: Additional lister notification created successfully for status: $newStatus", 0);
                }
                $listerNotificationStmt->close();
            }
        }
    }

    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "Application status updated to '$newStatus' successfully."
    ]);

} catch (Exception $e) {
    if (isset($conn) && $conn instanceof mysqli && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("update_application_status.php: Caught exception: " . $e->getMessage(), 0);
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