<?php
// debug_availability_api.php
// Test script to debug the availability status API

// Set error reporting
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "=== Availability API Debug Test ===\n\n";

// Test data
$testUserId = 1; // Replace with actual user ID
$testAvailability = true;

// Prepare the request data
$requestData = [
    'user_id' => $testUserId,
    'is_available' => $testAvailability
];

echo "Request Data: " . json_encode($requestData) . "\n\n";

// Make the API call
$url = 'http://localhost/hanapp/hanapp_backend/api/update_user_availability.php';
echo "API URL: $url\n\n";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Content-Length: ' . strlen(json_encode($requestData))
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_VERBOSE, true);

echo "Making API call...\n";
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

echo "HTTP Status Code: $httpCode\n";
echo "CURL Error: " . ($error ?: 'None') . "\n";
echo "Response: $response\n\n";

if ($response) {
    $responseData = json_decode($response, true);
    echo "Parsed Response: " . json_encode($responseData, JSON_PRETTY_PRINT) . "\n";
    
    if ($responseData['success']) {
        echo "\n✅ SUCCESS: Availability status updated successfully!\n";
        echo "User ID: " . $responseData['user']['id'] . "\n";
        echo "Availability: " . ($responseData['user']['is_available'] ? 'ON' : 'OFF') . "\n";
    } else {
        echo "\n❌ FAILED: " . $responseData['message'] . "\n";
    }
} else {
    echo "\n❌ FAILED: No response received\n";
}

echo "\n=== End Debug Test ===\n";
?> 