<?php
// debug_register.php - Upload this to test what's causing the 500 error
// Place this at: public_html/api/debug_register.php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Enable error reporting
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $debug_steps = [];
    $debug_steps[] = 'Starting debug...';

    // Test database connection
    require_once 'config/db_connect.php';
    $debug_steps[] = 'Database connection loaded';

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method is allowed');
    }

    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    $debug_steps[] = 'JSON input received';

    if (!$input) {
        throw new Exception('Invalid JSON input');
    }

    // Extract data
    $firstName = $input['first_name'] ?? null;
    $lastName = $input['last_name'] ?? null;
    $email = $input['email'] ?? null;
    $password = $input['password'] ?? null;
    $role = $input['role'] ?? null;

    $debug_steps[] = 'Basic fields extracted: ' . json_encode([
        'first_name' => $firstName,
        'last_name' => $lastName,
        'email' => $email,
        'role' => $role
    ]);

    // Validate required fields
    if (!$firstName || !$lastName || !$email || !$password || !$role) {
        throw new Exception('Missing required fields: first_name, last_name, email, password, role');
    }

    $debug_steps[] = 'Required fields validated';

    // Check if email already exists
    $checkStmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $checkStmt->bind_param('s', $email);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();

    if ($checkResult->num_rows > 0) {
        throw new Exception('Email is already registered');
    }

    $debug_steps[] = 'Email check passed';

    // Hash password
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
    $fullName = trim($firstName . ' ' . $lastName);

    $debug_steps[] = 'Password hashed, ready to insert';

    // Simple insert to test
    $stmt = $conn->prepare("
        INSERT INTO users (
            first_name, last_name, full_name, email, password, role, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, NOW())
    ");

    $stmt->bind_param('ssssss', $firstName, $lastName, $fullName, $email, $hashedPassword, $role);

    $debug_steps[] = 'Prepared statement ready';

    if (!$stmt->execute()) {
        throw new Exception('Failed to create user: ' . $stmt->error);
    }

    $userId = $conn->insert_id;
    $debug_steps[] = 'User created successfully';

    echo json_encode([
        'success' => true,
        'message' => 'Debug registration successful',
        'user_id' => $userId,
        'debug_steps' => $debug_steps,
        'user' => [
            'id' => $userId,
            'full_name' => $fullName,
            'email' => $email,
            'role' => $role,
            'is_verified' => false,
            'is_available' => true
        ]
    ]);

} catch (Exception $e) {
    error_log("debug_register.php error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'debug_steps' => $debug_steps ?? ['Error occurred before debug steps were initialized'],
        'file' => basename(__FILE__),
        'line' => $e->getLine()
    ]);
}
?>
