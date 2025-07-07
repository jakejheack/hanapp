<?php
// update_user_availability.php
// Handles updating user availability status for doers

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once 'db_connect.php';

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

    $user_id = $data['user_id'] ?? null;
    $is_available = $data['is_available'] ?? null;

    if ($user_id === null || $is_available === null) {
        echo json_encode(["success" => false, "message" => "Missing required fields: user_id and is_available"]);
        exit();
    }

    // Validate user_id is a positive integer
    if (!is_numeric($user_id) || $user_id <= 0) {
        echo json_encode(["success" => false, "message" => "Invalid user_id"]);
        exit();
    }

    // Validate is_available is boolean
    if (!is_bool($is_available)) {
        echo json_encode(["success" => false, "message" => "is_available must be a boolean value"]);
        exit();
    }

    // First, check if the user exists and is a doer
    $stmt = $conn->prepare("SELECT id, role FROM users WHERE id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $stmt->store_result();

    if ($stmt->num_rows === 0) {
        echo json_encode(["success" => false, "message" => "User not found"]);
        exit();
    }

    $stmt->bind_result($db_user_id, $role);
    $stmt->fetch();
    $stmt->close();

    // Check if user is a doer (only doers can have availability status)
    if ($role !== 'doer') {
        echo json_encode(["success" => false, "message" => "Only doers can update availability status"]);
        exit();
    }

    // Update the user's availability status
    $stmt = $conn->prepare("UPDATE users SET is_available = ? WHERE id = ?");
    $stmt->bind_param("ii", $is_available ? 1 : 0, $user_id);
    $update_result = $stmt->execute();

    if ($update_result) {
        // Fetch updated user data to return
        $stmt = $conn->prepare("SELECT id, full_name, email, role, is_verified, profile_picture_url, is_available FROM users WHERE id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $stmt->store_result();
        $stmt->bind_result($updated_id, $full_name, $email, $updated_role, $is_verified, $profile_picture_url, $updated_is_available);
        $stmt->fetch();
        $stmt->close();

        echo json_encode([
            "success" => true,
            "message" => "Availability status updated successfully",
            "user" => [
                "id" => $updated_id,
                "full_name" => $full_name,
                "email" => $email,
                "role" => $updated_role,
                "is_verified" => (bool)$is_verified,
                "profile_picture_url" => $profile_picture_url,
                "is_available" => (bool)$updated_is_available
            ]
        ]);
    } else {
        echo json_encode(["success" => false, "message" => "Failed to update availability status"]);
    }

    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    error_log("update_user_availability.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
} 
?> 