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
    // Prepare a statement to fetch user data including ALL fields the Flutter app expects
    $stmt = $conn->prepare("
        SELECT 
            id, full_name, first_name, middle_name, last_name, email, role, is_verified, profile_picture_url, 
            average_rating, review_count, total_reviews, address_details, contact_number,
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
        // Convert string representations of numbers to actual numbers for JSON
        $user['id'] = (int)$user['id'];
        $user['is_verified'] = (bool)$user['is_verified'];
        $user['average_rating'] = (float)$user['average_rating'];
        $user['review_count'] = (int)$user['review_count'];
        $user['total_reviews'] = (int)$user['total_reviews'];
        $user['is_available'] = (bool)$user['is_available'];
        $user['total_profit'] = (float)$user['total_profit'];
        $user['id_verified'] = (bool)$user['id_verified'];
        $user['badge_acquired'] = (bool)$user['badge_acquired'];
        $user['is_deleted'] = (bool)$user['is_deleted'];
        
        // Ensure latitude and longitude are returned as numbers or null
        $user['latitude'] = ($user['latitude'] !== null) ? (float)$user['latitude'] : null;
        $user['longitude'] = ($user['longitude'] !== null) ? (float)$user['longitude'] : null;

        // Ensure string fields are properly handled (convert empty strings to null where appropriate)
        $stringFields = ['first_name', 'middle_name', 'last_name', 'address_details', 'contact_number', 'gender', 'profile_picture_url'];
        foreach ($stringFields as $field) {
            if (isset($user[$field]) && $user[$field] === '') {
                $user[$field] = null;
            }
        }

        // Ensure verification status fields have proper defaults
        $user['verification_status'] = $user['verification_status'] ?: 'unverified';
        $user['badge_status'] = $user['badge_status'] ?: 'none';
        $user['role'] = $user['role'] ?: 'user';

        // Convert timestamps to UTC for frontend
        if ($user['created_at']) {
            $user['created_at'] = gmdate('Y-m-d H:i:s', strtotime($user['created_at']));
        }
        if ($user['updated_at']) {
            $user['updated_at'] = gmdate('Y-m-d H:i:s', strtotime($user['updated_at']));
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
