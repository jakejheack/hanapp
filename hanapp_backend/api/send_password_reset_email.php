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

if (!isset($input['email']) || empty($input['email'])) {
    sendJsonResponse(['error' => 'Email is required'], 400);
}

$email = filter_var($input['email'], FILTER_SANITIZE_EMAIL);

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    sendJsonResponse(['error' => 'Invalid email format'], 400);
}

// Database connection
require_once 'db_connect.php';

try {
    // Check if user exists
    $stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if (!$result->fetch_assoc()) {
        sendJsonResponse(['error' => 'User not found'], 404);
    }
    
    // Check if password_reset_codes table exists
    $stmt = $conn->prepare("SHOW TABLES LIKE 'password_reset_codes'");
    $stmt->execute();
    $result = $stmt->get_result();
    if (!$result->fetch_assoc()) {
        // Create the table if it doesn't exist
        $createTable = "CREATE TABLE password_reset_codes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            email VARCHAR(255) NOT NULL,
            code VARCHAR(6) NOT NULL,
            expires_at DATETIME NOT NULL,
            used TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )";
        $conn->query($createTable);
    }
    
    // Generate 6-digit code
    $code = sprintf('%06d', mt_rand(0, 999999));
    $expires_at = date('Y-m-d H:i:s', strtotime('+10 minutes'));
    
    // Delete any existing codes for this email
    $stmt = $conn->prepare("DELETE FROM password_reset_codes WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    
    // Insert new code
    $stmt = $conn->prepare("INSERT INTO password_reset_codes (email, code, expires_at) VALUES (?, ?, ?)");
    $stmt->bind_param("sss", $email, $code, $expires_at);
    $stmt->execute();
    
    // Send email with code using a more reliable method
    $to = $email;
    $subject = "Password Reset Code - HanApp";
    $message = "Your password reset code is: $code\n\n";
    $message .= "This code will expire in 10 minutes.\n";
    $message .= "If you didn't request this, please ignore this email.\n\n";
    $message .= "Best regards,\nHanApp Team";
    
    // Try multiple email sending methods
    $emailSent = false;
    
    // Method 1: Try using mail() with proper headers
    $headers = "From: noreply@autosell.io\r\n";
    $headers .= "Reply-To: noreply@autosell.io\r\n";
    $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
    $headers .= "X-Mailer: PHP/" . phpversion() . "\r\n";
    
    if (mail($to, $subject, $message, $headers)) {
        $emailSent = true;
    }
    
    // Method 2: If mail() fails, try without extra headers
    if (!$emailSent) {
        if (mail($to, $subject, $message)) {
            $emailSent = true;
        }
    }
    
    // Method 3: Try with different from address
    if (!$emailSent) {
        $headers = "From: HanApp <noreply@autosell.io>\r\n";
        $headers .= "Content-Type: text/plain; charset=UTF-8\r\n";
        
        if (mail($to, $subject, $message, $headers)) {
            $emailSent = true;
        }
    }
    
    if ($emailSent) {
        sendJsonResponse(['success' => true, 'message' => 'Password reset code sent to your email']);
    } else {
        // If email fails, still return success but with a note
        // This allows testing without email setup
        sendJsonResponse([
            'success' => true, 
            'message' => 'Password reset code generated successfully. Email sending failed, but you can use the code for testing.',
            'debug_code' => $code, // Only for testing - remove in production
            'note' => 'Email service not configured. Contact your hosting provider to enable email sending.'
        ]);
    }
    
} catch (PDOException $e) {
    sendJsonResponse(['error' => 'Database error: ' . $e->getMessage()], 500);
} catch (Exception $e) {
    sendJsonResponse(['error' => 'General error: ' . $e->getMessage()], 500);
}
?> 