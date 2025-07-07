<?php
// hanapp_backend/api/utils/cron_endpoint.php
// Simple endpoint for external cron services to trigger ASAP conversion

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Simple authentication (you can change this secret)
$cron_secret = 'your_cron_secret_key_here';
$provided_secret = $_GET['secret'] ?? '';

if ($provided_secret !== $cron_secret) {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ]);
    exit();
}

// Include the conversion script
include_once 'convert_asap_to_public.php';

// Return simple response
echo json_encode([
    'success' => true,
    'message' => 'Cron job executed',
    'timestamp' => date('Y-m-d H:i:s')
]);
?> 