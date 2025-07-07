<?php
// hanapp_backend/api/utils/trigger_asap_conversion.php
// Endpoint to trigger ASAP to PUBLIC conversion via Postman

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/db_connect.php';

try {
    // First, let's check what ASAP listings exist
    $checkSql = "
        SELECT al.id, al.lister_id, al.title, al.created_at, al.status, al.is_active,
               TIMESTAMPDIFF(MINUTE, al.created_at, NOW()) as minutes_old,
               CASE 
                   WHEN al.created_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE) THEN 'ELIGIBLE_FOR_CONVERSION'
                   ELSE 'NOT_ELIGIBLE_YET'
               END as conversion_status
        FROM asap_listings al
        WHERE al.is_active = TRUE AND al.status = 'pending'
        ORDER BY al.created_at DESC
    ";
    
    $result = $conn->query($checkSql);
    
    if (!$result) {
        throw new Exception("Check query failed: " . $conn->error);
    }
    
    $asapListings = [];
    $eligibleCount = 0;
    
    while ($row = $result->fetch_assoc()) {
        $asapListings[] = $row;
        if ($row['conversion_status'] === 'ELIGIBLE_FOR_CONVERSION') {
            $eligibleCount++;
        }
    }
    
    $result->free();
    
    // Capture the output from the conversion script
    ob_start();
    include 'convert_asap_to_public.php';
    $conversionOutput = ob_get_clean();
    
    // Try to decode the conversion result
    $conversionResult = null;
    if (!empty($conversionOutput)) {
        $conversionResult = json_decode($conversionOutput, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $conversionResult = ['raw_output' => $conversionOutput];
        }
    }
    
    // Return comprehensive results
    echo json_encode([
        "success" => true,
        "message" => "ASAP conversion triggered",
        "before_conversion" => [
            "total_asap_listings" => count($asapListings),
            "eligible_for_conversion" => $eligibleCount,
            "asap_listings" => $asapListings
        ],
        "conversion_result" => $conversionResult,
        "current_time" => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Error: " . $e->getMessage(),
        "current_time" => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT);
} finally {
    if (isset($conn) && $conn instanceof mysqli) {
        $conn->close();
    }
}
?> 