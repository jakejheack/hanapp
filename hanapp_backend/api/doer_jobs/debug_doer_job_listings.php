<?php
// Debug version of get_doer_job_listings.php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection not established.");
    }

    $doerId = $_GET['doer_id'] ?? null;
    $statusFilter = $_GET['status_filter'] ?? 'all';

    if (empty($doerId) || !is_numeric($doerId)) {
        throw new Exception("Doer ID is required and must be numeric.");
    }

    $doerId = intval($doerId);
    
    // Debug: First, let's see what applications exist for this doer
    $debugSql = "
        SELECT 
            a.id AS application_id,
            a.listing_id,
            a.listing_type,
            a.status AS application_status,
            pl.title AS public_title,
            pl.price AS public_price,
            al.title AS asap_title,
            al.price AS asap_price,
            COALESCE(pl.title, al.title) AS combined_title,
            COALESCE(pl.price, al.price) AS combined_price
        FROM applicationsv2 a
        LEFT JOIN listingsv2 pl ON a.listing_id = pl.id AND a.listing_type = 'PUBLIC'
        LEFT JOIN asap_listings al ON a.listing_id = al.id AND a.listing_type = 'ASAP'
        WHERE a.doer_id = ?
        ORDER BY a.applied_at DESC
        LIMIT 5
    ";
    
    $debugStmt = $conn->prepare($debugSql);
    $debugStmt->bind_param("i", $doerId);
    $debugStmt->execute();
    $debugResult = $debugStmt->get_result();
    
    $debugData = [];
    while ($row = $debugResult->fetch_assoc()) {
        $debugData[] = [
            'application_id' => $row['application_id'],
            'listing_id' => $row['listing_id'],
            'listing_type' => $row['listing_type'],
            'application_status' => $row['application_status'],
            'public_title' => $row['public_title'],
            'public_price' => $row['public_price'],
            'asap_title' => $row['asap_title'],
            'asap_price' => $row['asap_price'],
            'combined_title' => $row['combined_title'],
            'combined_price' => $row['combined_price'],
        ];
    }
    $debugStmt->close();
    
    // Also check if the listings exist
    $listingCheckSql = "
        SELECT 
            'public' as type,
            id,
            title,
            price
        FROM listingsv2 
        WHERE id IN (SELECT DISTINCT listing_id FROM applicationsv2 WHERE doer_id = ? AND listing_type = 'PUBLIC')
        UNION ALL
        SELECT 
            'asap' as type,
            id,
            title,
            price
        FROM asap_listings 
        WHERE id IN (SELECT DISTINCT listing_id FROM applicationsv2 WHERE doer_id = ? AND listing_type = 'ASAP')
    ";
    
    $listingCheckStmt = $conn->prepare($listingCheckSql);
    $listingCheckStmt->bind_param("ii", $doerId, $doerId);
    $listingCheckStmt->execute();
    $listingCheckResult = $listingCheckStmt->get_result();
    
    $listingData = [];
    while ($row = $listingCheckResult->fetch_assoc()) {
        $listingData[] = [
            'type' => $row['type'],
            'id' => $row['id'],
            'title' => $row['title'],
            'price' => $row['price'],
        ];
    }
    $listingCheckStmt->close();
    
    echo json_encode([
        "success" => true,
        "debug_info" => [
            "doer_id" => $doerId,
            "status_filter" => $statusFilter,
            "application_data" => $debugData,
            "listing_data" => $listingData,
            "note" => "This shows the raw data from database to help debug title/price issues"
        ]
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
}
?> 