<?php
// Prevent any output before headers
ob_start();

// Set error handling
ini_set('display_errors', 0); // Don't display errors as HTML
ini_set('log_errors', 1);
error_reporting(E_ALL);

// Set JSON headers immediately
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Include database connection
    require_once '../../config/server.php';
    
    // Get JSON input
    $input = file_get_contents("php://input");
    if (empty($input)) {
        throw new Exception("No input data received");
    }
    
    $data = json_decode($input);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("Invalid JSON format: " . json_last_error_msg());
    }

    // Check if user_id and role are provided
    if (!isset($data->user_id) || !isset($data->role)) {
        throw new Exception("User ID and role are required.");
    }

    $userId = $data->user_id;
    $newRole = $data->role;

    // Validate the role to ensure it's either 'doer' or 'lister'
    if (!in_array($newRole, ['doer', 'lister'])) {
        throw new Exception("Invalid role specified. Role must be 'doer' or 'lister'.");
    }

    // Validate user_id is numeric
    if (!is_numeric($userId)) {
        throw new Exception("User ID must be a number.");
    }

    // Check if user exists first
    $checkStmt = $pdo->prepare("SELECT id FROM users WHERE id = :user_id");
    $checkStmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
    $checkStmt->execute();
    
    if ($checkStmt->rowCount() === 0) {
        throw new Exception("User not found with ID: " . $userId);
    }

    // Prepare the SQL statement to update the user's role
    $stmt = $pdo->prepare("UPDATE users SET role = :role WHERE id = :user_id");
    $stmt->bindParam(':role', $newRole, PDO::PARAM_STR);
    $stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);

    // Execute the statement
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        echo json_encode([
            "success" => true, 
            "message" => "User role updated successfully to " . $newRole . "."
        ]);
    } else {
        echo json_encode([
            "success" => true, 
            "message" => "Role is already set to " . $newRole . "."
        ]);
    }

} catch (PDOException $e) {
    // Log the error
    error_log("Database error in update_role.php: " . $e->getMessage());
    
    echo json_encode([
        "success" => false, 
        "message" => "Database error occurred. Please try again later."
    ]);
} catch (Exception $e) {
    // Log the error
    error_log("Error in update_role.php: " . $e->getMessage());
    
    echo json_encode([
        "success" => false, 
        "message" => $e->getMessage()
    ]);
}

// Clear any output buffer
ob_end_flush();
?> 