<?php
// hanapp_backend/config/server.php
// Database connection configuration for Hanapp using PDO

// For local development - update these with your local MySQL credentials
$host = "localhost"; 
$user = "u688984333_danielmoto1212"; 
$pass = "@nasebRenz202525";  // Fixed: Correct password from working mysqli connection
$db = "u688984333_admin_hanap";   
$charset = 'utf8mb4';

// Uncomment the lines below if you want to use the remote server credentials
// $host = "localhost"; 
// $user = "u688984333_danielmoto1212"; 
// $pass = "nasebRenz202525@2015"; 
// $db = "u688984333_admin_hanap";   
// $charset = 'utf8mb4';
  
$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (\PDOException $e) {
    throw new \PDOException($e->getMessage(), (int)$e->getCode());
}
?> 