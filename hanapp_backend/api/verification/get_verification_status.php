<?php
// hanapp_backend/api/verification/get_verification_status.php
// Get user verification status

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../config/db_connect.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        throw new Exception('Only GET method is allowed');
    }

    // Get user_id from query parameters
    $userId = $_GET['user_id'] ?? null;

    if (!$userId) {
        throw new Exception('User ID is required');
    }

    // Validate user_id is numeric
    if (!is_numeric($userId)) {
        throw new Exception('Invalid user ID format');
    }

    // Fetch user verification data
    $stmt = $conn->prepare("
        SELECT 
            verification_status,
            id_verified,
            badge_acquired,
            badge_status,
            id_photo_front_url,
            id_photo_back_url,
            brgy_clearance_photo_url,
            live_photo_url
        FROM users 
        WHERE id = ?
    ");
    
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception('User not found');
    }

    $user = $result->fetch_assoc();

    // Prepare status data with proper type conversion
    $statusData = [
        'verification_status' => (string)($user['verification_status'] ?? 'unverified'),
        'id_verified' => (bool)($user['id_verified'] ?? false),
        'badge_acquired' => (bool)($user['badge_acquired'] ?? false),
        'badge_status' => (string)($user['badge_status'] ?? 'none'),
        'id_photo_front_url' => $user['id_photo_front_url'] ? (string)$user['id_photo_front_url'] : null,
        'id_photo_back_url' => $user['id_photo_back_url'] ? (string)$user['id_photo_back_url'] : null,
        'brgy_clearance_photo_url' => $user['brgy_clearance_photo_url'] ? (string)$user['brgy_clearance_photo_url'] : null,
        'live_photo_url' => $user['live_photo_url'] ? (string)$user['live_photo_url'] : null,
    ];

    echo json_encode([
        'success' => true,
        'message' => 'Verification status retrieved successfully',
        'status_data' => $statusData
    ]);

} catch (Exception $e) {
    error_log("get_verification_status.php error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
