<?php
// hanapp_backend/api/doer/get_available_listings.php
// Fetches available listings (ASAP and Public) for doers, with filters

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (!isset($conn) || $conn->connect_error) {
    error_log("Database connection not established in get_available_listings.php: " . $conn->connect_error);
    echo json_encode(["success" => false, "message" => "Database connection not established."]);
    exit();
}

// Get query parameters
$categoryFilter = $_GET['category'] ?? 'All'; // 'All', 'Onsite', 'Hybrid', 'Remote'
$searchQuery = $_GET['search_query'] ?? '';
$minBudget = $_GET['min_budget'] ?? null;
$datePosted = $_GET['date_posted'] ?? null;
$currentDoerId = $_GET['current_doer_id'] ?? null;
$distance = $_GET['distance'] ?? null; // in km
$userLat = $_GET['user_latitude'] ?? null;
$userLng = $_GET['user_longitude'] ?? null;

// Debug logging for all parameters
error_log("get_available_listings.php: Received parameters - categoryFilter: $categoryFilter, searchQuery: $searchQuery, minBudget: $minBudget, datePosted: $datePosted, currentDoerId: $currentDoerId, distance: $distance, userLat: $userLat, userLng: $userLng");

// Debug: Check ASAP listings directly
$debugAsapQuery = "SELECT COUNT(*) as count, 
                          SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active_count,
                          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
                          SUM(CASE WHEN lister_id != ? THEN 1 ELSE 0 END) as not_own_count
                   FROM asap_listings";
$debugStmt = $conn->prepare($debugAsapQuery);
if ($debugStmt) {
    $debugStmt->bind_param("i", $currentDoerId);
    $debugStmt->execute();
    $debugResult = $debugStmt->get_result();
    $debugData = $debugResult->fetch_assoc();
    error_log("get_available_listings.php: ASAP Debug - Total: {$debugData['count']}, Active: {$debugData['active_count']}, Pending: {$debugData['pending_count']}, Not Own: {$debugData['not_own_count']}");
    $debugStmt->close();
}

// Debug: Show actual ASAP listings
$debugAsapListingsQuery = "SELECT id, lister_id, title, status, is_active, created_at FROM asap_listings ORDER BY created_at DESC LIMIT 5";
$debugListingsStmt = $conn->prepare($debugAsapListingsQuery);
if ($debugListingsStmt) {
    $debugListingsStmt->execute();
    $debugListingsResult = $debugListingsStmt->get_result();
    error_log("get_available_listings.php: Recent ASAP listings:");
    while ($row = $debugListingsResult->fetch_assoc()) {
        error_log("get_available_listings.php: ASAP ID: {$row['id']}, Lister: {$row['lister_id']}, Title: {$row['title']}, Status: {$row['status']}, Active: {$row['is_active']}, Created: {$row['created_at']}");
    }
    $debugListingsStmt->close();
}

// Helper to build WHERE and params for each table
function buildWhereAndParams($tableAlias, $categoryField, $categoryFilter, $searchQuery, $minBudget, $datePosted, $currentDoerId, $isAsap) {
    $where = [];
    $params = [];
    $types = '';
    
    // Debug logging
    error_log("buildWhereAndParams: tableAlias=$tableAlias, categoryFilter=$categoryFilter, isAsap=" . ($isAsap ? 'true' : 'false'));
    
    if ($isAsap) {
        $where[] = "$tableAlias.is_active = TRUE AND $tableAlias.status = 'pending'";
        // Only include ASAP listings if category is 'All' or 'Onsite'
        if ($categoryFilter !== 'All' && $categoryFilter !== 'Onsite') {
            // Force no results for ASAP if filter is not All/Onsite
            error_log("buildWhereAndParams: Excluding ASAP listings due to category filter: $categoryFilter");
            $where[] = '1=0';
        } else {
            error_log("buildWhereAndParams: Including ASAP listings for category filter: $categoryFilter");
        }
    } else {
        $where[] = "$tableAlias.is_active = TRUE AND $tableAlias.status = 'open'";
        if ($categoryFilter !== 'All') {
            $where[] = "$categoryField = ?";
            $types .= 's';
            $params[] = $categoryFilter;
            error_log("buildWhereAndParams: Adding category filter for public listings: $categoryFilter");
        }
    }
    if ($currentDoerId !== null && is_numeric($currentDoerId)) {
        $where[] = "$tableAlias.lister_id != ?";
        $types .= 'i';
        $params[] = intval($currentDoerId);
        error_log("buildWhereAndParams: Filtering out listings from user ID: $currentDoerId");
    }
    if (!empty($searchQuery)) {
        $where[] = "($tableAlias.title LIKE ? OR $tableAlias.description LIKE ? OR $tableAlias.location_address LIKE ?)";
        $types .= 'sss';
        $searchPattern = "%$searchQuery%";
        $params[] = $searchPattern;
        $params[] = $searchPattern;
        $params[] = $searchPattern;
        error_log("buildWhereAndParams: Adding search filter: $searchQuery");
    }
    if ($minBudget !== null && is_numeric($minBudget)) {
        $where[] = "$tableAlias.price >= ?";
        $types .= 'd';
        $params[] = floatval($minBudget);
        error_log("buildWhereAndParams: Adding min budget filter: $minBudget");
    }
    if ($datePosted !== null) {
        $where[] = "DATE($tableAlias.created_at) = ?";
        $types .= 's';
        $params[] = $datePosted;
        error_log("buildWhereAndParams: Adding date filter: $datePosted");
    }
    
    $whereClause = implode(' AND ', $where);
    error_log("buildWhereAndParams: Final WHERE clause for $tableAlias: $whereClause");
    
    return [$where, $params, $types];
}

list($asapWhere, $asapParams, $asapTypes) = buildWhereAndParams('al', 'category', $categoryFilter, $searchQuery, $minBudget, $datePosted, $currentDoerId, true);
list($lWhere, $lParams, $lTypes) = buildWhereAndParams('l', 'l.category', $categoryFilter, $searchQuery, $minBudget, $datePosted, $currentDoerId, false);

// Distance filter (Haversine formula)
$distanceSelect = '';
$asapDistanceSelect = '';
$having = '';
$asapHaving = '';
$distanceEnabled = $distance !== null && is_numeric($distance) && $userLat !== null && $userLng !== null && is_numeric($userLat) && is_numeric($userLng);
if ($distanceEnabled) {
    $distanceSelect = ", (6371 * acos(cos(radians(?)) * cos(radians(l.latitude)) * cos(radians(l.longitude) - radians(?)) + sin(radians(?)) * sin(radians(l.latitude)))) AS distance_km";
    $asapDistanceSelect = ", (6371 * acos(cos(radians(?)) * cos(radians(al.latitude)) * cos(radians(al.longitude) - radians(?)) + sin(radians(?)) * sin(radians(al.latitude)))) AS distance_km";
    $having = "HAVING distance_km <= " . floatval($distance);
    $asapHaving = $having;
}

// Build SQL for both tables
$asapWhereClause = implode(' AND ', $asapWhere);
$lWhereClause = implode(' AND ', $lWhere);

$asapSql = "SELECT al.id, al.lister_id, al.title, al.description, al.price, al.location_address, al.created_at, al.status, 'ASAP' as listing_type, 'Onsite' as category, u.full_name as lister_full_name, u.profile_picture_url as lister_profile_picture_url, al.latitude, al.longitude $asapDistanceSelect FROM asap_listings al JOIN users u ON al.lister_id = u.id WHERE $asapWhereClause $asapHaving";
$lSql = "SELECT l.id, l.lister_id, l.title, l.description, l.price, l.location_address, l.created_at, l.status, 'PUBLIC' as listing_type, l.category, u.full_name as lister_full_name, u.profile_picture_url as lister_profile_picture_url, l.latitude, l.longitude $distanceSelect FROM listingsv2 l JOIN users u ON l.lister_id = u.id WHERE $lWhereClause $having";

// Combine with UNION ALL
$sql = "$asapSql UNION ALL $lSql ORDER BY created_at DESC";

// Merge params and types for both queries
$allParams = [];
$allTypes = '';
if ($distanceEnabled) {
    // For ASAP
    $asapTypes = 'ddd' . $asapTypes;
    array_unshift($asapParams, floatval($userLng));
    array_unshift($asapParams, floatval($userLat));
    array_unshift($asapParams, floatval($userLat));
    // For Public
    $lTypes = 'ddd' . $lTypes;
    array_unshift($lParams, floatval($userLng));
    array_unshift($lParams, floatval($userLat));
    array_unshift($lParams, floatval($userLat));
}
$allTypes = $asapTypes . $lTypes;
$allParams = array_merge($asapParams, $lParams);

// If there are no parameters, use query(); otherwise, use prepare()
$listings = [];
if (empty($allTypes)) {
    $result = $conn->query($sql);
    if (!$result) {
        error_log("get_available_listings.php: Query error: " . $conn->error);
        echo json_encode([
            "success" => false,
            "message" => "Database error: " . $conn->error
        ]);
        exit();
    }
    while ($row = $result->fetch_assoc()) {
        if (isset($row['price'])) {
            $row['price'] = (float)$row['price'];
        }
        if (isset($row['distance_km'])) {
            $row['distance_km'] = round($row['distance_km'], 2);
        }
        $listings[] = $row;
    }
    $result->free();
} else {
    // Use prepare() and bind_param for both queries
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        error_log("Failed to prepare listings statement: " . $conn->error);
        echo json_encode(["success" => false, "message" => "Internal server error."]);
        exit();
    }
    $stmt->bind_param($allTypes, ...$allParams);
    if ($stmt->execute()) {
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            if (isset($row['price'])) {
                $row['price'] = (float)$row['price'];
            }
            if (isset($row['distance_km'])) {
                $row['distance_km'] = round($row['distance_km'], 2);
            }
            $listings[] = $row;
        }
        $stmt->close();
    } else {
        error_log("Error executing get available listings statement: " . $stmt->error);
        echo json_encode(["success" => false, "message" => "Failed to fetch available listings. Please try again."]);
        $stmt->close();
        $conn->close();
        exit();
    }
}
$conn->close();

// Debug logging for results
$asapCount = 0;
$publicCount = 0;
foreach ($listings as $listing) {
    if ($listing['listing_type'] === 'ASAP') {
        $asapCount++;
    } else {
        $publicCount++;
    }
}
error_log("get_available_listings.php: Results - Total: " . count($listings) . ", ASAP: $asapCount, Public: $publicCount");

echo json_encode([
    "success" => true,
    "listings" => $listings,
    "total_count" => count($listings)
]);
?> 