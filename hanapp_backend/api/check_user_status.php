<?php
// hanapp_backend/api/check_user_status.php
// Checks user status and prevents multiple device usage

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once 'config/db_connect.php';

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

    $userId = $data['user_id'] ?? null;
    $deviceInfo = $data['device_info'] ?? null;
    $action = $data['action'] ?? 'check'; // 'check' or 'login'

    if (empty($userId)) {
        echo json_encode([
            "success" => false, 
            "message" => "User ID is required.",
            "error_type" => "missing_user_id"
        ]);
        exit();
    }

    // Get user information
    $stmt = $conn->prepare("
        SELECT
            id, full_name, email, role, is_verified, profile_picture_url,
            address_details, contact_number, latitude, longitude, is_available,
            banned_until, is_deleted, created_at, updated_at
        FROM users
        WHERE id = ?
    ");

    if ($stmt === false) {
        throw new Exception("Failed to prepare database statement.");
    }

    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    if (!$user) {
        echo json_encode([
            "success" => false, 
            "message" => "User not found.",
            "error_type" => "user_not_found"
        ]);
        exit();
    }

    // Check if user is deleted
    if ($user['is_deleted'] == 1 || $user['is_deleted'] === '1' || $user['is_deleted'] === true) {
        echo json_encode([
            "success" => false, 
            "message" => "Account has been deleted.",
            "error_type" => "account_deleted"
        ]);
        exit();
    }

    // Check if user is banned
    if ($user['banned_until'] !== null) {
        $banned_until = new DateTime($user['banned_until']);
        $current_time = new DateTime();
        
        if ($banned_until > $current_time) {
            $formatted_date = $banned_until->format('F j, Y \a\t g:i A');
            echo json_encode([
                "success" => false, 
                "message" => "Your account has been banned until $formatted_date.",
                "error_type" => "account_banned",
                "banned_until" => $user['banned_until']
            ]);
            exit();
        }
    }

    // Check for multiple device usage
    if ($action === 'login') {
        // Get recent login history (last 5 minutes)
        $stmt = $conn->prepare("
            SELECT id, device_info, login_timestamp, ip_address 
            FROM login_history 
            WHERE user_id = ? 
            AND login_timestamp > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
            ORDER BY login_timestamp DESC
        ");
        
        if ($stmt) {
            $stmt->bind_param("i", $userId);
            $stmt->execute();
            $recentLogins = $stmt->get_result();
            $stmt->close();

            $loginCount = $recentLogins->num_rows;
            
            if ($loginCount > 1) {
                // Check if this is a different device
                $currentDevice = $deviceInfo ?? 'Unknown Device';
                $differentDevice = false;
                
                while ($login = $recentLogins->fetch_assoc()) {
                    if ($login['device_info'] !== $currentDevice) {
                        $differentDevice = true;
                        break;
                    }
                }
                
                if ($differentDevice) {
                    echo json_encode([
                        "success" => false, 
                        "message" => "Multiple devices detected. Please use only one device at a time.",
                        "error_type" => "multiple_devices",
                        "login_count" => $loginCount
                    ]);
                    exit();
                }
            }
        }
    }

    // Clean user data before sending
    unset($user['banned_until']);
    unset($user['is_deleted']);

    // Ensure numeric values are cast to correct types and strings are properly cast
    $user_data = [
        'id' => intval($user['id']),
        'full_name' => (string)($user['full_name'] ?? ''),
        'email' => (string)($user['email'] ?? ''),
        'role' => (string)($user['role'] ?? 'user'),
        'is_verified' => (bool)$user['is_verified'],
        'profile_picture_url' => $user['profile_picture_url'] ? (string)$user['profile_picture_url'] : null,
        'address_details' => $user['address_details'] ? (string)$user['address_details'] : null,
        'latitude' => $user['latitude'] !== null ? floatval($user['latitude']) : null,
        'longitude' => $user['longitude'] !== null ? floatval($user['longitude']) : null,
        'is_available' => $user['is_available'] !== null ? (bool)$user['is_available'] : null,
        'contact_number' => $user['contact_number'] ? (string)$user['contact_number'] : null,
        'created_at' => $user['created_at'],
        'updated_at' => $user['updated_at'],
    ];

    echo json_encode([
        "success" => true,
        "message" => "User status verified successfully.",
        "user" => $user_data,
        "timestamp" => time()
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("check_user_status.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage(),
        "error_type" => "server_error"
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 