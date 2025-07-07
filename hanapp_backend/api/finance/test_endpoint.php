<?php
// hanapp_backend/api/finance/test_endpoint.php
// Basic test to see if PHP is working

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");

echo json_encode([
    "success" => true,
    "message" => "Test endpoint is working",
    "timestamp" => date('Y-m-d H:i:s'),
    "php_version" => PHP_VERSION
]);
?> 