<?php
// login.php
// Handles user login and logs login history.

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once 'db_connect.php';
require_once 'log_login_history.php'; // Include the login history logging function

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $data = json_decode(file_get_contents("php://input"), true);

    $email = $data['email'] ?? '';
    $password = $data['password'] ?? '';
    $device_info = $data['device_info'] ?? null; // Get device info from Flutter app

    // NEW: Social login fields
    $social_login = $data['social_login'] ?? false;
    $firebase_uid = $data['firebase_uid'] ?? null;

    if (empty($email) || empty($password)) {
        echo json_encode(["success" => false, "message" => "Please enter email and password."]);
        exit();
    }

    // Modify query based on login type (using your existing column structure)
    if ($social_login && $firebase_uid) {
        // For social login, look up by email AND firebase_uid (or google_id/facebook_id)
        $stmt = $conn->prepare("SELECT id, password, full_name, role, is_verified, profile_picture_url, total_rating_sum, total_rating_count, contact_number, address_details, latitude, longitude, is_available, firebase_uid, google_id, facebook_id, login_method FROM users WHERE email = ? AND (firebase_uid = ? OR google_id = ? OR facebook_id = ?)");
        $stmt->bind_param("ssss", $email, $firebase_uid, $firebase_uid, $firebase_uid);
    } else {
        // Regular email/password login
        $stmt = $conn->prepare("SELECT id, password, full_name, role, is_verified, profile_picture_url, total_rating_sum, total_rating_count, contact_number, address_details, latitude, longitude, is_available, firebase_uid, google_id, facebook_id, login_method FROM users WHERE email = ?");
        $stmt->bind_param("s", $email);
    }
    $stmt->execute();
    $stmt->store_result();

    if ($stmt->num_rows > 0) {
        $stmt->bind_result($user_id, $hashed_password, $full_name, $role, $is_verified, $profile_picture_url, $total_rating_sum, $total_rating_count, $contact_number, $address_details, $latitude, $longitude, $is_available, $user_firebase_uid, $user_google_id, $user_facebook_id, $user_login_method);
        $stmt->fetch();

        // Handle authentication based on login type
        $auth_success = false;
        if ($social_login) {
            // For social login, verify any of the social IDs match
            if ($user_firebase_uid === $firebase_uid || $user_google_id === $firebase_uid || $user_facebook_id === $firebase_uid) {
                $auth_success = true;

                // Update last_login for social users
                $update_stmt = $conn->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
                $update_stmt->bind_param("i", $user_id);
                $update_stmt->execute();
                $update_stmt->close();
            }
        } else {
            // Regular password verification for email/password login
            if (password_verify($password, $hashed_password)) {
                $auth_success = true;
            }
        }

        if ($auth_success) {
            if (!$is_verified) {
                echo json_encode(["success" => false, "message" => "Please verify your email first."]);
            } else {
                // --- LOGIN HISTORY LOGGING ---
                logLoginHistory($conn, $user_id, null, $device_info, null); // Pass device info from Flutter
                // --- END LOGIN HISTORY LOGGING ---
                
                $average_rating = ($total_rating_count > 0) ? round($total_rating_sum / $total_rating_count, 1) : 0.0;
                echo json_encode([
                    "success" => true,
                    "message" => "Login successful.",
                    "user" => [
                        "id" => $user_id,
                        "full_name" => $full_name,
                        "email" => $email,
                        "role" => $role,
                        "is_verified" => (bool)$is_verified,
                        "profile_picture_url" => $profile_picture_url,
                        "average_rating" => $average_rating,
                        "review_count" => $total_rating_count,
                        "contact_number" => $contact_number,
                        "address_details" => $address_details,
                        "latitude" => $latitude,
                        "longitude" => $longitude,
                        "is_available" => (bool)$is_available
                    ]
                ]);
            }
        } else {
            if ($social_login) {
                echo json_encode(["success" => false, "message" => "Invalid social login credentials."]);
            } else {
                echo json_encode(["success" => false, "message" => "Invalid credentials."]);
            }
        }
    } else {
        echo json_encode(["success" => false, "message" => "Invalid credentials."]);
    }

    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    error_log("login.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
} 