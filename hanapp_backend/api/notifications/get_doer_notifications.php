<?php
// hanapp_backend/api/notifications/get_doer_notifications.php
// Fetches notifications for a doer from the doer_notifications table

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

require_once '../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    if (!isset($_GET['user_id']) || !is_numeric($_GET['user_id'])) {
        throw new Exception("user_id is required and must be numeric.");
    }
    $userId = intval($_GET['user_id']);

    $sql = "SELECT * FROM doer_notifications WHERE user_id = ? ORDER BY created_at DESC";
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    $notifications = [];
    while ($row = $result->fetch_assoc()) {
        $notifications[] = [
            'id' => $row['id'],
            'user_id' => $row['user_id'],
            'sender_id' => $row['sender_id'],
            'type' => $row['type'],
            'title' => $row['title'],
            'content' => $row['content'],
            'associated_id' => $row['associated_id'],
            'conversation_id_for_chat_nav' => $row['conversation_id_for_chat_nav'],
            'conversation_lister_id' => $row['conversation_lister_id'],
            'conversation_doer_id' => $row['conversation_doer_id'],
            'related_listing_title' => $row['related_listing_title'],
            'listing_id' => $row['listing_id'],
            'listing_type' => $row['listing_type'],
            'lister_id' => $row['lister_id'],
            'lister_name' => $row['lister_name'],
            'is_read' => $row['is_read'],
            'created_at' => $row['created_at'],
        ];
    }
    $stmt->close();

    echo json_encode([
        'success' => true,
        'notifications' => $notifications
    ]);
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
} 