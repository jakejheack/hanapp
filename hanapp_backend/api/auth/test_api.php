<?php
// Simple test to verify the API endpoint
header("Content-Type: application/json");

echo json_encode([
    "status" => "API endpoint is accessible",
    "timestamp" => date('Y-m-d H:i:s'),
    "method" => $_SERVER['REQUEST_METHOD'],
    "php_version" => PHP_VERSION
]);
?> 