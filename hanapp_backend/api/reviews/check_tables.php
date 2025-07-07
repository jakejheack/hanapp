<?php
file_put_contents('/tmp/php_debug.log', 'check_tables.php reached\n', FILE_APPEND);

// Strict error reporting for production
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ERROR | E_PARSE);

require_once '../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
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
    file_put_contents('/tmp/php_debug.log', "Checking database tables...\n", FILE_APPEND);
    
    // Get all tables in the database
    $showTablesSql = "SHOW TABLES";
    $showTablesResult = $conn->query($showTablesSql);
    
    if (!$showTablesResult) {
        throw new Exception("Failed to get tables: " . $conn->error);
    }
    
    $allTables = [];
    while ($row = $showTablesResult->fetch_array()) {
        $allTables[] = $row[0];
    }
    
    file_put_contents('/tmp/php_debug.log', "All tables: " . implode(', ', $allTables) . "\n", FILE_APPEND);
    
    // Check for notification-related tables
    $notificationTables = [];
    $requiredTables = ['notificationsv2', 'doer_notifications', 'users'];
    
    foreach ($requiredTables as $table) {
        if (in_array($table, $allTables)) {
            $notificationTables[$table] = 'exists';
            
            // Get table structure
            $describeSql = "DESCRIBE $table";
            $describeResult = $conn->query($describeSql);
            
            if ($describeResult) {
                $columns = [];
                while ($row = $describeResult->fetch_assoc()) {
                    $columns[] = $row['Field'];
                }
                $notificationTables[$table . '_columns'] = $columns;
            }
        } else {
            $notificationTables[$table] = 'missing';
        }
    }
    
    respond(true, "Table check completed", [
        'all_tables' => $allTables,
        'notification_tables' => $notificationTables
    ]);
    
} catch (Exception $e) {
    file_put_contents('/tmp/php_debug.log', "Table check error: " . $e->getMessage() . "\n", FILE_APPEND);
    respond(false, "Table check failed: " . $e->getMessage());
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}

file_put_contents('/tmp/php_debug.log', 'check_tables.php finished\n', FILE_APPEND); 