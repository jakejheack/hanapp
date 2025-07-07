<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0);

// Start output buffering
ob_start();

// Set headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Function to send JSON response and exit
function sendJsonResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

// Check request method
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(['error' => 'Method not allowed'], 405);
}

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (json_last_error() !== JSON_ERROR_NONE) {
    sendJsonResponse(['error' => 'Invalid JSON input'], 400);
}

if (!isset($input['email']) || empty($input['email']) || 
    !isset($input['code']) || empty($input['code']) ||
    !isset($input['new_password']) || empty($input['new_password'])) {
    sendJsonResponse(['error' => 'Email, code, and new password are required'], 400);
}

$email = filter_var($input['email'], FILTER_SANITIZE_EMAIL);
$code = filter_var($input['code'], FILTER_SANITIZE_STRING);
$new_password = $input['new_password'];

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    sendJsonResponse(['error' => 'Invalid email format'], 400);
}

if (strlen($new_password) < 6) {
    sendJsonResponse(['error' => 'Password must be at least 6 characters long'], 400);
}

// Database connection
require_once 'db_connect.php';

try {
    // Check if code exists and is valid
    $stmt = $conn->prepare("SELECT * FROM password_reset_codes WHERE email = ? AND code = ? AND expires_at > NOW() AND used = 0");
    $stmt->bind_param("ss", $email, $code);
    $stmt->execute();
    $result = $stmt->get_result();
    $resetCode = $result->fetch_assoc();
    
    if (!$resetCode) {
        sendJsonResponse(['error' => 'Invalid or expired code'], 400);
    }
    
    // Hash the new password
    $hashed_password = password_hash($new_password, PASSWORD_DEFAULT);
    
    // Update user's password
    $stmt = $conn->prepare("UPDATE users SET password = ? WHERE email = ?");
    $stmt->bind_param("ss", $hashed_password, $email);
    $stmt->execute();
    
    if ($stmt->affected_rows > 0) {
        // Mark code as used
        $stmt = $conn->prepare("UPDATE password_reset_codes SET used = 1 WHERE id = ?");
        $stmt->bind_param("i", $resetCode['id']);
        $stmt->execute();
        
        sendJsonResponse(['success' => true, 'message' => 'Password updated successfully']);
    } else {
        sendJsonResponse(['error' => 'User not found'], 404);
    }
    
} catch (Exception $e) {
    sendJsonResponse(['error' => 'Database error: ' . $e->getMessage()], 500);
}
?> 