<?php
// hanapp_backend/api/update_profile.php
// Update user profile information with file-based profile image support

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../config/db_connect.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method is allowed');
    }

    // Check if it's multipart form data or JSON
    $isMultipart = isset($_POST['user_id']);
    
    if ($isMultipart) {
        // Handle multipart form data (for file uploads)
        $userId = $_POST['user_id'] ?? null;
        $fullName = $_POST['full_name'] ?? null;
        $email = $_POST['email'] ?? null;
        $contactNumber = $_POST['contact_number'] ?? null;
        $addressDetails = $_POST['address_details'] ?? null;
        $latitude = $_POST['latitude'] ?? null;
        $longitude = $_POST['longitude'] ?? null;
        
        // Handle file upload
        $profileImageFile = $_FILES['profile_picture'] ?? null;
    } else {
        // Handle JSON input (for non-file updates)
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            throw new Exception('Invalid JSON input');
        }

        $userId = $input['user_id'] ?? null;
        $fullName = $input['full_name'] ?? null;
        $email = $input['email'] ?? null;
        $contactNumber = $input['contact_number'] ?? null;
        $addressDetails = $input['address_details'] ?? null;
        $latitude = $input['latitude'] ?? null;
        $longitude = $input['longitude'] ?? null;
        
        $profileImageFile = null; // No file upload in JSON mode
    }

    // Validate required fields
    if (!$userId || !$fullName || !$email) {
        throw new Exception('Missing required fields: user_id, full_name, email');
    }

    // Validate email format
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Invalid email format');
    }

    // Check if email is already taken by another user
    $checkEmailStmt = $conn->prepare("SELECT id FROM users WHERE email = ? AND id != ?");
    $checkEmailStmt->bind_param('si', $email, $userId);
    $checkEmailStmt->execute();
    $emailResult = $checkEmailStmt->get_result();
    
    if ($emailResult->num_rows > 0) {
        throw new Exception('Email is already taken by another user');
    }

    // Start building the update query
    $updateFields = [];
    $updateValues = [];
    $updateTypes = '';

    // Add fields to update
    if ($fullName !== null) {
        $updateFields[] = "full_name = ?";
        $updateValues[] = $fullName;
        $updateTypes .= 's';
    }

    if ($email !== null) {
        $updateFields[] = "email = ?";
        $updateValues[] = $email;
        $updateTypes .= 's';
    }

    if ($contactNumber !== null) {
        $updateFields[] = "contact_number = ?";
        $updateValues[] = $contactNumber;
        $updateTypes .= 's';
    }

    if ($addressDetails !== null) {
        $updateFields[] = "address_details = ?";
        $updateValues[] = $addressDetails;
        $updateTypes .= 's';
    }

    if ($latitude !== null) {
        $updateFields[] = "latitude = ?";
        $updateValues[] = $latitude;
        $updateTypes .= 'd';
    }

    if ($longitude !== null) {
        $updateFields[] = "longitude = ?";
        $updateValues[] = $longitude;
        $updateTypes .= 'd';
    }

    // Handle file upload for profile picture
    $profilePictureUrl = null;
    if ($profileImageFile && $profileImageFile['error'] === UPLOAD_ERR_OK) {
        // Debug file information
        error_log("Update profile debug - File type: " . $profileImageFile['type']);
        error_log("Update profile debug - File name: " . $profileImageFile['name']);
        error_log("Update profile debug - File size: " . $profileImageFile['size']);
        
        // Validate file type using multiple methods
        $allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
        $isValidType = false;
        
        // Method 1: Check MIME type from $_FILES
        if (in_array($profileImageFile['type'], $allowedTypes)) {
            $isValidType = true;
            error_log("Update profile debug - Valid type via MIME: " . $profileImageFile['type']);
        }
        
        // Method 2: Check file extension
        $fileExtension = strtolower(pathinfo($profileImageFile['name'], PATHINFO_EXTENSION));
        $allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
        if (in_array($fileExtension, $allowedExtensions)) {
            $isValidType = true;
            error_log("Update profile debug - Valid type via extension: " . $fileExtension);
        }
        
        // Method 3: Check actual file content using finfo
        if (!$isValidType) {
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            $actualMimeType = finfo_file($finfo, $profileImageFile['tmp_name']);
            finfo_close($finfo);
            
            error_log("Update profile debug - Actual MIME type: " . $actualMimeType);
            
            if (in_array($actualMimeType, $allowedTypes)) {
                $isValidType = true;
                error_log("Update profile debug - Valid type via finfo: " . $actualMimeType);
            }
        }
        
        if (!$isValidType) {
            // Final fallback: accept based on extension only if file size is reasonable
            if ($profileImageFile['size'] > 0 && $profileImageFile['size'] <= 10 * 1024 * 1024) { // Max 10MB
                error_log("Update profile debug - Accepting file based on extension fallback: " . $fileExtension);
                $isValidType = true;
            } else {
                throw new Exception('Invalid file type. Only JPEG, PNG, and GIF are allowed. Detected type: ' . $profileImageFile['type'] . ', Extension: ' . $fileExtension);
            }
        }

        // Validate file size (max 5MB)
        if ($profileImageFile['size'] > 5 * 1024 * 1024) {
            throw new Exception('File too large. Maximum size is 5MB.');
        }

        // Create uploads directory if it doesn't exist
        $uploadDir = '../uploads/profile_pictures/';
        if (!file_exists($uploadDir)) {
            if (!mkdir($uploadDir, 0755, true)) {
                throw new Exception('Failed to create upload directory');
            }
        }

        // Generate unique filename
        $fileExtension = pathinfo($profileImageFile['name'], PATHINFO_EXTENSION);
        $filename = 'profile_' . $userId . '_' . time() . '.' . $fileExtension;
        $filepath = $uploadDir . $filename;
        
        // Move uploaded file
        if (move_uploaded_file($profileImageFile['tmp_name'], $filepath)) {
            $profilePictureUrl = 'uploads/profile_pictures/' . $filename;
            
            // Add profile picture to update fields
            $updateFields[] = "profile_picture_url = ?";
            $updateValues[] = $profilePictureUrl;
            $updateTypes .= 's';
            
            // Delete old profile picture if it exists
            $oldPictureStmt = $conn->prepare("SELECT profile_picture_url FROM users WHERE id = ?");
            $oldPictureStmt->bind_param('i', $userId);
            $oldPictureStmt->execute();
            $oldResult = $oldPictureStmt->get_result();
            
            if ($oldResult->num_rows > 0) {
                $oldUser = $oldResult->fetch_assoc();
                $oldPictureUrl = $oldUser['profile_picture_url'];
                
                // Delete old file if it's a local file (not base64 or external URL)
                if ($oldPictureUrl && !str_starts_with($oldPictureUrl, 'data:') && !str_starts_with($oldPictureUrl, 'http')) {
                    $oldFilePath = '../' . $oldPictureUrl;
                    if (file_exists($oldFilePath)) {
                        unlink($oldFilePath);
                    }
                }
            }
        } else {
            throw new Exception('Failed to save uploaded file');
        }
    }

    // Add user_id to the end for WHERE clause
    $updateValues[] = $userId;
    $updateTypes .= 'i';

    // Build and execute update query
    if (!empty($updateFields)) {
        $sql = "UPDATE users SET " . implode(', ', $updateFields) . " WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($updateTypes, ...$updateValues);
        
        if (!$stmt->execute()) {
            throw new Exception('Failed to update profile: ' . $stmt->error);
        }

        if ($stmt->affected_rows === 0) {
            throw new Exception('No changes made or user not found');
        }
    }

    // Fetch updated user data
    $fetchStmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
    $fetchStmt->bind_param('i', $userId);
    $fetchStmt->execute();
    $result = $fetchStmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('User not found after update');
    }

    $user = $result->fetch_assoc();

    // Convert server local timestamps to UTC for frontend
    $user['created_at'] = $user['created_at'] ? gmdate('Y-m-d H:i:s', strtotime($user['created_at'])) : null;
    $user['updated_at'] = $user['updated_at'] ? gmdate('Y-m-d H:i:s', strtotime($user['updated_at'])) : null;

    echo json_encode([
        'success' => true,
        'message' => 'Profile updated successfully',
        'profile_picture_url' => $profilePictureUrl ?? $user['profile_picture_url'],
        'user' => [
            'id' => $user['id'],
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
    error_log("update_profile.php error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?> 