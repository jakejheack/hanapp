<?php
// update_role.php
// Handles updating user role (lister/doer)

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once 'db_connect.php';

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
    error_log("update_role.php: Raw input: " . $input);
    
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log("update_role.php: JSON decode error: " . json_last_error_msg());
        echo json_encode(["success" => false, "message" => "Invalid JSON payload."]);
        exit();
    }

    $userId = $data['user_id'] ?? null;
    $role = $data['role'] ?? null;

    error_log("update_role.php: Received data - user_id: $userId, role: $role");

    // Basic validation
    if (empty($userId) || !is_numeric($userId)) {
        error_log("update_role.php: Validation failed - Invalid user_id.");
        echo json_encode(["success" => false, "message" => "Valid user ID is required."]);
        exit();
    }

    if (empty($role) || !in_array($role, ['lister', 'doer'])) {
        error_log("update_role.php: Validation failed - Invalid role: $role");
        echo json_encode(["success" => false, "message" => "Role must be either 'lister' or 'doer'."]);
        exit();
    }

    // Check if user exists
    $checkStmt = $conn->prepare("SELECT id, full_name, email, role FROM users WHERE id = ?");
    if ($checkStmt === false) {
        error_log("update_role.php: Failed to prepare check statement: " . $conn->error);
        echo json_encode(["success" => false, "message" => "Internal server error."]);
        exit();
    }

    $checkStmt->bind_param("i", $userId);
    $checkStmt->execute();
    $checkStmt->store_result();

    if ($checkStmt->num_rows === 0) {
        error_log("update_role.php: User $userId not found.");
        echo json_encode(["success" => false, "message" => "User not found."]);
        $checkStmt->close();
        exit();
    }

    $checkStmt->bind_result($dbUserId, $fullName, $email, $currentRole);
    $checkStmt->fetch();
    $checkStmt->close();

    // Update the user's role
    $stmt = $conn->prepare("UPDATE users SET role = ? WHERE id = ?");

    if ($stmt === false) {
        error_log("update_role.php: Failed to prepare update statement: " . $conn->error);
        echo json_encode(["success" => false, "message" => "Internal server error."]);
        exit();
    }

    $stmt->bind_param("si", $role, $userId);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            error_log("update_role.php: User $userId role updated from '$currentRole' to '$role'");
            
            echo json_encode([
                "success" => true, 
                "message" => "Role updated successfully to " . ucfirst($role),
                "user" => [
                    "id" => $dbUserId,
                    "full_name" => $fullName,
                    "email" => $email,
                    "role" => $role
                ]
            ]);
        } else {
            // No rows affected means the role is already set to the requested value
            error_log("update_role.php: User $userId role already set to '$role'");
            
            echo json_encode([
                "success" => true, 
                "message" => "Role is already set to " . ucfirst($role),
                "user" => [
                    "id" => $dbUserId,
                    "full_name" => $fullName,
                    "email" => $email,
                    "role" => $role
                ]
            ]);
        }
    } else {
        error_log("update_role.php: Error executing update statement: " . $stmt->error);
        echo json_encode(["success" => false, "message" => "Failed to update role."]);
    }

    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    error_log("update_role.php: Caught exception: " . $e->getMessage());
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
}
?> 