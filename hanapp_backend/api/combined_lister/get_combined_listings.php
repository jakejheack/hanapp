<?php
// hanapp_backend/api/combined_lister/get_combined_listings.php
// Fetches combined listings (ASAP and Public) for a specific lister
// Modified to show only ASAP listings with "pending" status

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../config/db_connect.php';

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
        throw new Exception("Database connection not established: " . ($conn->connect_error ?? 'Unknown error'));
    }

    $userId = $_GET['user_id'] ?? null;
    $statusFilter = $_GET['status_filter'] ?? 'all';

    if (empty($userId) || !is_numeric($userId)) {
        throw new Exception("User ID is required and must be numeric.");
    }

    $userId = intval($userId);

    // MODIFIED: Only fetch ASAP listings with "pending" status
    $sql = "
        SELECT 
            al.id,
            al.lister_id,
            al.title,
            al.description,
            al.price,
            al.location_address,
            al.created_at,
            al.status,
            'ASAP' as listing_type,
            'Onsite' as category,
            u.full_name as lister_full_name,
            u.profile_picture_url as lister_profile_picture_url,
            al.latitude,
            al.longitude,
            al.is_active,
            COALESCE(lv.views, 0) AS views,
            COALESCE(app_counts.applicants_count, 0) AS applicants
        FROM 
            asap_listings al
        JOIN 
            users u ON al.lister_id = u.id
        LEFT JOIN 
            (SELECT listing_id, COUNT(*) AS views FROM listing_views GROUP BY listing_id) lv ON al.id = lv.listing_id
        LEFT JOIN
            (SELECT listing_id, COUNT(*) AS applicants_count FROM applicationsv2 WHERE listing_type = 'ASAP' GROUP BY listing_id) app_counts ON al.id = app_counts.listing_id
        WHERE 
            al.lister_id = ? 
            AND al.status = 'pending'
        ORDER BY 
            al.created_at DESC
    ";

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $stmt->bind_param("i", $userId);
    
    if (!$stmt->execute()) {
        throw new Exception("Failed to execute query: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $listings = [];
    $totalViews = 0;
    $totalApplicants = 0;

    while ($row = $result->fetch_assoc()) {
        // Convert server local timestamps to UTC for frontend
        $createdAtUTC = null;
        if ($row['created_at']) {
            $createdAtUTC = gmdate('Y-m-d H:i:s', strtotime($row['created_at']));
        }

        $listing = [
            'id' => intval($row['id']),
            'lister_id' => intval($row['lister_id']),
            'title' => $row['title'],
            'description' => $row['description'],
            'price' => floatval($row['price']),
            'location_address' => $row['location_address'],
            'created_at' => $createdAtUTC,
            'status' => $row['status'],
            'listing_type' => $row['listing_type'],
            'category' => $row['category'],
            'lister_full_name' => $row['lister_full_name'],
            'lister_profile_picture_url' => $row['lister_profile_picture_url'],
            'latitude' => $row['latitude'] ? floatval($row['latitude']) : null,
            'longitude' => $row['longitude'] ? floatval($row['longitude']) : null,
            'is_active' => (bool)($row['is_active'] ?? 0),
            'views' => intval($row['views']),
            'applicants' => intval($row['applicants']),
        ];

        $listings[] = $listing;
        $totalViews += intval($row['views']);
        $totalApplicants += intval($row['applicants']);
    }

    $stmt->close();

    error_log("get_combined_listings.php: Fetched " . count($listings) . " pending ASAP listings for user $userId");

    echo json_encode([
        "success" => true,
        "listings" => $listings,
        "total_views" => $totalViews,
        "total_applicants" => $totalApplicants,
        "count" => count($listings)
    ]);

} catch (Exception $e) {
    error_log("get_combined_listings.php: Error: " . $e->getMessage());
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