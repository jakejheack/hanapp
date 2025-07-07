<?php
// hanapp_backend/api/utils/check_asap_status_endpoint.php
// Endpoint to check ASAP listings status via Postman

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/db_connect.php';

try {
    // Check all ASAP listings
    $sql = "
        SELECT al.id, al.lister_id, al.title, al.created_at, al.status, al.is_active,
               TIMESTAMPDIFF(MINUTE, al.created_at, NOW()) as minutes_old,
               CASE 
                   WHEN al.created_at < DATE_SUB(NOW(), INTERVAL 5 MINUTE) THEN 'ELIGIBLE_FOR_CONVERSION'
                   ELSE 'NOT_ELIGIBLE_YET'
               END as conversion_status,
               u.full_name as lister_name
        FROM asap_listings al
        LEFT JOIN users u ON al.lister_id = u.id
        ORDER BY al.created_at DESC
    ";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception("Query failed: " . $conn->error);
    }
    
    $asapListings = [];
    $eligibleCount = 0;
    $totalCount = 0;
    
    while ($row = $result->fetch_assoc()) {
        $asapListings[] = $row;
        $totalCount++;
        if ($row['conversion_status'] === 'ELIGIBLE_FOR_CONVERSION' && 
            $row['status'] === 'pending' && 
            $row['is_active'] == 1) {
            $eligibleCount++;
        }
    }
    
    $result->free();
    
    echo json_encode([
        "success" => true,
        "message" => "ASAP listings status",
        "summary" => [
            "total_asap_listings" => $totalCount,
            "active_pending_listings" => count(array_filter($asapListings, function($l) {
                return $l['is_active'] == 1 && $l['status'] === 'pending';
            })),
            "eligible_for_conversion" => $eligibleCount,
            "current_time" => date('Y-m-d H:i:s')
        ],
        "asap_listings" => $asapListings
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Error: " . $e->getMessage(),
        "current_time" => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 