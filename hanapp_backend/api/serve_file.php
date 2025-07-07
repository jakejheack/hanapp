<?php
// hanapp_backend/api/serve_file.php
// Secure file serving endpoint for uploaded files

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        throw new Exception('Only GET method is allowed');
    }

    $filePath = $_GET['path'] ?? null;
    
    if (!$filePath) {
        throw new Exception('File path is required');
    }
    
    // Security: Only allow access to uploads directory
    if (!str_starts_with($filePath, 'uploads/')) {
        throw new Exception('Access denied: Invalid file path');
    }
    
    // Remove any directory traversal attempts
    $filePath = str_replace(['../', '..\\'], '', $filePath);
    
    // Construct full file path
    $fullPath = __DIR__ . '/' . $filePath;
    error_log("Serve file debug - Requested path: " . $filePath);
    error_log("Serve file debug - Script directory: " . __DIR__);
    error_log("Serve file debug - Full path: " . $fullPath);
    error_log("Serve file debug - File exists: " . (file_exists($fullPath) ? 'Yes' : 'No'));
    
    // Check if file exists
    if (!file_exists($fullPath)) {
        throw new Exception('File not found');
    }
    
    // Check if file is within uploads directory
    $realPath = realpath($fullPath);
    $uploadsDir = realpath(__DIR__ . '/uploads');
    
    if (!$realPath || !$uploadsDir || strpos($realPath, $uploadsDir) !== 0) {
        throw new Exception('Access denied: File outside uploads directory');
    }
    
    // Get file info
    $fileInfo = pathinfo($fullPath);
    $extension = strtolower($fileInfo['extension']);
    
    // Set appropriate content type
    $contentTypes = [
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'pdf' => 'application/pdf',
        'txt' => 'text/plain',
    ];
    
    $contentType = $contentTypes[$extension] ?? 'application/octet-stream';
    
    // Set headers for file download/display
    header('Content-Type: ' . $contentType);
    header('Content-Length: ' . filesize($fullPath));
    header('Cache-Control: public, max-age=31536000'); // Cache for 1 year
    header('Expires: ' . gmdate('D, d M Y H:i:s \G\M\T', time() + 31536000));
    
    // Output file content
    readfile($fullPath);
    exit();
    
} catch (Exception $e) {
    http_response_code(404);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?> 