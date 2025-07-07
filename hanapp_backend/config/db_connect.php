<?php
// hanapp_backend/config/db_connect.php
// Database connection configuration

$servername = "localhost";
$username = "u688984333_hanapp_use_new";       
$password = "Jardinel@2015";           
$dbname = "u688984333_hanapp_db_new";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    error_log("db_connect.php: Database connection failed: " . $conn->connect_error);
    die(json_encode([
        "success" => false, 
        "message" => "Database connection failed: " . $conn->connect_error
    ]));
} else {
    error_log("db_connect.php: Database connection established successfully");
}

// Set charset to utf8mb4
$conn->set_charset("utf8mb4");

// Set timezone
$conn->query("SET time_zone = '+08:00'");

// The $conn variable is now available to any file that includes this
?> 