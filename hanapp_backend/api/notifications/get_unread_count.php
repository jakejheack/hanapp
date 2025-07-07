<?php
// hanapp_backend/api/notifications/get_unread_count.php
// Gets the count of unread notifications for a user (lister or doer)

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
    
    // Get user role from users table
    $userSql = "SELECT role FROM users WHERE id = ?";
    $userStmt = $conn->prepare($userSql);
    if ($userStmt === false) {
        throw new Exception("Failed to prepare user query: " . $conn->error);
    }
    $userStmt->bind_param("i", $userId);
    $userStmt->execute();
    $userResult = $userStmt->get_result();
    
    if ($userResult->num_rows === 0) {
        throw new Exception("User not found.");
    }
    
    $user = $userResult->fetch_assoc();
    $userRole = $user['role'];
    $userStmt->close();

    // Choose the appropriate table based on user role
    $tableName = ($userRole === 'lister') ? 'notificationsv2' : 'doer_notifications';
    
    $sql = "SELECT COUNT(*) as unread_count FROM $tableName WHERE user_id = ? AND is_read = 0";
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();

    echo json_encode([
        'success' => true,
        'unread_count' => intval($row['unread_count']),
        'user_role' => $userRole
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
?> 