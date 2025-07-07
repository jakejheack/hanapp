<?php
// hanapp_backend/api/wallet/test_wallet.php
// Simple test to check if wallet directory is accessible

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");

echo json_encode([
    "success" => true,
    "message" => "Wallet directory is accessible",
    "timestamp" => date('Y-m-d H:i:s'),
    "php_version" => PHP_VERSION
]);
?> 