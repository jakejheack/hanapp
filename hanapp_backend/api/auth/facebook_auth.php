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
    sendJsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
}

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

if (json_last_error() !== JSON_ERROR_NONE) {
    sendJsonResponse(['success' => false, 'message' => 'Invalid JSON input'], 400);
}

// Validate required fields
if (!isset($input['access_token']) || empty($input['access_token'])) {
    sendJsonResponse(['success' => false, 'message' => 'Access token is required'], 400);
}

$accessToken = $input['access_token'];
$deviceInfo = $input['device_info'] ?? null;
$locationDetails = $input['location_details'] ?? null;

// Facebook access token verification (using hanapp Facebook app)
$facebookAppId = '1286019079565975'; // HanApp Facebook App ID
$facebookAppSecret = 'ee49b6837cdb23462bbe027a6e3d007e'; // HanApp Facebook Client Token (Note: This might need to be the actual App Secret from Facebook Developer Console)

// Get user info from Facebook
$graphUrl = "https://graph.facebook.com/me?fields=id,name,email,first_name,last_name,picture&access_token=" . urlencode($accessToken);
error_log("Facebook Graph API URL: " . $graphUrl);

$response = file_get_contents($graphUrl);
error_log("Facebook Graph API Response: " . $response);

$userData = json_decode($response, true);

if (!isset($userData['id']) || !isset($userData['email'])) {
    error_log("Facebook token validation failed. User data: " . json_encode($userData));
    sendJsonResponse(['success' => false, 'message' => 'Invalid Facebook access token or missing email permission'], 401);
}

$facebookUserId = $userData['id'];
$email = $userData['email'];
$fullName = $userData['name'] ?? '';
$firstName = $userData['first_name'] ?? '';
$lastName = $userData['last_name'] ?? '';
$profilePicture = $userData['picture']['data']['url'] ?? '';

// Database connection
require_once '../../config/db_connect.php';

try {
    // Check if user exists
    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ?");
    $stmt->execute([$email]);
    $existingUser = $stmt->fetch();

    if ($existingUser) {
        // User exists - update profile if needed
        $updateFields = [];
        $updateValues = [];

        if (!empty($fullName) && $existingUser['full_name'] !== $fullName) {
            $updateFields[] = "full_name = ?";
            $updateValues[] = $fullName;
        }

        if (!empty($firstName) && $existingUser['first_name'] !== $firstName) {
            $updateFields[] = "first_name = ?";
            $updateValues[] = $firstName;
        }

        if (!empty($lastName) && $existingUser['last_name'] !== $lastName) {
            $updateFields[] = "last_name = ?";
            $updateValues[] = $lastName;
        }

        if (!empty($profilePicture) && $existingUser['profile_picture_url'] !== $profilePicture) {
            $updateFields[] = "profile_picture_url = ?";
            $updateValues[] = $profilePicture;
        }

        if (!empty($updateFields)) {
            $updateValues[] = $existingUser['id'];
            $stmt = $pdo->prepare("UPDATE users SET " . implode(', ', $updateFields) . " WHERE id = ?");
            $stmt->execute($updateValues);

            // Fetch updated user data
            $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
            $stmt->execute([$existingUser['id']]);
            $existingUser = $stmt->fetch();
        }

        // Generate JWT token
        $token = bin2hex(random_bytes(32));

        // Log login history
        $stmt = $pdo->prepare("INSERT INTO login_history (user_id, login_time, device_info, location_details) VALUES (?, NOW(), ?, ?)");
        $stmt->execute([$existingUser['id'], $deviceInfo, $locationDetails]);

        sendJsonResponse([
            'success' => true,
            'message' => 'Login successful',
            'user' => [
                'id' => $existingUser['id'],
                'email' => $existingUser['email'],
                'full_name' => $existingUser['full_name'],
                'first_name' => $existingUser['first_name'],
                'last_name' => $existingUser['last_name'],
                'role' => $existingUser['role'],
                'profile_picture_url' => $existingUser['profile_picture_url'],
                'address_details' => $existingUser['address_details'],
                'contact_number' => $existingUser['contact_number'],
                'latitude' => $existingUser['latitude'],
                'longitude' => $existingUser['longitude'],
                'is_verified' => (bool)$existingUser['is_verified'],
                'is_available' => (bool)$existingUser['is_available'],
                'average_rating' => (float)($existingUser['average_rating'] ?? 0),
                'total_reviews' => (int)($existingUser['review_count'] ?? 0),
                'verification_status' => (string)($existingUser['verification_status'] ?? 'unverified'),
                'badge_status' => (string)($existingUser['badge_status'] ?? 'none'),
                'id_verified' => (bool)($existingUser['id_verified'] ?? false),
                'badge_acquired' => (bool)($existingUser['badge_acquired'] ?? false),
                'id_photo_front_url' => $existingUser['id_photo_front_url'],
                'id_photo_back_url' => $existingUser['id_photo_back_url'],
                'brgy_clearance_photo_url' => $existingUser['brgy_clearance_photo_url'],
                'live_photo_url' => $existingUser['live_photo_url'],
                'created_at' => $existingUser['created_at'],
                'updated_at' => $existingUser['updated_at'],
                'token' => $token
            ]
        ]);

    } else {
        // User doesn't exist - create new user with minimal fields (will be detected as incomplete by app logic)
        $stmt = $pdo->prepare("
            INSERT INTO users (
                email, full_name, profile_picture_url, facebook_id,
                auth_provider, login_method, is_verified,
                verification_status, badge_status, id_verified, badge_acquired,
                created_at, birthday, latitude, longitude
            ) VALUES (?, ?, ?, ?, 'facebook', 'facebook', 1, 'unverified', 'none', 0, 0, NOW(), '1990-01-01', 37.4219983, -122.084)
        ");
        $stmt->execute([$email, $fullName, $profilePicture, $facebookUserId]);

        $newUserId = $pdo->lastInsertId();

        // Link social login
        $stmt = $pdo->prepare("INSERT INTO social_logins (user_id, provider, social_id, created_at) VALUES (?, 'facebook', ?, NOW())");
        $stmt->execute([$newUserId, $facebookUserId]);

        // Generate JWT token
        $token = bin2hex(random_bytes(32));

        // Log login history
        $stmt = $pdo->prepare("INSERT INTO login_history (user_id, login_time, device_info, location_details) VALUES (?, NOW(), ?, ?)");
        $stmt->execute([$newUserId, $deviceInfo, $locationDetails]);

        // Fetch the newly created user to get all fields
        $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
        $stmt->execute([$newUserId]);
        $newUser = $stmt->fetch(PDO::FETCH_ASSOC);

        sendJsonResponse([
            'success' => true,
            'message' => 'Account created and login successful',
            'user' => [
                'id' => $newUser['id'],
                'email' => $newUser['email'],
                'full_name' => $newUser['full_name'],
                'first_name' => $newUser['first_name'],
                'last_name' => $newUser['last_name'],
                'role' => $newUser['role'],
                'profile_picture_url' => $newUser['profile_picture_url'],
                'address_details' => $newUser['address_details'],
                'contact_number' => $newUser['contact_number'],
                'latitude' => $newUser['latitude'],
                'longitude' => $newUser['longitude'],
                'is_verified' => (bool)$newUser['is_verified'],
                'is_available' => (bool)$newUser['is_available'],
                'average_rating' => (float)($newUser['average_rating'] ?? 0),
                'total_reviews' => (int)($newUser['review_count'] ?? 0),
                'verification_status' => (string)($newUser['verification_status'] ?? 'unverified'),
                'badge_status' => (string)($newUser['badge_status'] ?? 'none'),
                'id_verified' => (bool)($newUser['id_verified'] ?? false),
                'badge_acquired' => (bool)($newUser['badge_acquired'] ?? false),
                'id_photo_front_url' => $newUser['id_photo_front_url'],
                'id_photo_back_url' => $newUser['id_photo_back_url'],
                'brgy_clearance_photo_url' => $newUser['brgy_clearance_photo_url'],
                'live_photo_url' => $newUser['live_photo_url'],
                'created_at' => $newUser['created_at'],
                'updated_at' => $newUser['updated_at'],
                'token' => $token
            ]
        ]);
    }

} catch (PDOException $e) {
    sendJsonResponse(['success' => false, 'message' => 'Database error: ' . $e->getMessage()], 500);
} catch (Exception $e) {
    sendJsonResponse(['success' => false, 'message' => 'General error: ' . $e->getMessage()], 500);
}
?> 