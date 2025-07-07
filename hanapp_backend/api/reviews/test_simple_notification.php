<?php
file_put_contents('/tmp/php_debug.log', 'test_simple_notification.php reached\n', FILE_APPEND);

// Strict error reporting for production
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ERROR | E_PARSE);

require_once '../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function respond($success, $message, $data = null) {
    $response = ['success' => $success, 'message' => $message];
    if ($data !== null) {
        $response['data'] = $data;
    }
    echo json_encode($response);
    exit();
}

try {
    file_put_contents('/tmp/php_debug.log', "Testing database connection...\n", FILE_APPEND);
    
    // Test 1: Check database connection
    if (!$conn || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn ? $conn->connect_error : "No connection"));
    }
    
    file_put_contents('/tmp/php_debug.log', "Database connection successful\n", FILE_APPEND);
    
    // Test 2: Check if users table exists and has data
    $getUsersSql = "SELECT id FROM users LIMIT 2";
    $getUsersResult = $conn->query($getUsersSql);
    
    if (!$getUsersResult) {
        throw new Exception("Failed to query users table: " . $conn->error);
    }
    
    if ($getUsersResult->num_rows < 2) {
        throw new Exception("Need at least 2 users in the database for testing. Found: " . $getUsersResult->num_rows);
    }
    
    $userIds = [];
    while ($row = $getUsersResult->fetch_assoc()) {
        $userIds[] = $row['id'];
    }
    
    $testUserId = $userIds[0];    // First user
    $testSenderId = $userIds[1];  // Second user
    
    file_put_contents('/tmp/php_debug.log', "Found users: " . implode(', ', $userIds) . "\n", FILE_APPEND);
    
    // Test 3: Check if notification tables exist
    $checkNotificationsv2Sql = "SHOW TABLES LIKE 'notificationsv2'";
    $checkNotificationsv2Result = $conn->query($checkNotificationsv2Sql);
    
    if ($checkNotificationsv2Result->num_rows === 0) {
        throw new Exception("Table 'notificationsv2' does not exist");
    }
    
    $checkDoerNotificationsSql = "SHOW TABLES LIKE 'doer_notifications'";
    $checkDoerNotificationsResult = $conn->query($checkDoerNotificationsSql);
    
    if ($checkDoerNotificationsResult->num_rows === 0) {
        throw new Exception("Table 'doer_notifications' does not exist");
    }
    
    file_put_contents('/tmp/php_debug.log', "Both notification tables exist\n", FILE_APPEND);
    
    // Test 4: Try inserting into notificationsv2
    file_put_contents('/tmp/php_debug.log', "Testing notificationsv2 insertion...\n", FILE_APPEND);
    
    $simpleSql = "INSERT INTO notificationsv2 (user_id, sender_id, type, title, content, associated_id, conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id, related_listing_title, is_read) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)";
    
    $simpleStmt = $conn->prepare($simpleSql);
    if (!$simpleStmt) {
        throw new Exception("Failed to prepare notificationsv2: " . $conn->error);
    }
    
    $testType = 'test_simple';
    $testTitle = 'Simple Test';
    $testContent = 'Simple test notification';
    $testAssociatedId = 0;
    $testConversationId = 0;
    $testListerId = $testUserId;
    $testDoerId = $testSenderId;
    $testListingTitle = '';
    
    $simpleStmt->bind_param("iisssiiiss",
        $testUserId,
        $testSenderId,
        $testType,
        $testTitle,
        $testContent,
        $testAssociatedId,
        $testConversationId,
        $testListerId,
        $testDoerId,
        $testListingTitle
    );
    
    if (!$simpleStmt->execute()) {
        throw new Exception("Failed to execute notificationsv2: " . $simpleStmt->error);
    }
    
    $simpleStmt->close();
    file_put_contents('/tmp/php_debug.log', "notificationsv2 inserted successfully\n", FILE_APPEND);
    
    // Test 5: Try inserting into doer_notifications
    file_put_contents('/tmp/php_debug.log', "Testing doer_notifications insertion...\n", FILE_APPEND);
    
    $doerSql = "INSERT INTO doer_notifications (user_id, sender_id, type, title, content, associated_id, conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id, related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)";
    
    $doerStmt = $conn->prepare($doerSql);
    if (!$doerStmt) {
        throw new Exception("Failed to prepare doer_notifications: " . $conn->error);
    }
    
    $doerStmt->bind_param("iisssiiissiiss",
        $testUserId,
        $testSenderId,
        $testType,
        $testTitle,
        $testContent,
        $testAssociatedId,
        $testConversationId,
        $testListerId,
        $testDoerId,
        $testListingTitle,
        null, // listing_id
        null, // listing_type
        null, // lister_id
        null  // lister_name
    );
    
    if (!$doerStmt->execute()) {
        throw new Exception("Failed to execute doer_notifications: " . $doerStmt->error);
    }
    
    $doerStmt->close();
    file_put_contents('/tmp/php_debug.log', "doer_notifications inserted successfully\n", FILE_APPEND);
    
    respond(true, "Both notification tables working correctly", [
        'database_connection' => 'passed',
        'users_table' => 'passed',
        'notificationsv2_table' => 'exists',
        'doer_notifications_table' => 'exists',
        'notificationsv2_insertion' => 'passed',
        'doer_notifications_insertion' => 'passed',
        'user_ids_found' => $userIds
    ]);
    
} catch (Exception $e) {
    file_put_contents('/tmp/php_debug.log', "Test error: " . $e->getMessage() . "\n", FILE_APPEND);
    respond(false, "Test failed: " . $e->getMessage());
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}

file_put_contents('/tmp/php_debug.log', 'test_simple_notification.php finished\n', FILE_APPEND); 