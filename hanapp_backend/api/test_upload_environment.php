<?php
// hanapp_backend/api/test_upload_environment.php
// Test endpoint to check server environment and file permissions

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $testDir = '../../uploads/test/';
    $testFile = $testDir . 'test_' . time() . '.txt';
    
    $info = [
        'script_directory' => __DIR__,
        'current_working_directory' => getcwd(),
        'php_user' => get_current_user(),
        'php_process_user' => function_exists('posix_getpwuid') ? posix_getpwuid(posix_geteuid())['name'] : 'Not available',
        'upload_max_filesize' => ini_get('upload_max_filesize'),
        'post_max_size' => ini_get('post_max_size'),
        'max_file_uploads' => ini_get('max_file_uploads'),
        'file_uploads_enabled' => ini_get('file_uploads'),
        'temp_dir' => ini_get('upload_tmp_dir') ?: sys_get_temp_dir(),
        'test_directory_path' => realpath(__DIR__ . '/' . $testDir),
        'test_directory_exists' => file_exists($testDir),
        'test_directory_writable' => is_writable($testDir),
        'parent_directory_writable' => is_writable(dirname($testDir)),
    ];
    
    // Try to create test directory
    if (!file_exists($testDir)) {
        $info['create_directory_attempt'] = 'Creating directory: ' . $testDir;
        if (mkdir($testDir, 0755, true)) {
            $info['create_directory_success'] = true;
            $info['test_directory_exists_after_create'] = file_exists($testDir);
            $info['test_directory_writable_after_create'] = is_writable($testDir);
        } else {
            $info['create_directory_success'] = false;
            $info['create_directory_error'] = error_get_last();
        }
    }
    
    // Try to create a test file
    if (file_exists($testDir) && is_writable($testDir)) {
        $info['create_file_attempt'] = 'Creating file: ' . $testFile;
        if (file_put_contents($testFile, 'Test file created at ' . date('Y-m-d H:i:s'))) {
            $info['create_file_success'] = true;
            $info['test_file_exists'] = file_exists($testFile);
            $info['test_file_size'] = filesize($testFile);
            
            // Clean up test file
            unlink($testFile);
            $info['test_file_cleaned_up'] = true;
        } else {
            $info['create_file_success'] = false;
            $info['create_file_error'] = error_get_last();
        }
    }
    
    // Check if uploads directory exists and is writable
    $uploadsDir = '../../uploads/';
    $profilePicturesDir = '../../uploads/profile_pictures/';
    
    $info['uploads_directory_exists'] = file_exists($uploadsDir);
    $info['uploads_directory_writable'] = is_writable($uploadsDir);
    $info['profile_pictures_directory_exists'] = file_exists($profilePicturesDir);
    $info['profile_pictures_directory_writable'] = is_writable($profilePicturesDir);
    
    // List contents of parent directory
    $parentDir = dirname($uploadsDir);
    if (file_exists($parentDir)) {
        $info['parent_directory_contents'] = scandir($parentDir);
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Environment test completed',
        'info' => $info
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Test failed: ' . $e->getMessage()
    ]);
}
?> 