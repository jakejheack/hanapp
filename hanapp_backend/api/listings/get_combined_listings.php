<?php
// hanapp_backend/api/listings/get_combined_listings.php
// Fetches a combined list of public (listingsv2) and ASAP listings (asap_listings),
// filtered by the logged-in user's lister_id.
// It also includes total views and applicants for the *filtered* listings.
// MODIFIED: Only shows ASAP listings with "pending" status

// --- DEBUGGING: Temporarily enable error display for development ---
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
// --- END DEBUGGING ---

require_once '../config/db_connect.php'; // Ensure this path is correct relative to this script

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Handle preflight OPTIONS requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}


try {
    // Check if the global database connection variable is set and valid
 

    // Get user_id from query parameter. This is MANDATORY for this API's purpose.
    $userId = $_GET['user_id'] ?? null;

    if (empty($userId) || !is_numeric($userId)) {
        echo json_encode(["success" => false, "message" => "User ID is required and must be numeric to fetch your listings."]);
        exit(); // Stop execution if userId is missing or invalid
    }

    $listings = [];
    $totalViews = 0;
    $totalApplicants = 0;

    // --- Fetch Public Listings from listingsv2 ---
    // Join with 'users' table to get the lister's full name
    // Filter by 'is_active = TRUE' and 'lister_id = ?'
    $publicSql = "
        SELECT
            l.id,
            l.lister_id,
            u.full_name AS lister_full_name, -- Alias to match Flutter model
            l.title,
            l.description,
            l.category,
            l.price,
            l.location_address,
            l.latitude,
            l.longitude,
            l.created_at,
            l.is_active,
            l.tags,
            l.views,
            -- Assuming 'status' column exists for 'isCompleted' logic
            l.status, -- Add status column if you use it for completed logic
            (SELECT COUNT(a.id) FROM applicationsv2 a WHERE a.listing_id = l.id AND a.listing_type = 'PUBLIC') AS applicants_count
        FROM
            listingsv2 l
        JOIN
            users u ON l.lister_id = u.id
        WHERE
            l.lister_id = ? -- Filter by the provided user_id
    ";

    $stmtPublic = $conn->prepare($publicSql);
    if ($stmtPublic === false) {
        error_log("get_combined_listings.php: Failed to prepare public listings statement: " . $conn->error, 0);
        throw new Exception("Failed to prepare public listings database statement: " . $conn->error);
    }
    $stmtPublic->bind_param("i", $userId); // Bind the user ID for public listings
    $stmtPublic->execute();
    $publicResult = $stmtPublic->get_result();

    if ($publicResult) {
        while ($row = $publicResult->fetch_assoc()) {
            $listings[] = [
                'id' => (int)$row['id'],
                'lister_id' => (int)$row['lister_id'],
                'lister_full_name' => $row['lister_full_name'],
                'title' => $row['title'],
                'description' => $row['description'],
                'category' => $row['category'],
                'price' => $row['price'] !== null ? (double)$row['price'] : null,
                'location_address' => $row['location_address'],
                'latitude' => $row['latitude'] !== null ? (double)$row['latitude'] : null,
                'longitude' => $row['longitude'] !== null ? (double)$row['longitude'] : null,
                'created_at' => $row['created_at'],
                'is_active' => (bool)$row['is_active'],
                'tags' => $row['tags'],
                'listing_type' => 'PUBLIC', // Explicitly set type for Flutter
                'views' => (int)$row['views'],
                'applicants' => (int)$row['applicants_count'],
                'status' => $row['status'] ?? 'active', // Default status if not present
            ];
            $totalViews += (int)$row['views'];
            $totalApplicants += (int)$row['applicants_count'];
        }
    } else {
        error_log("get_combined_listings.php: Error fetching public listings: " . $stmtPublic->error);
    }
    $stmtPublic->close();

    // --- Fetch ASAP Listings from asap_listings ---
    // MODIFIED: Only fetch ASAP listings with "pending" status
    // Join with 'users' table to get the lister's full name
    // Filter by 'is_active = TRUE', 'lister_id = ?', and 'status = "pending"'
    $asapSql = "
        SELECT
            al.id,
            al.lister_id,
            u.full_name AS lister_full_name, -- Alias to match Flutter model
            al.title,
            al.description,
            al.price,
            al.location_address,
            al.latitude,
            al.longitude,
            al.created_at,
            al.is_active,
            al.tags,
            al.views,
            -- Assuming 'status' column exists for 'isCompleted' logic
            al.status, -- Add status column if you use it for completed logic
            (SELECT COUNT(a.id) FROM applicationsv2 a WHERE a.listing_id = al.id AND a.listing_type = 'ASAP') AS applicants_count
        FROM
            asap_listings al
        JOIN
            users u ON al.lister_id = u.id
        WHERE
            al.lister_id = ? -- Filter by the provided user_id
            AND al.status = 'pending' -- MODIFIED: Only show pending ASAP listings
    ";

    $stmtAsap = $conn->prepare($asapSql);
    if ($stmtAsap === false) {
        error_log("get_combined_listings.php: Failed to prepare ASAP listings statement: " . $conn->error, 0);
        throw new Exception("Failed to prepare ASAP listings database statement: " . $conn->error);
    }
    $stmtAsap->bind_param("i", $userId); // Bind the user ID for ASAP listings
    $stmtAsap->execute();
    $asapResult = $stmtAsap->get_result();

    if ($asapResult) {
        while ($row = $asapResult->fetch_assoc()) {
            $listings[] = [
                'id' => (int)$row['id'],
                'lister_id' => (int)$row['lister_id'],
                'lister_full_name' => $row['lister_full_name'],
                'title' => $row['title'],
                'description' => $row['description'],
                'category' => 'ASAP', // Hardcoded category for ASAP listings
                'price' => $row['price'] !== null ? (double)$row['price'] : null,
                'location_address' => $row['location_address'],
                'latitude' => $row['latitude'] !== null ? (double)$row['latitude'] : null,
                'longitude' => $row['longitude'] !== null ? (double)$row['longitude'] : null,
                'created_at' => $row['created_at'],
                'is_active' => (bool)$row['is_active'],
                'tags' => $row['tags'],
                'listing_type' => 'ASAP', // Explicitly set type for Flutter
                'views' => (int)$row['views'],
                'applicants' => (int)$row['applicants_count'],
                'status' => $row['status'] ?? 'active', // Default status if not present
            ];
            $totalViews += (int)$row['views'];
            $totalApplicants += (int)$row['applicants_count'];
        }
    } else {
        error_log("get_combined_listings.php: Error fetching ASAP listings: " . $stmtAsap->error);
    }
    $stmtAsap->close();

    // Sort combined listings by creation date (newest first)
    usort($listings, function($a, $b) {
        return strtotime($b['created_at']) - strtotime($a['created_at']);
    });

    // Send success response with filtered listings and totals
    echo json_encode([
        "success" => true,
        "listings" => $listings,
        "total_views" => $totalViews,
        "total_applicants" => $totalApplicants
    ]);

} catch (Exception $e) {
    http_response_code(500); // Internal Server Error
    error_log("get_combined_listings.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
} finally {
    // Ensure the database connection is closed if it was successfully opened.
    if (isset($conn) && $conn instanceof mysqli && !$conn->connect_error) {
        $conn->close();
    }
} 