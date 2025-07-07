<?php
// hanapp_backend/api/notifications/get_notifications.php
// Fetches notifications for a given user, joining with users table for sender details.

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
    $userId = $_GET['user_id'] ?? null;

    if (empty($userId) || !is_numeric($userId)) {
        error_log("get_notifications.php: Validation failed - User ID is missing or invalid. Received user_id: " . var_export($userId, true), 0);
        throw new Exception("User ID is required to fetch notifications.");
    }

    $notifications = [];

    // Select all columns from notificationsv2 and join with users for sender details
    $sql = "
        SELECT
            n.id,
            n.user_id,
            n.sender_id,
            n.type,
            n.title,
            n.content,
            n.created_at,
            n.is_read,
            n.associated_id,
            n.conversation_id_for_chat_nav,
            n.conversation_lister_id,
            n.conversation_doer_id,
            n.related_listing_title,
            u.full_name AS sender_full_name,
            u.profile_picture_url AS sender_profile_picture_url
        FROM
            notificationsv2 n
        LEFT JOIN
            users u ON n.sender_id = u.id
        WHERE
            n.user_id = ?
        ORDER BY
            n.created_at DESC
    ";

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        error_log("get_notifications.php: Failed to prepare statement: " . $conn->error, 0);
        throw new Exception("Database query preparation failed: " . $conn->error);
    }
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    while ($row = $result->fetch_assoc()) {
        $row['created_at'] = $row['created_at'] ? date('Y-m-d H:i:s', strtotime($row['created_at'])) : null;
        $row['is_read'] = (bool)$row['is_read'];
        $notifications[] = $row;
    }
    $stmt->close();

    echo json_encode([
        "success" => true,
        "notifications" => $notifications
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_notifications.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An internal server error occurred. Please check server logs for PHP errors. (Error: " . $e->getMessage() . ")"
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 