<?php
// check_asap_status.php
// Check the current status of ASAP listings

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once 'hanapp_backend/config/db_connect.php';

header('Content-Type: application/json');

try {
    // Check all ASAP listings
    $sql = "
        SELECT al.id, al.lister_id, al.title, al.created_at, al.status, al.is_active,
               TIMESTAMPDIFF(MINUTE, al.created_at, NOW()) as minutes_old,
               CASE 
                   WHEN al.created_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE) THEN 'ELIGIBLE_FOR_CONVERSION'
                   ELSE 'NOT_ELIGIBLE_YET'
               END as conversion_status
        FROM asap_listings al
        ORDER BY al.created_at DESC
    ";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception("Query failed: " . $conn->error);
    }
    
    $asapListings = [];
    while ($row = $result->fetch_assoc()) {
        $asapListings[] = $row;
    }
    
    // Count eligible for conversion
    $eligibleCount = 0;
    foreach ($asapListings as $listing) {
        if ($listing['conversion_status'] === 'ELIGIBLE_FOR_CONVERSION' && 
            $listing['status'] === 'pending' && 
            $listing['is_active'] == 1) {
            $eligibleCount++;
        }
    }
    
    echo json_encode([
        "success" => true,
        "message" => "ASAP listings status",
        "asap_listings" => $asapListings,
        "total_count" => count($asapListings),
        "eligible_for_conversion" => $eligibleCount,
        "current_time" => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Error: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 