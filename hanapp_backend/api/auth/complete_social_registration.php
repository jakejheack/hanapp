<?php
// hanapp_backend/api/auth/complete_social_registration.php
// Complete social login registration with missing information

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../config/db_connect.php';

function sendJsonResponse($data, $statusCode = 200) {
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

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
    $socialUserData = $input['social_user_data'] ?? [];
    $firstName = trim($input['first_name'] ?? '');
    $middleName = trim($input['middle_name'] ?? '');
    $lastName = trim($input['last_name'] ?? '');
    $birthday = $input['birthday'] ?? '';
    $addressDetails = trim($input['address_details'] ?? '');
    $gender = $input['gender'] ?? '';
    $contactNumber = trim($input['contact_number'] ?? '');
    $role = $input['role'] ?? '';
    $latitude = $input['latitude'] ?? null;
    $longitude = $input['longitude'] ?? null;
    $profileImageBase64 = $input['profile_image_base64'] ?? null;

    // Validate required fields
    if (!$firstName || !$lastName || !$birthday || !$addressDetails || !$gender || !$contactNumber || !$role) {
        throw new Exception('Missing required fields for registration completion');
    }

    if (!isset($socialUserData['id']) || !isset($socialUserData['email'])) {
        throw new Exception('Invalid social user data');
    }

    // Check if user exists and get their current role
    $stmt = $conn->prepare("SELECT id, role FROM users WHERE email = ?");
    $stmt->bind_param("s", $socialUserData['email']);
    $stmt->execute();
    $result = $stmt->get_result();
    $existingUser = $result->fetch_assoc();
    $stmt->close();

    if (!$existingUser) {
        throw new Exception('Social user not found. Please sign in again.');
    }

    $userId = $existingUser['id'];
    $currentRole = $existingUser['role'];

    // If user already has a valid role (lister/doer), keep it
    // Otherwise, set to 'user' to trigger role selection screen
    if (!empty($currentRole) && in_array($currentRole, ['lister', 'doer'])) {
        $finalRole = $currentRole; // Keep existing role - user goes to dashboard
        error_log("User already has role: $currentRole, keeping it - will go to dashboard");
    } else {
        $finalRole = 'user'; // Set to 'user' to trigger role selection screen
        error_log("User has no valid role, setting to 'user' - will go to role selection");
    }

    // Create full name
    $fullName = trim($firstName . ' ' . ($middleName ? $middleName . ' ' : '') . $lastName);

    // Handle profile image upload if provided
    $profilePictureUrl = $socialUserData['profile_picture_url'] ?? null;
    if ($profileImageBase64) {
        try {
            // Decode base64 image
            $imageData = base64_decode($profileImageBase64);
            if ($imageData === false) {
                throw new Exception('Invalid base64 image data');
            }

            // Create uploads directory if it doesn't exist
            $uploadDir = '../uploads/profile_pictures/';
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0755, true);
            }

            // Generate unique filename
            $userId = $socialUserData['id'];
            $timestamp = time();
            $filename = "profile_{$userId}_{$timestamp}.jpg";
            $filepath = $uploadDir . $filename;

            // Save image file
            if (file_put_contents($filepath, $imageData) !== false) {
                $profilePictureUrl = "uploads/profile_pictures/" . $filename;
            }
        } catch (Exception $e) {
            error_log("Profile image upload error: " . $e->getMessage());
            // Continue without profile image if upload fails
        }
    }

    // User ID already obtained above

    // Update user with complete information
    $updateStmt = $conn->prepare("
        UPDATE users SET 
            full_name = ?,
            first_name = ?,
            middle_name = ?,
            last_name = ?,
            birthday = ?,
            address_details = ?,
            gender = ?,
            contact_number = ?,
            role = ?,
            latitude = ?,
            longitude = ?,
            profile_picture_url = ?,
            is_verified = 1,
            updated_at = NOW()
        WHERE id = ?
    ");

    $updateStmt->bind_param(
        "sssssssssddsi",
        $fullName,
        $firstName,
        $middleName,
        $lastName,
        $birthday,
        $addressDetails,
        $gender,
        $contactNumber,
        $finalRole,
        $latitude,
        $longitude,
        $profilePictureUrl,
        $userId
    );

    if (!$updateStmt->execute()) {
        throw new Exception('Failed to update user information: ' . $updateStmt->error);
    }
    $updateStmt->close();

    // Fetch updated user data
    $stmt = $conn->prepare("
        SELECT 
            id, full_name, first_name, middle_name, last_name, email, role, is_verified, 
            profile_picture_url, address_details, contact_number, latitude, longitude, 
            is_available, birthday, gender, verification_status, badge_status, 
            id_verified, badge_acquired, created_at, updated_at
        FROM users 
        WHERE id = ?
    ");
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $updatedUser = $result->fetch_assoc();
    $stmt->close();

    if (!$updatedUser) {
        throw new Exception('Failed to fetch updated user data');
    }

    // Generate session token
    $token = bin2hex(random_bytes(32));

    // Log the completion
    error_log("Social registration completed for user ID: $userId, email: {$socialUserData['email']}, final role: $finalRole");

    // Return success response with complete user data
    sendJsonResponse([
        'success' => true,
        'message' => 'Social registration completed successfully',
        'user' => [
            'id' => (int)$updatedUser['id'],
            'full_name' => (string)$updatedUser['full_name'],
            'first_name' => (string)$updatedUser['first_name'],
            'middle_name' => (string)$updatedUser['middle_name'],
            'last_name' => (string)$updatedUser['last_name'],
            'email' => (string)$updatedUser['email'],
            'role' => (string)$updatedUser['role'],
            'is_verified' => (bool)$updatedUser['is_verified'],
            'profile_picture_url' => $updatedUser['profile_picture_url'] ? (string)$updatedUser['profile_picture_url'] : null,
            'address_details' => (string)$updatedUser['address_details'],
            'contact_number' => (string)$updatedUser['contact_number'],
            'latitude' => $updatedUser['latitude'] ? (float)$updatedUser['latitude'] : null,
            'longitude' => $updatedUser['longitude'] ? (float)$updatedUser['longitude'] : null,
            'is_available' => (bool)$updatedUser['is_available'],
            'birthday' => (string)$updatedUser['birthday'],
            'gender' => (string)$updatedUser['gender'],
            'verification_status' => (string)($updatedUser['verification_status'] ?? 'unverified'),
            'badge_status' => (string)($updatedUser['badge_status'] ?? 'none'),
            'id_verified' => (bool)($updatedUser['id_verified'] ?? false),
            'badge_acquired' => (bool)($updatedUser['badge_acquired'] ?? false),
            'created_at' => $updatedUser['created_at'],
            'updated_at' => $updatedUser['updated_at'],
            'average_rating' => 0.0,
            'total_reviews' => 0,
        ],
        'token' => $token
    ]);

} catch (Exception $e) {
    error_log("complete_social_registration.php error: " . $e->getMessage());
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
?>
