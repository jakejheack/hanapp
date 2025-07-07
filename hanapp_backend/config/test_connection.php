<?php
// Test database connection
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "<h2>Testing Database Connection</h2>";

// Database configuration
$host = "localhost"; 
$user = "u688984333_danielmoto1212"; 
$pass = "nasebRenz202525@2015"; 
$db = "u688984333_admin_hanap";   
$charset = 'utf8mb4';

echo "<p><strong>Connection Details:</strong></p>";
echo "<p>Host: $host</p>";
echo "<p>User: $user</p>";
echo "<p>Database: $db</p>";
echo "<p>Charset: $charset</p>";

// Test 1: Check if PDO is available
echo "<h3>Test 1: PDO Extension</h3>";
if (extension_loaded('pdo')) {
    echo "<p style='color: green;'>✓ PDO extension is loaded</p>";
    if (extension_loaded('pdo_mysql')) {
        echo "<p style='color: green;'>✓ PDO MySQL driver is loaded</p>";
    } else {
        echo "<p style='color: red;'>✗ PDO MySQL driver is NOT loaded</p>";
    }
} else {
    echo "<p style='color: red;'>✗ PDO extension is NOT loaded</p>";
}

// Test 2: Try to connect to MySQL server (without specifying database)
echo "<h3>Test 2: MySQL Server Connection</h3>";
try {
    $dsn_server = "mysql:host=$host;charset=$charset";
    $pdo_server = new PDO($dsn_server, $user, $pass);
    echo "<p style='color: green;'>✓ Successfully connected to MySQL server</p>";
    
    // Test 3: Check if database exists
    echo "<h3>Test 3: Database Existence</h3>";
    $stmt = $pdo_server->query("SHOW DATABASES LIKE '$db'");
    if ($stmt->rowCount() > 0) {
        echo "<p style='color: green;'>✓ Database '$db' exists</p>";
    } else {
        echo "<p style='color: red;'>✗ Database '$db' does NOT exist</p>";
        
        // Show available databases
        echo "<p><strong>Available databases:</strong></p>";
        $stmt = $pdo_server->query("SHOW DATABASES");
        while ($row = $stmt->fetch()) {
            echo "<p>- " . $row['Database'] . "</p>";
        }
    }
    
} catch (PDOException $e) {
    echo "<p style='color: red;'>✗ Failed to connect to MySQL server: " . $e->getMessage() . "</p>";
}

// Test 4: Try to connect to specific database
echo "<h3>Test 4: Database Connection</h3>";
try {
    $dsn = "mysql:host=$host;dbname=$db;charset=$charset";
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];
    
    $pdo = new PDO($dsn, $user, $pass, $options);
    echo "<p style='color: green;'>✓ Successfully connected to database '$db'</p>";
    
    // Test 5: Check if users table exists
    echo "<h3>Test 5: Users Table</h3>";
    $stmt = $pdo->query("SHOW TABLES LIKE 'users'");
    if ($stmt->rowCount() > 0) {
        echo "<p style='color: green;'>✓ Users table exists</p>";
        
        // Show table structure
        $stmt = $pdo->query("DESCRIBE users");
        echo "<p><strong>Users table structure:</strong></p>";
        echo "<table border='1' style='border-collapse: collapse;'>";
        echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
        while ($row = $stmt->fetch()) {
            echo "<tr>";
            echo "<td>" . $row['Field'] . "</td>";
            echo "<td>" . $row['Type'] . "</td>";
            echo "<td>" . $row['Null'] . "</td>";
            echo "<td>" . $row['Key'] . "</td>";
            echo "<td>" . $row['Default'] . "</td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "<p style='color: red;'>✗ Users table does NOT exist</p>";
        
        // Show available tables
        echo "<p><strong>Available tables:</strong></p>";
        $stmt = $pdo->query("SHOW TABLES");
        while ($row = $stmt->fetch()) {
            echo "<p>- " . $row['Tables_in_' . $db] . "</p>";
        }
    }
    
} catch (PDOException $e) {
    echo "<p style='color: red;'>✗ Failed to connect to database '$db': " . $e->getMessage() . "</p>";
}
?> 