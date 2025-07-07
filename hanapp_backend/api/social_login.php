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

// Validate required fields
if (!isset($input['email']) || empty($input['email']) || 
    !isset($input['social_provider']) || empty($input['social_provider']) ||
    !isset($input['social_id']) || empty($input['social_id'])) {
    sendJsonResponse(['error' => 'Email, social_provider, and social_id are required'], 400);
}

$email = filter_var($input['email'], FILTER_SANITIZE_EMAIL);
$socialProvider = filter_var($input['social_provider'], FILTER_UNSAFE_RAW);
$socialId = filter_var($input['social_id'], FILTER_UNSAFE_RAW);
$fullName = filter_var($input['full_name'] ?? '', FILTER_UNSAFE_RAW);
$firstName = filter_var($input['first_name'] ?? '', FILTER_UNSAFE_RAW);
$lastName = filter_var($input['last_name'] ?? '', FILTER_UNSAFE_RAW);
$profilePicture = filter_var($input['profile_picture'] ?? '', FILTER_SANITIZE_URL);
$deviceInfo = $input['device_info'] ?? null; // Get device info from Flutter app

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    sendJsonResponse(['error' => 'Invalid email format'], 400);
}

if (!in_array($socialProvider, ['google', 'facebook'])) {
    sendJsonResponse(['error' => 'Invalid social provider'], 400);
}

// --- SOCIAL TOKEN VERIFICATION ---
if ($socialProvider === 'google') {
    // Google ID token verification using HTTP request (no Composer needed)
    $idToken = $input['id_token'] ?? '';
    $googleClientId = '723085540061-v5iheljkimtttiiadt3fqi5uc55qdpv6.apps.googleusercontent.com';
    $tokenInfoUrl = "https://oauth2.googleapis.com/tokeninfo?id_token=" . urlencode($idToken);
    $tokenInfo = json_decode(file_get_contents($tokenInfoUrl), true);

    if (
        !$tokenInfo ||
        !isset($tokenInfo['sub']) ||
        $tokenInfo['sub'] !== $socialId ||
        strtolower($tokenInfo['email']) !== strtolower($email) ||
        $tokenInfo['aud'] !== $googleClientId
    ) {
        sendJsonResponse(['error' => 'Invalid Google ID token'], 401);
    }
    // Optionally, you can use $tokenInfo['name'], $tokenInfo['picture'], etc.
}

if ($socialProvider === 'facebook') {
    // Facebook access token verification
    $accessToken = $input['access_token'] ?? '';
    $facebookAppId = '1286019079565975'; // Facebook App ID
    $facebookAppSecret = 'ee49b6837cdb23462bbe027a6e3d007e'; // Facebook App Secret
    $debugUrl = "https://graph.facebook.com/debug_token?input_token=$accessToken&access_token=$facebookAppId|$facebookAppSecret";
    $response = file_get_contents($debugUrl);
    $data = json_decode($response, true);
    if (!($data['data']['is_valid'] ?? false) || ($data['data']['user_id'] ?? '') !== $socialId) {
        sendJsonResponse(['error' => 'Invalid Facebook access token'], 401);
    }
}
// --- END SOCIAL TOKEN VERIFICATION ---

// Database connection
try {
    require_once 'db_connect.php';
    require_once 'log_login_history.php'; // Include the login history logging function
    
    // Convert mysqli connection to PDO for this file
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    sendJsonResponse(['error' => 'Database connection failed: ' . $e->getMessage()], 500);
}

try {
    // Check if user exists by email
    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = ?");
    $stmt->execute([$email]);
    $existingUser = $stmt->fetch();
    
    if ($existingUser) {
        // User exists - check if they have social login linked
        $stmt = $pdo->prepare("SELECT * FROM social_logins WHERE user_id = ? AND provider = ?");
        $stmt->execute([$existingUser['id'], $socialProvider]);
        $socialLogin = $stmt->fetch();
        
        if ($socialLogin) {
            // Social login already linked - update social ID if needed
            if ($socialLogin['social_id'] !== $socialId) {
                $stmt = $pdo->prepare("UPDATE social_logins SET social_id = ?, updated_at = NOW() WHERE id = ?");
                $stmt->execute([$socialId, $socialLogin['id']]);
            }
        } else {
            // Link social login to existing user
            $stmt = $pdo->prepare("INSERT INTO social_logins (user_id, provider, social_id, created_at) VALUES (?, ?, ?, NOW())");
            $stmt->execute([$existingUser['id'], $socialProvider, $socialId]);
        }
        
        // Update user profile if new data provided
        $updateFields = [];
        $updateValues = [];
        
        if (!empty($fullName) && $existingUser['full_name'] !== $fullName) {
            $updateFields[] = "full_name = ?";
            $updateValues[] = $fullName;
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
        
        // Generate JWT token (you can use your existing token generation method)
        $token = bin2hex(random_bytes(32)); // Simple token for now
        
        // --- LOGIN HISTORY LOGGING ---
        logLoginHistoryPDO($pdo, $existingUser['id'], null, $deviceInfo, null); // Pass device info from Flutter
        // --- END LOGIN HISTORY LOGGING ---
        
        sendJsonResponse([
            'success' => true,
            'message' => 'Login successful',
            'user' => [
                'id' => $existingUser['id'],
                'email' => (string)($existingUser['email'] ?? ''),
                'full_name' => (string)($existingUser['full_name'] ?? ''),
                'role' => (string)($existingUser['role'] ?? 'user'),
                'profile_picture_url' => $existingUser['profile_picture_url'] ? (string)$existingUser['profile_picture_url'] : null,
                'address_details' => $existingUser['address_details'] ? (string)$existingUser['address_details'] : null,
                'contact_number' => $existingUser['contact_number'] ? (string)$existingUser['contact_number'] : null,
                'is_available' => (bool)$existingUser['is_available'],
                // Add verification fields for consistency
                'verification_status' => (string)($existingUser['verification_status'] ?? 'unverified'),
                'badge_status' => (string)($existingUser['badge_status'] ?? 'none'),
                'id_verified' => (bool)($existingUser['id_verified'] ?? false),
                'badge_acquired' => (bool)($existingUser['badge_acquired'] ?? false),
            ],
            'token' => $token
        ]);
        
    } else {
        // User doesn't exist - create new user with verification fields
        $stmt = $pdo->prepare("INSERT INTO users (email, full_name, first_name, last_name, profile_picture_url, role, verification_status, badge_status, id_verified, badge_acquired, created_at) VALUES (?, ?, ?, ?, ?, 'user', 'unverified', 'none', 0, 0, NOW())");
        $stmt->execute([$email, $fullName, $firstName, $lastName, $profilePicture]);
        
        $newUserId = $pdo->lastInsertId();
        
        // Link social login
        $stmt = $pdo->prepare("INSERT INTO social_logins (user_id, provider, social_id, created_at) VALUES (?, ?, ?, NOW())");
        $stmt->execute([$newUserId, $socialProvider, $socialId]);
        
        // Generate JWT token
        $token = bin2hex(random_bytes(32)); // Simple token for now
        
        // --- LOGIN HISTORY LOGGING ---
        logLoginHistoryPDO($pdo, $newUserId, null, $deviceInfo, null); // Pass device info from Flutter
        // --- END LOGIN HISTORY LOGGING ---
        
        sendJsonResponse([
            'success' => true,
            'message' => 'Account created and login successful',
            'user' => [
                'id' => $newUserId,
                'email' => (string)$email,
                'full_name' => (string)$fullName,
                'role' => 'user',
                'profile_picture_url' => $profilePicture ? (string)$profilePicture : null,
                'address_details' => null,
                'contact_number' => null,
                'is_available' => false,
                // Add verification fields for consistency
                'verification_status' => 'unverified',
                'badge_status' => 'none',
                'id_verified' => false,
                'badge_acquired' => false,
            ],
            'token' => $token
        ]);
    }
    
} catch (PDOException $e) {
    sendJsonResponse(['error' => 'Database error: ' . $e->getMessage()], 500);
} catch (Exception $e) {
    sendJsonResponse(['error' => 'General error: ' . $e->getMessage()], 500);
}
?> 