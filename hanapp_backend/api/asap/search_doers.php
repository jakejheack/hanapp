<?php
// hanapp_backend/api/asap/search_doers.php
// Search for available doers for an ASAP listing

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../config/db_connect.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $listingId = $input['listing_id'] ?? null;
    $listerLatitude = $input['lister_latitude'] ?? null;
    $listerLongitude = $input['lister_longitude'] ?? null;
    $preferredDoerGender = $input['preferred_doer_gender'] ?? 'Any';
    $maxDistance = $input['max_distance'] ?? 10; // Default 10km
    $currentTime = date('Y-m-d H:i:s');
    
    if (!$listingId || !$listerLatitude || !$listerLongitude) {
        throw new Exception('Missing required parameters: listing_id, lister_latitude, lister_longitude');
    }
    
    // First, get the ASAP listing details
    $listingQuery = "SELECT * FROM asap_listings WHERE id = ? AND status = 'pending'";
    $listingStmt = $conn->prepare($listingQuery);
    $listingStmt->bind_param('i', $listingId);
    $listingStmt->execute();
    $listingResult = $listingStmt->get_result();
    
    if ($listingResult->num_rows === 0) {
        throw new Exception('ASAP listing not found or not in pending status');
    }
    
    $listing = $listingResult->fetch_assoc();
    
    // Build the doer search query with distance calculation (dynamic, with parameter binding)
    $distanceSelect = "(6371 * acos(cos(radians(?)) * cos(radians(u.latitude)) * cos(radians(u.longitude) - radians(?)) + sin(radians(?)) * sin(radians(u.latitude)))) AS distance_km";
    
    $sql = "SELECT 
                u.id,
                u.full_name,
                u.profile_picture_url,
                u.latitude,
                u.longitude,
                u.address_details,
                u.average_rating,
                u.review_count,
                u.is_verified,
                u.id_verified,
                u.badge_acquired,
                $distanceSelect
            FROM users u
            WHERE u.role = 'doer' 
            AND u.is_available = 1
            AND u.is_deleted = 0";
    
    $params = [(float)$listerLatitude, (float)$listerLongitude, (float)$listerLatitude];
    $types = 'ddd';
    
    // Add gender filter if specified
    if ($preferredDoerGender !== 'Any') {
        $sql .= " AND u.gender = ?";
        $params[] = $preferredDoerGender;
        $types .= 's';
    }
    
    // Add distance filter
    $sql .= " HAVING distance_km <= ?
            ORDER BY distance_km ASC, u.average_rating DESC, u.updated_at DESC
            LIMIT 10";
    $params[] = (float)$maxDistance;
    $types .= 'd';
    
    // Debug logging
    error_log('SQL: ' . $sql);
    error_log('Params: ' . json_encode($params));
    error_log('Types: ' . $types);
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('SQL prepare failed: ' . $conn->error);
    }
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    error_log('Rows found: ' . $result->num_rows);
    $doers = [];
    while ($row = $result->fetch_assoc()) {
        $doers[] = [
            'id' => $row['id'],
            'full_name' => $row['full_name'],
            'profile_picture_url' => $row['profile_picture_url'],
            'latitude' => $row['latitude'],
            'longitude' => $row['longitude'],
            'address_details' => $row['address_details'],
            'average_rating' => (float)$row['average_rating'],
            'total_reviews' => $row['review_count'],
            'is_verified' => (bool)$row['is_verified'],
            'is_id_verified' => (bool)$row['id_verified'],
            'is_badge_acquired' => (bool)$row['badge_acquired'],
            'distance_km' => round($row['distance_km'], 2),
            'is_available' => true,
            'last_active' => $row['updated_at'] ?? null,
        ];
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Doers found successfully',
        'doers' => $doers,
        'total_count' => count($doers),
        'listing' => [
            'id' => $listing['id'],
            'title' => $listing['title'],
            'price' => $listing['price'],
            'location_address' => $listing['location_address'],
        ]
    ]);
    
} catch (Exception $e) {
    error_log("search_doers.php error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?> 