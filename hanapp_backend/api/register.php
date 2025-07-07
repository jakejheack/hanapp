<?php
// hanapp_backend/api/register.php
// User registration with base64 profile image support

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

    // Extract data
    $firstName = $input['first_name'] ?? null;
    $middleName = $input['middle_name'] ?? null;
    $lastName = $input['last_name'] ?? null;
    $birthday = $input['birthday'] ?? null;
    $addressDetails = $input['address_details'] ?? null;
    $gender = $input['gender'] ?? null;
    $contactNumber = $input['contact_number'] ?? null;
    $email = $input['email'] ?? null;
    $password = $input['password'] ?? null;
    $role = $input['role'] ?? null;
    $latitude = $input['latitude'] ?? null;
    $longitude = $input['longitude'] ?? null;
    $profileImageBase64 = $input['profile_image_base64'] ?? null;

    // NEW: Social login fields (using your existing column names)
    $profilePictureUrl = $input['profile_picture_url'] ?? null;
    $firebaseUid = $input['firebase_uid'] ?? null;
    $authProvider = $input['auth_provider'] ?? 'email';
    $loginMethod = $input['auth_provider'] ?? 'email'; // Maps to your login_method column
    $isVerified = $input['is_verified'] ?? false;
    $socialRegistration = $input['social_registration'] ?? false;
    $googleId = ($authProvider === 'google') ? $firebaseUid : null;
    $facebookId = ($authProvider === 'facebook') ? $firebaseUid : null;

    // Validate required fields (relaxed for social registration)
    if (!$firstName || !$lastName || !$email || !$password || !$role) {
        throw new Exception('Missing required fields: first_name, last_name, email, password, role');
    }

    // For social registrations, allow some fields to be empty
    if ($socialRegistration) {
        $birthday = $birthday ?: '1990-01-01';
        $addressDetails = $addressDetails ?: '';
        $gender = $gender ?: '';
        $contactNumber = $contactNumber ?: '';
    }

    // Validate email format
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
    }

    // Check if email already exists (also check social IDs)
    if ($firebaseUid) {
        $checkStmt = $conn->prepare("SELECT id FROM users WHERE email = ? OR firebase_uid = ? OR google_id = ? OR facebook_id = ?");
        $checkStmt->bind_param('ssss', $email, $firebaseUid, $googleId, $facebookId);
    } else {
        $checkStmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
        $checkStmt->bind_param('s', $email);
    }
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();

    if ($checkResult->num_rows > 0) {
        throw new Exception('Email or account is already registered');
    }

    // Validate and process base64 profile image (skip if social profile URL is provided)
    if (!$profilePictureUrl && $profileImageBase64) {
        // Remove data:image/jpeg;base64, prefix if present
        $base64Data = preg_replace('/^data:image\/[a-zA-Z]+;base64,/', '', $profileImageBase64);
        
        // Validate base64 format
        if (!preg_match('%^[a-zA-Z0-9/+]*={0,2}$%', $base64Data)) {
            throw new Exception('Invalid base64 image format');
        }

        // Decode and validate image
        $imageData = base64_decode($base64Data);
        if ($imageData === false) {
            throw new Exception('Failed to decode base64 image');
        }

        // Check file size (max 5MB)
        if (strlen($imageData) > 5 * 1024 * 1024) {
            throw new Exception('Image size too large. Maximum size is 5MB.');
        }

        // Validate image format
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_buffer($finfo, $imageData);
        finfo_close($finfo);

        $allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
        if (!in_array($mimeType, $allowedMimeTypes)) {
            throw new Exception('Invalid image format. Only JPG, PNG, and GIF are allowed.');
        }

        // Store base64 data directly in database
        $profilePictureUrl = $profileImageBase64;
    }

    // Hash password
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

    // Combine first, middle, and last name
    $fullName = trim($firstName . ' ' . ($middleName ? $middleName . ' ' : '') . $lastName);

    // Insert new user (using your existing column structure)
    $stmt = $conn->prepare("
        INSERT INTO users (
            first_name, middle_name, last_name, full_name, birthday,
            address_details, gender, contact_number, email, password,
            role, latitude, longitude, profile_picture_url, firebase_uid,
            auth_provider, login_method, google_id, facebook_id, is_verified, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ");

    $stmt->bind_param(
        'ssssssssssddssssssi',
        $firstName,
        $middleName,
        $lastName,
        $fullName,
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
        $authProvider,
        $loginMethod,
        $googleId,
        $facebookId,
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

    // Convert server local timestamps to UTC for frontend
    $user['created_at'] = $user['created_at'] ? gmdate('Y-m-d H:i:s', strtotime($user['created_at'])) : null;
    $user['updated_at'] = $user['updated_at'] ? gmdate('Y-m-d H:i:s', strtotime($user['updated_at'])) : null;

    echo json_encode([
        'success' => true,
        'message' => 'Registration successful',
        'user' => [
            'id' => $user['id'],
            'first_name' => $user['first_name'],
            'middle_name' => $user['middle_name'],
            'last_name' => $user['last_name'],
            'full_name' => $user['full_name'],
            'email' => $user['email'],
            'role' => $user['role'],
            'profile_picture_url' => $user['profile_picture_url'],
            'address_details' => $user['address_details'],
            'contact_number' => $user['contact_number'],
            'latitude' => $user['latitude'],
            'longitude' => $user['longitude'],
            'is_verified' => (bool)$user['is_verified'],
            'is_available' => (bool)$user['is_available'],
            'average_rating' => (float)$user['average_rating'],
            'total_reviews' => (int)$user['review_count'],
            'is_id_verified' => (bool)$user['id_verified'],
            'is_badge_acquired' => (bool)$user['badge_acquired'],
            'verification_status' => $user['verification_status'],
            'badge_status' => $user['badge_status'],
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at'],
        ]
    ]);

} catch (Exception $e) {
    error_log("register.php error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
} 