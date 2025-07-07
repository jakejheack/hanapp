<?php
// hanapp_backend/api/auth/login.php
// Handles user login and logs login history.

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../config/db_connect.php'; // Adjust path as needed

// Force cache bypass - add unique timestamp to prevent any caching
$unique_id = uniqid('login_', true);
$timestamp = microtime(true);

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Cache-Bust, X-Requested-With, X-Retry-Count");
header("Cache-Control: no-cache, no-store, must-revalidate, max-age=0, private, no-transform");
header("Pragma: no-cache");
header("Expires: -1");
header("X-Content-Type-Options: nosniff");
header("X-Frame-Options: DENY");
header("X-XSS-Protection: 1; mode=block");
header("X-Cache-Status: BYPASS");
header("X-Cache-Control: no-cache");
header("X-Response-Time: $timestamp");
header("X-Response-ID: $unique_id");
header("X-No-Cache: true");
header("X-Accel-Buffering: no");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Force cache bypass by checking for cache-busting headers
$cache_bust = $_SERVER['HTTP_X_CACHE_BUST'] ?? $_POST['_cache_bust'] ?? null;
$retry_count = $_SERVER['HTTP_X_RETRY_COUNT'] ?? 0;
$is_retry = isset($_POST['_retry']) && $_POST['_retry'] === 'true';

// Log cache-busting info for debugging
error_log("login.php: Cache bust: $cache_bust, Retry count: $retry_count, Is retry: " . ($is_retry ? 'true' : 'false'));

try {
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log("login.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        throw new Exception("Invalid JSON payload.");
    }

    $email = $data['email'] ?? null;
    $password = $data['password'] ?? null;

    if (empty($email) || empty($password)) {
        echo json_encode(["success" => false, "message" => "Email and password are required."]);
        exit();
    }

    $stmt = $conn->prepare("
        SELECT
            id, full_name, email, password, profile_picture_url, address_details, latitude, longitude, role, is_available, contact_number,
            banned_until, is_deleted
        FROM
            users
        WHERE
            email = ?
    ");

    if ($stmt === false) {
        error_log("login.php: Failed to prepare statement: " . $conn->error, 0);
        throw new Exception("Failed to prepare database statement.");
    }

    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    // Debug: Log the entire user data
    error_log("login.php: Full user data: " . json_encode($user));

    if ($user && password_verify($password, $user['password'])) {
        // Debug logging
        error_log("login.php: User found, is_deleted value: " . var_export($user['is_deleted'], true));
        error_log("login.php: is_deleted type: " . gettype($user['is_deleted']));
        error_log("login.php: is_deleted == 1 comparison: " . var_export($user['is_deleted'] == 1, true));
        error_log("login.php: is_deleted === '1' comparison: " . var_export($user['is_deleted'] === '1', true));
        error_log("login.php: is_deleted === true comparison: " . var_export($user['is_deleted'] === true, true));
        
        // Check if user is deleted
        if ($user['is_deleted'] == 1 || $user['is_deleted'] === '1' || $user['is_deleted'] === true) {
            error_log("login.php: User is deleted, blocking login");
            error_log("login.php: Sending error response for deleted account");
            http_response_code(403); // Set proper HTTP status code
            $error_response = [
                "success" => false, 
                "message" => "Account has been deleted.",
                "error_type" => "account_deleted",
                "timestamp" => time(),
                "response_id" => uniqid('del_', true),
                "debug_info" => "User ID: " . $user['id'] . ", is_deleted: " . $user['is_deleted']
            ];
            error_log("login.php: Error response JSON: " . json_encode($error_response));
            echo json_encode($error_response);
            error_log("login.php: Error response sent, exiting");
            exit();
        }

        // Debug: Log the is_deleted value for troubleshooting
        error_log("login.php: User is NOT deleted, is_deleted value: " . var_export($user['is_deleted'], true));

        // Check if user is banned
        if ($user['banned_until'] !== null) {
            $banned_until = new DateTime($user['banned_until']);
            $current_time = new DateTime();
            
            if ($banned_until > $current_time) {
                // User is still banned
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

        // Successful login
        // Remove sensitive data (password_hash) before sending to client
        unset($user['password']);
        unset($user['banned_until']);
        unset($user['is_deleted']);

        // Ensure numeric values are cast to correct types if needed
        $user_data = [
            'id' => intval($user['id']),
            'full_name' => $user['full_name'],
            'email' => $user['email'],
            'profile_picture_url' => $user['profile_picture_url'],
            'address_details' => $user['address_details'],
            'latitude' => $user['latitude'] !== null ? floatval($user['latitude']) : null,
            'longitude' => $user['longitude'] !== null ? floatval($user['longitude']) : null,
            'role' => $user['role'],
            'is_available' => $user['is_available'] !== null ? (bool)$user['is_available'] : null,
            'contact_number' => $user['contact_number'],
        ];

        // --- LOGIN HISTORY LOGGING ---
        $user_id = intval($user['id']);
        $device_info = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
        $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';
        $location = 'Unknown';
        $ip = $ip_address;
        $geo = @json_decode(file_get_contents("http://ip-api.com/json/$ip"));
        if ($geo && $geo->status === 'success') {
            $location = $geo->city . ', ' . $geo->country;
        }
        // Insert into login_history (do not block login if this fails)
        try {
            $stmt_history = $conn->prepare("INSERT INTO login_history (user_id, login_timestamp, location, device_info, ip_address) VALUES (?, NOW(), ?, ?, ?)");
            if ($stmt_history) {
                $stmt_history->bind_param("isss", $user_id, $location, $device_info, $ip_address);
                $stmt_history->execute();
                $stmt_history->close();
            }
        } catch (Exception $e) {
            error_log("login.php: Failed to insert login history: " . $e->getMessage(), 0);
        }
        // --- END LOGIN HISTORY LOGGING ---

        echo json_encode([
            "success" => true,
            "message" => "Login successful!",
            "user" => $user_data, // Send the cleaned user data
            "response_id" => uniqid('login_', true),
            "timestamp" => time()
        ]);
        exit();
    } else {
        echo json_encode(["success" => false, "message" => "Invalid email or password."]);
        exit();
    }

} catch (Exception $e) {
    http_response_code(500);
    error_log("login.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
} 