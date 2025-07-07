<?php
// hanapp_backend/api/doer_jobs/start_project.php
// Marks an application as 'in_progress' and creates a notification

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
    $listerId = $data['lister_id'] ?? null;

    // Validation
    if (empty($applicationId) || !is_numeric($applicationId)) {
        throw new Exception("Application ID is required and must be numeric.");
    }
    if (empty($listerId) || !is_numeric($listerId)) {
        throw new Exception("Lister ID is required and must be numeric.");
    }

    $conn->begin_transaction();

    // Get application details and verify lister ownership
    $getAppStmt = $conn->prepare("
        SELECT a.*, l.title as listing_title, l.lister_id, l.price,
               u1.full_name as lister_name, u2.full_name as doer_name
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

    // Check if application is in accepted status
    if ($application['status'] !== 'accepted') {
        throw new Exception("Only accepted applications can be started. Current status: {$application['status']}");
    }

    // Update application status to in_progress and set project start date
    $updateStmt = $conn->prepare("UPDATE applicationsv2 SET status = 'in_progress', project_start_date = NOW() WHERE id = ?");
    if ($updateStmt === false) {
        throw new Exception("Failed to prepare update statement: " . $conn->error);
    }
    $updateStmt->bind_param("i", $applicationId);
    
    if (!$updateStmt->execute()) {
        throw new Exception("Failed to start project: " . $updateStmt->error);
    }
    $updateStmt->close();

    // Create notification for doer (project started)
    $doerNotificationTitle = 'Project Started';
    $doerNotificationContent = "The project '{$application['listing_title']}' has started. Good luck with your work!";
    $doerNotificationType = 'project_started';
    
    $doerNotificationSql = "
        INSERT INTO doer_notifications (
            user_id, sender_id, type, title, content, associated_id,
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
            related_listing_title, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ";
    
    $doerNotificationStmt = $conn->prepare($doerNotificationSql);
    if ($doerNotificationStmt === false) {
        error_log("start_project.php: Failed to prepare doer notification insert: " . $conn->error, 0);
    } else {
        $doerNotificationStmt->bind_param("iisssiiiss",
            $application['doer_id'],    // user_id (doer)
            $listerId,                   // sender_id (lister)
            $doerNotificationType,       // type
            $doerNotificationTitle,      // title
            $doerNotificationContent,    // content
            $applicationId,              // associated_id
            $application['conversation_id'], // conversation_id_for_chat_nav
            $application['lister_id'],       // conversation_lister_id
            $application['doer_id'],         // conversation_doer_id
            $application['listing_title']    // related_listing_title
        );
        
        if (!$doerNotificationStmt->execute()) {
            error_log("start_project.php: Failed to insert doer notification: " . $doerNotificationStmt->error, 0);
        } else {
            error_log("start_project.php: Doer project start notification created successfully", 0);
        }
        $doerNotificationStmt->close();
    }

    // Create notification for lister (project started)
    $listerNotificationTitle = 'Project Started';
    $listerNotificationContent = "Your project '{$application['listing_title']}' has been started by {$application['doer_name']}.";
    $listerNotificationType = 'project_started';
    
    $listerNotificationSql = "
        INSERT INTO notificationsv2 (
            user_id, sender_id, type, title, content, associated_id,
            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
            related_listing_title, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ";
    
    $listerNotificationStmt = $conn->prepare($listerNotificationSql);
    if ($listerNotificationStmt === false) {
        error_log("start_project.php: Failed to prepare lister notification insert: " . $conn->error, 0);
    } else {
        $listerNotificationStmt->bind_param("iisssiiiss",
            $application['lister_id'],  // user_id (lister)
            $application['doer_id'],    // sender_id (doer)
            $listerNotificationType,    // type
            $listerNotificationTitle,   // title
            $listerNotificationContent, // content
            $applicationId,             // associated_id
            $application['conversation_id'], // conversation_id_for_chat_nav
            $application['lister_id'],       // conversation_lister_id
            $application['doer_id'],         // conversation_doer_id
            $application['listing_title']    // related_listing_title
        );
        
        if (!$listerNotificationStmt->execute()) {
            error_log("start_project.php: Failed to insert lister notification: " . $listerNotificationStmt->error, 0);
        } else {
            error_log("start_project.php: Lister project start notification created successfully", 0);
        }
        $listerNotificationStmt->close();
    }

    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "Project started successfully. Application status set to 'in_progress'."
    ]);

} catch (Exception $e) {
    if (isset($conn) && $conn instanceof mysqli && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("start_project.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to start project: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 