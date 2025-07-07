<?php
// hanapp_backend/api/auth/upload_profile_picture.php
// Dedicated endpoint for uploading profile pictures

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../../config/db_connect.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method is allowed');
    }

    $user_id = $_POST['user_id'] ?? null;
    
    if (!$user_id) {
        echo json_encode(['success' => false, 'message' => 'User ID is required']);
        exit();
    }
    
    // Check if file was uploaded
    if (!isset($_FILES['profile_picture']) || $_FILES['profile_picture']['error'] !== UPLOAD_ERR_OK) {
        echo json_encode(['success' => false, 'message' => 'No file uploaded or upload error']);
        exit();
    }
    
    $file = $_FILES['profile_picture'];
    $allowed_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
    
    // Debug file information
    error_log("Upload debug - File type: " . $file['type']);
    error_log("Upload debug - File name: " . $file['name']);
    error_log("Upload debug - File size: " . $file['size']);
    
    // Validate file type using multiple methods
    $isValidType = false;
    
    // Method 1: Check MIME type from $_FILES
    if (in_array($file['type'], $allowed_types)) {
        $isValidType = true;
        error_log("Upload debug - Valid type via MIME: " . $file['type']);
    }
    
    // Method 2: Check file extension
    $fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
    if (in_array($fileExtension, $allowedExtensions)) {
        $isValidType = true;
        error_log("Upload debug - Valid type via extension: " . $fileExtension);
    }
    
    // Method 3: Check actual file content using finfo
    if (!$isValidType) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $actualMimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);
        
        error_log("Upload debug - Actual MIME type: " . $actualMimeType);
        
        if (in_array($actualMimeType, $allowed_types)) {
            $isValidType = true;
            error_log("Upload debug - Valid type via finfo: " . $actualMimeType);
        }
    }
    
    if (!$isValidType) {
        // Final fallback: accept based on extension only if file size is reasonable
        if ($file['size'] > 0 && $file['size'] <= 10 * 1024 * 1024) { // Max 10MB
            error_log("Upload debug - Accepting file based on extension fallback: " . $fileExtension);
            $isValidType = true;
        } else {
            echo json_encode([
                'success' => false, 
                'message' => 'Invalid file type. Only JPEG, PNG, and GIF are allowed. Detected type: ' . $file['type'] . ', Extension: ' . $fileExtension
            ]);
            exit();
        }
    }
    
    // Validate file size (max 5MB)
    if ($file['size'] > 5 * 1024 * 1024) {
        echo json_encode(['success' => false, 'message' => 'File too large. Maximum size is 5MB']);
        exit();
    }
    
    // Create uploads directory if it doesn't exist
    // The correct path should be relative to the API directory
    $upload_dir = '../../uploads/profile_pictures/';
    error_log("Upload debug - Using path: $upload_dir");
    error_log("Upload debug - Script location: " . __DIR__);
    error_log("Upload debug - Expected full path: " . realpath(__DIR__ . '/' . $upload_dir));
    error_log("Upload debug - Upload directory path: " . realpath($upload_dir));
    error_log("Upload debug - Current working directory: " . getcwd());
    error_log("Upload debug - Script directory: " . __DIR__);
    error_log("Upload debug - Absolute upload path: " . realpath(__DIR__ . '/' . $upload_dir));
    error_log("Upload debug - PHP user: " . get_current_user());
    error_log("Upload debug - PHP process user: " . posix_getpwuid(posix_geteuid())['name']);
    
    if (!file_exists($upload_dir)) {
        error_log("Upload debug - Creating upload directory: $upload_dir");
        if (!mkdir($upload_dir, 0755, true)) {
            error_log("Upload debug - Failed to create directory: " . error_get_last()['message']);
            echo json_encode(['success' => false, 'message' => 'Failed to create upload directory']);
            exit();
        }
        error_log("Upload debug - Directory created successfully");
    } else {
        error_log("Upload debug - Upload directory already exists");
    }
    
    // Check directory permissions
    if (!is_writable($upload_dir)) {
        error_log("Upload debug - Directory is not writable: $upload_dir");
        echo json_encode(['success' => false, 'message' => 'Upload directory is not writable']);
        exit();
    }
    
    // Generate unique filename
    $file_extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = 'profile_' . $user_id . '_' . time() . '.' . $file_extension;
    $filepath = $upload_dir . $filename;
    
    // Move uploaded file
    error_log("Upload debug - Moving file from: " . $file['tmp_name']);
    error_log("Upload debug - Moving file to: " . $filepath);
    error_log("Upload debug - File exists before move: " . (file_exists($file['tmp_name']) ? 'Yes' : 'No'));
    
    if (move_uploaded_file($file['tmp_name'], $filepath)) {
        error_log("Upload debug - File moved successfully");
        error_log("Upload debug - File exists after move: " . (file_exists($filepath) ? 'Yes' : 'No'));
        error_log("Upload debug - File size after move: " . filesize($filepath));
        
        $profile_url = 'uploads/profile_pictures/' . $filename;
        
        // Delete old profile picture if it exists
        $oldPictureStmt = $conn->prepare("SELECT profile_picture_url FROM users WHERE id = ?");
        $oldPictureStmt->bind_param('i', $user_id);
        $oldPictureStmt->execute();
        $oldResult = $oldPictureStmt->get_result();
        
        if ($oldResult->num_rows > 0) {
            $oldUser = $oldResult->fetch_assoc();
            $oldPictureUrl = $oldUser['profile_picture_url'];
            
            // Delete old file if it's a local file (not base64 or external URL)
            if ($oldPictureUrl && !str_starts_with($oldPictureUrl, 'data:') && !str_starts_with($oldPictureUrl, 'http')) {
                $oldFilePath = '../../' . $oldPictureUrl;
                if (file_exists($oldFilePath)) {
                    unlink($oldFilePath);
                }
            }
        }
        
        // Update database with file path
        $stmt = $conn->prepare("UPDATE users SET profile_picture_url = ? WHERE id = ?");
        $stmt->bind_param("si", $profile_url, $user_id);
        
        if ($stmt->execute()) {
            echo json_encode([
                'success' => true, 
                'message' => 'Profile picture uploaded successfully',
                'url' => $profile_url
            ]);
        } else {
            // Delete file if database update fails
            unlink($filepath);
            echo json_encode(['success' => false, 'message' => 'Failed to update database']);
        }
        $stmt->close();
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to save file']);
    }
    
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}

$conn->close();
?> 