<?php
// hanapp_backend/api/get_user_profile.php
// Handles fetching a single user's profile by ID.

require_once 'db_connect.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Get user_id from query parameters
$user_id = $_GET['user_id'] ?? '';

if (empty($user_id)) {
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit();
}

try {
    // Prepare a statement to fetch user data including contact_number and other fields
    $stmt = $conn->prepare("
        SELECT 
            id, full_name, email, role, is_verified, profile_picture_url, 
            average_rating, review_count, address_details, contact_number,
            latitude, longitude, is_available, total_profit, birthday, gender,
            created_at, updated_at, id_verified, badge_acquired, 
            verification_status, badge_status, id_photo_front_url, 
            id_photo_back_url, brgy_clearance_photo_url, live_photo_url,
            banned_until, is_deleted
        FROM users 
        WHERE id = ?
    ");
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    if ($user) {
        // Debug logging to see what we're working with
        error_log("DEBUG: get_user_profile.php - Processing user: " . $user['full_name'] . " (ID: " . $user['id'] . ")");
        error_log("DEBUG: Raw verification_status from DB: " . var_export($user['verification_status'], true) . " (type: " . gettype($user['verification_status']) . ")");
        error_log("DEBUG: Raw badge_status from DB: " . var_export($user['badge_status'], true) . " (type: " . gettype($user['badge_status']) . ")");

        // Convert string representations of numbers to actual numbers for JSON
        $user['id'] = (int)$user['id'];
        $user['is_verified'] = (bool)$user['is_verified'];
        $user['average_rating'] = (float)$user['average_rating'];
        $user['review_count'] = (int)$user['review_count'];
        $user['is_available'] = (bool)$user['is_available'];
        $user['total_profit'] = (float)$user['total_profit'];
        $user['id_verified'] = (bool)$user['id_verified'];
        $user['badge_acquired'] = (bool)$user['badge_acquired'];
        $user['is_deleted'] = (bool)$user['is_deleted'];
        
        // Ensure latitude and longitude are returned as numbers or null
        $user['latitude'] = ($user['latitude'] !== null) ? (float)$user['latitude'] : null;
        $user['longitude'] = ($user['longitude'] !== null) ? (float)$user['longitude'] : null;

        // Ensure string fields are properly cast to strings (especially important for social login users)
        $user['verification_status'] = (string)($user['verification_status'] ?? 'unverified');
        $user['badge_status'] = (string)($user['badge_status'] ?? 'none');
        $user['role'] = (string)($user['role'] ?? 'user');
        $user['full_name'] = (string)($user['full_name'] ?? '');
        $user['email'] = (string)($user['email'] ?? '');

        // Additional string casting for fields that might be problematic for social users
        $user['address_details'] = $user['address_details'] ? (string)$user['address_details'] : null;
        $user['contact_number'] = $user['contact_number'] ? (string)$user['contact_number'] : null;
        $user['gender'] = $user['gender'] ? (string)$user['gender'] : null;
        $user['birthday'] = $user['birthday'] ? (string)$user['birthday'] : null;

        // Debug logging after string casting
        error_log("DEBUG: After string casting - verification_status: " . var_export($user['verification_status'], true) . " (type: " . gettype($user['verification_status']) . ")");
        error_log("DEBUG: After string casting - badge_status: " . var_export($user['badge_status'], true) . " (type: " . gettype($user['badge_status']) . ")");
        error_log("DEBUG: After string casting - full_name: " . var_export($user['full_name'], true) . " (type: " . gettype($user['full_name']) . ")");

        // Ensure URL fields are strings or null
        $user['profile_picture_url'] = $user['profile_picture_url'] ? (string)$user['profile_picture_url'] : null;
        $user['id_photo_front_url'] = $user['id_photo_front_url'] ? (string)$user['id_photo_front_url'] : null;
        $user['id_photo_back_url'] = $user['id_photo_back_url'] ? (string)$user['id_photo_back_url'] : null;
        $user['brgy_clearance_photo_url'] = $user['brgy_clearance_photo_url'] ? (string)$user['brgy_clearance_photo_url'] : null;
        $user['live_photo_url'] = $user['live_photo_url'] ? (string)$user['live_photo_url'] : null;

        // Convert timestamps to UTC for frontend
        if ($user['created_at']) {
            $user['created_at'] = gmdate('Y-m-d H:i:s', strtotime($user['created_at']));
        }
        if ($user['updated_at']) {
            $user['updated_at'] = gmdate('Y-m-d H:i:s', strtotime($user['updated_at']));
        }
        if ($user['banned_until']) {
            $user['banned_until'] = gmdate('Y-m-d H:i:s', strtotime($user['banned_until']));
        }

        echo json_encode(["success" => true, "user" => $user]);
    } else {
        echo json_encode(["success" => false, "message" => "User not found."]);
    }

} catch (Exception $e) {
    http_response_code(500); // Internal Server Error
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
} finally {
    if (isset($conn) && $conn instanceof mysqli) {
        $conn->close();
    }
}
?> 