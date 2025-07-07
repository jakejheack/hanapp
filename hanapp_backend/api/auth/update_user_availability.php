<?php
// hanapp_backend/api/auth/update_user_availability.php
// Updates the 'is_available' status for a user (typically a doer).

// --- DEBUGGING: Temporarily enable error display for development ---
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
// --- END DEBUGGING ---

require_once '../config/db_connect.php'; // Adjust path as needed

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (!isset($conn) || $conn->connect_error) {
    error_log("update_user_availability.php: Database connection not established: " . $conn->connect_error);
    echo json_encode(["success" => false, "message" => "Database connection not established."]);
    exit();
}

$input = file_get_contents("php://input");
error_log("update_user_availability.php: Raw input: " . $input);
$data = json_decode($input, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    error_log("update_user_availability.php: JSON decode error: " . json_last_error_msg());
    echo json_encode(["success" => false, "message" => "Invalid JSON payload."]);
    exit();
}

$userId = $data['user_id'] ?? null;
$isAvailable = $data['is_available'] ?? null;

error_log("update_user_availability.php: Received data - user_id: $userId, is_available: " . var_export($isAvailable, true));

// Basic validation
if (empty($userId) || !is_numeric($userId)) {
    error_log("update_user_availability.php: Validation failed - Invalid user_id.");
    echo json_encode(["success" => false, "message" => "Valid user ID is required."]);
    exit();
}

if (!isset($isAvailable) || !is_bool($isAvailable)) {
    error_log("update_user_availability.php: Validation failed - is_available must be a boolean.");
    echo json_encode(["success" => false, "message" => "Availability status must be a boolean value."]);
    exit();
}

// First, check if the user exists and is a doer
$checkStmt = $conn->prepare("SELECT id, role, full_name, email, is_verified, profile_picture_url FROM users WHERE id = ?");
if ($checkStmt === false) {
    error_log("update_user_availability.php: Failed to prepare check statement: " . $conn->error);
    echo json_encode(["success" => false, "message" => "Internal server error."]);
    exit();
}

$checkStmt->bind_param("i", $userId);
$checkStmt->execute();
$checkStmt->store_result();

if ($checkStmt->num_rows === 0) {
    error_log("update_user_availability.php: User $userId not found.");
    echo json_encode(["success" => false, "message" => "User not found."]);
    $checkStmt->close();
    exit();
}

$checkStmt->bind_result($dbUserId, $role, $fullName, $email, $isVerified, $profilePictureUrl);
$checkStmt->fetch();
$checkStmt->close();

// Check if user is a doer (only doers can have availability status)
if ($role !== 'doer') {
    error_log("update_user_availability.php: User $userId is not a doer (role: $role).");
    echo json_encode(["success" => false, "message" => "Only doers can update availability status."]);
    exit();
}

// Convert boolean to integer for database storage
$isAvailableInt = $isAvailable ? 1 : 0;

// Prepare and execute the update statement
$stmt = $conn->prepare("UPDATE users SET is_available = ? WHERE id = ?");

if ($stmt === false) {
    error_log("update_user_availability.php: Failed to prepare update statement: " . $conn->error);
    echo json_encode(["success" => false, "message" => "Internal server error."]);
    exit();
}

$stmt->bind_param("ii", $isAvailableInt, $userId);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        error_log("update_user_availability.php: User $userId availability updated to " . ($isAvailable ? 'true' : 'false'));
        
        // Return updated user data for the Flutter app
        echo json_encode([
            "success" => true, 
            "message" => "Availability status updated successfully.",
            "user" => [
                "id" => $dbUserId,
                "full_name" => $fullName,
                "email" => $email,
                "role" => $role,
                "is_verified" => (bool)$isVerified,
                "profile_picture_url" => $profilePictureUrl,
                "is_available" => $isAvailable
            ]
        ]);
    } else {
        // No rows affected means the status is already set to the requested value
        // This is actually a success case, not an error
        error_log("update_user_availability.php: User $userId status already set to " . ($isAvailable ? 'true' : 'false'));
        
        echo json_encode([
            "success" => true, 
            "message" => "Availability status is already " . ($isAvailable ? 'ON' : 'OFF'),
            "user" => [
                "id" => $dbUserId,
                "full_name" => $fullName,
                "email" => $email,
                "role" => $role,
                "is_verified" => (bool)$isVerified,
                "profile_picture_url" => $profilePictureUrl,
                "is_available" => $isAvailable
            ]
        ]);
    }
} else {
    error_log("update_user_availability.php: Error executing update statement: " . $stmt->error);
    echo json_encode(["success" => false, "message" => "Failed to update availability status."]);
}

$stmt->close();
$conn->close();
?> 