<?php
// Simple test for update_role.php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "<h2>Testing update_role.php</h2>";

// Test 1: Check if file exists
echo "<h3>Test 1: File Existence</h3>";
$file_path = __DIR__ . '/update_role.php';
if (file_exists($file_path)) {
    echo "<p style='color: green;'>✓ update_role.php file exists</p>";
} else {
    echo "<p style='color: red;'>✗ update_role.php file does NOT exist</p>";
}

// Test 2: Check if server.php exists
echo "<h3>Test 2: Server.php Existence</h3>";
$server_path = __DIR__ . '/../../config/server.php';
if (file_exists($server_path)) {
    echo "<p style='color: green;'>✓ server.php file exists</p>";
} else {
    echo "<p style='color: red;'>✗ server.php file does NOT exist at: $server_path</p>";
}

// Test 3: Test include path
echo "<h3>Test 3: Include Path Test</h3>";
try {
    include $server_path;
    echo "<p style='color: green;'>✓ Successfully included server.php</p>";
    
    if (isset($pdo)) {
        echo "<p style='color: green;'>✓ PDO connection object is available</p>";
    } else {
        echo "<p style='color: red;'>✗ PDO connection object is NOT available</p>";
    }
} catch (Exception $e) {
    echo "<p style='color: red;'>✗ Error including server.php: " . $e->getMessage() . "</p>";
}

// Test 4: Test JSON parsing
echo "<h3>Test 4: JSON Parsing Test</h3>";
$test_json = '{"user_id": 1, "role": "doer"}';
$parsed = json_decode($test_json);
if ($parsed !== null) {
    echo "<p style='color: green;'>✓ JSON parsing works correctly</p>";
    echo "<p>Parsed user_id: " . $parsed->user_id . "</p>";
    echo "<p>Parsed role: " . $parsed->role . "</p>";
} else {
    echo "<p style='color: red;'>✗ JSON parsing failed</p>";
}

echo "<h3>Next Steps:</h3>";
echo "<p>1. First run the database connection test: <a href='../../config/test_connection.php'>test_connection.php</a></p>";
echo "<p>2. If database connection works, test the actual API endpoint</p>";
?> 