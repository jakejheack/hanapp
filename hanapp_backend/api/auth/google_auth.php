<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0);

// Start output buffering
ob_start();

// Set headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

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
if (!isset($input['id_token']) || empty($input['id_token'])) {
    sendJsonResponse(['success' => false, 'message' => 'ID token is required'], 400);
}

$idToken = $input['id_token'];
$accessToken = $input['access_token'] ?? '';
$clientWebId = $input['client_web_id'] ?? '28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com';
$deviceInfo = $input['device_info'] ?? null;
$locationDetails = $input['location_details'] ?? null;

// Google ID token verification
$googleClientId = '28340114852-ckvau2c2fpdhllml5v43rf07eofffssb.apps.googleusercontent.com';
$tokenInfoUrl = "https://oauth2.googleapis.com/tokeninfo?id_token=" . urlencode($idToken);
$tokenInfo = json_decode(file_get_contents($tokenInfoUrl), true);

if (
    !$tokenInfo ||
    !isset($tokenInfo['sub']) ||
    !isset($tokenInfo['email']) ||
    $tokenInfo['aud'] !== $googleClientId
) {
    sendJsonResponse(['success' => false, 'message' => 'Invalid Google ID token'], 401);
}

$email = $tokenInfo['email'];
$googleUserId = $tokenInfo['sub'];
$fullName = $tokenInfo['name'] ?? '';
$firstName = $tokenInfo['given_name'] ?? '';
$lastName = $tokenInfo['family_name'] ?? '';
$profilePicture = $tokenInfo['picture'] ?? '';

// Database connection
require_once '../../config/db_connect.php';

// Firebase project configuration
// TODO: Replace 'your-firebase-project-id' with your actual Firebase project ID from Firebase Console
// Go to Firebase Console → Project Settings → General → Project ID
$firebase_project_id = 'hanapp-15bf7-38147';
$firebase_public_keys_url = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

function verifyFirebaseToken($idToken) {
    global $firebase_public_keys_url;
    
    // Get Firebase public keys
    $keys_response = file_get_contents($firebase_public_keys_url);
    if (!$keys_response) {
        return null;
    }
    
    $keys = json_decode($keys_response, true);
    
    // Decode the JWT token header
    $token_parts = explode('.', $idToken);
    if (count($token_parts) !== 3) {
        return null;
    }
    
    $header = json_decode(base64_decode(strtr($token_parts[0], '-_', '+/')), true);
    $payload = json_decode(base64_decode(strtr($token_parts[1], '-_', '+/')), true);
    
    if (!$header || !$payload) {
        return null;
    }
    
    // Verify the token was issued by Firebase
    if ($payload['iss'] !== 'https://securetoken.google.com/' . $GLOBALS['firebase_project_id']) {
        return null;
    }
    
    // Verify the audience
    if ($payload['aud'] !== $GLOBALS['firebase_project_id']) {
        return null;
    }
    
    // Check if token is expired
    if ($payload['exp'] < time()) {
        return null;
    }
    
    return $payload;
}

try {
    // Verify the Firebase token
    $firebaseUser = verifyFirebaseToken($idToken);
    
    if (!$firebaseUser) {
        throw new Exception('Invalid Firebase token');
    }
    
    // Use Firebase UID as the unique identifier
    $firebaseUid = $firebaseUser['user_id'];
    $email = $firebaseUser['email'] ?? $email;
    
    // Check if user exists in database
    $stmt = $pdo->prepare("SELECT * FROM users WHERE firebase_uid = ? OR email = ?");
    $stmt->execute([$firebaseUid, $email]);
    $existingUser = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($existingUser) {
        // Update existing user with Firebase UID if not set
        if (!$existingUser['firebase_uid']) {
            $updateStmt = $pdo->prepare("UPDATE users SET firebase_uid = ?, full_name = ?, profile_picture_url = ?, login_method = 'google', updated_at = NOW() WHERE id = ?");
            $updateStmt->execute([$firebaseUid, $fullName, $profilePicture, $existingUser['id']]);
        }
        
        $user = $existingUser;
    } else {
        // Create new user with minimal fields (will be detected as incomplete by app logic)
        $insertStmt = $pdo->prepare("
            INSERT INTO users (
                firebase_uid, email, full_name, profile_picture_url,
                login_method, auth_provider, is_verified,
                verification_status, badge_status, id_verified, badge_acquired,
                created_at, updated_at, birthday, latitude, longitude
            )
            VALUES (?, ?, ?, ?, 'google', 'google', 1, 'unverified', 'none', 0, 0, NOW(), NOW(), '1990-01-01', 37.4219983, -122.084)
        ");
        $insertStmt->execute([$firebaseUid, $email, $fullName, $profilePicture]);
        
        $userId = $pdo->lastInsertId();
        
        // Fetch the newly created user
        $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    // Generate a session token for your app
    $sessionToken = bin2hex(random_bytes(32));
    
    // Store session token
    $tokenStmt = $pdo->prepare("INSERT INTO user_sessions (user_id, token, created_at, expires_at) VALUES (?, ?, NOW(), DATE_ADD(NOW(), INTERVAL 30 DAY))");
    $tokenStmt->execute([$user['id'], $sessionToken]);
    
    // Return user data (same format as email/password registration)
    echo json_encode([
        'success' => true,
        'message' => 'Google authentication successful',
        'user' => [
            'id' => $user['id'],
            'firebase_uid' => $firebaseUid,
            'email' => $user['email'],
            'full_name' => $user['full_name'],
            'first_name' => $user['first_name'],
            'last_name' => $user['last_name'],
            'role' => $user['role'] ?? 'user',
            'profile_picture_url' => $user['profile_picture_url'],
            'address_details' => $user['address_details'],
            'contact_number' => $user['contact_number'],
            'latitude' => $user['latitude'],
            'longitude' => $user['longitude'],
            'is_verified' => (bool)$user['is_verified'],
            'is_available' => (bool)$user['is_available'],
            'average_rating' => (float)($user['average_rating'] ?? 0),
            'total_reviews' => (int)($user['review_count'] ?? 0),
            'verification_status' => (string)($user['verification_status'] ?? 'unverified'),
            'badge_status' => (string)($user['badge_status'] ?? 'none'),
            'id_verified' => (bool)($user['id_verified'] ?? false),
            'badge_acquired' => (bool)($user['badge_acquired'] ?? false),
            'id_photo_front_url' => $user['id_photo_front_url'],
            'id_photo_back_url' => $user['id_photo_back_url'],
            'brgy_clearance_photo_url' => $user['brgy_clearance_photo_url'],
            'live_photo_url' => $user['live_photo_url'],
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at'],
            'token' => $sessionToken
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?> 