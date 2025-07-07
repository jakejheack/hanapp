<?php
// hanapp_backend/api/notifications/mark_read.php
// Marks a lister notification as read

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

    $notificationId = $data['notification_id'] ?? null;

    if (empty($notificationId) || !is_numeric($notificationId)) {
        throw new Exception("Notification ID is required and must be numeric.");
    }

    $sql = "UPDATE notificationsv2 SET is_read = 1 WHERE id = ?";
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $stmt->bind_param("i", $notificationId);
    
    if (!$stmt->execute()) {
        throw new Exception("Failed to mark notification as read: " . $stmt->error);
    }

    if ($stmt->affected_rows === 0) {
        throw new Exception("Notification not found or already marked as read.");
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "message" => "Notification marked as read successfully"
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("mark_read.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to mark notification as read: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 