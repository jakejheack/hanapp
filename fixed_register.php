<?php
// fixed_register.php - Simplified version that works with your database structure
// Replace your existing register.php with this content

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once 'config/db_connect.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method is allowed');
    }

    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }

    // Extract basic data
    $firstName = $input['first_name'] ?? null;
    $middleName = $input['middle_name'] ?? '';
    $lastName = $input['last_name'] ?? null;
    $birthday = $input['birthday'] ?? '1990-01-01';
    $addressDetails = $input['address_details'] ?? '';
    $gender = $input['gender'] ?? '';
    $contactNumber = $input['contact_number'] ?? '';
    $email = $input['email'] ?? null;
    $password = $input['password'] ?? null;
    $role = $input['role'] ?? null;
    $latitude = $input['latitude'] ?? null;
    $longitude = $input['longitude'] ?? null;
    $profileImageBase64 = $input['profile_image_base64'] ?? null;

    // Social login fields
    $profilePictureUrl = $input['profile_picture_url'] ?? null;
    $firebaseUid = $input['firebase_uid'] ?? null;
    $authProvider = $input['auth_provider'] ?? 'email';
    $isVerified = $input['is_verified'] ?? false;
    $socialRegistration = $input['social_registration'] ?? false;

    // Map to your database columns
    $loginMethod = $authProvider; // Maps to login_method column
    $googleId = ($authProvider === 'google') ? $firebaseUid : null;
    $facebookId = ($authProvider === 'facebook') ? $firebaseUid : null;

    // For social registrations, allow some fields to be empty
    if ($socialRegistration) {
        $birthday = $birthday ?: '1990-01-01';
        $addressDetails = $addressDetails ?: '';
        $gender = $gender ?: '';
        $contactNumber = $contactNumber ?: '';
    }

    // Validate required fields
    if (!$firstName || !$lastName || !$email || !$password || !$role) {
        throw new Exception('Missing required fields: first_name, last_name, email, password, role');
    }

    // Validate email format
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
    }

    // Check if email already exists
    $checkEmailStmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $checkEmailStmt->bind_param('s', $email);
    $checkEmailStmt->execute();
    $emailResult = $checkEmailStmt->get_result();
    
    if ($emailResult->num_rows > 0) {
        throw new Exception('Email is already registered');
    }

    // Handle profile picture
    if (!$profilePictureUrl && $profileImageBase64) {
        // Process base64 image (simplified)
        $base64Data = preg_replace('/^data:image\/[a-zA-Z]+;base64,/', '', $profileImageBase64);
        if (preg_match('%^[a-zA-Z0-9/+]*={0,2}$%', $base64Data)) {
            $profilePictureUrl = $profileImageBase64;
        }
    }

    // Hash password
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

    // Combine names
    $fullName = trim($firstName . ' ' . ($middleName ? $middleName . ' ' : '') . $lastName);

    // Insert new user - using your exact database structure
    $stmt = $conn->prepare("
        INSERT INTO users (
            full_name, first_name, middle_name, last_name, birthday,
            address_details, gender, contact_number, email, password,
            role, latitude, longitude, profile_picture_url, firebase_uid,
            google_id, facebook_id, login_method, auth_provider, is_verified,
            created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ");

    $stmt->bind_param(
        'ssssssssssddsssssssi',
        $fullName,
        $firstName,
        $middleName,
        $lastName,
        $birthday,
        $addressDetails,
        $gender,
        $contactNumber,
        $email,
        $hashedPassword,
        $role,
        $latitude,
        $longitude,
        $profilePictureUrl,
        $firebaseUid,
        $googleId,
        $facebookId,
        $loginMethod,
        $authProvider,
        $isVerified
    );

    if (!$stmt->execute()) {
        throw new Exception('Failed to create user: ' . $stmt->error);
    }

    $userId = $conn->insert_id;

    // Fetch the created user
    $fetchStmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
    $fetchStmt->bind_param('i', $userId);
    $fetchStmt->execute();
    $result = $fetchStmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('Failed to fetch created user');
    }

    $user = $result->fetch_assoc();

    echo json_encode([
        'success' => true,
        'message' => 'Registration successful',
        'user' => [
            'id' => (int)$user['id'],
            'full_name' => $user['full_name'],
            'email' => $user['email'],
            'role' => $user['role'],
            'profile_picture_url' => $user['profile_picture_url'],
            'is_verified' => (bool)$user['is_verified'],
            'is_available' => (bool)$user['is_available'],
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at']
        ]
    ]);

} catch (Exception $e) {
    error_log("register.php error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
