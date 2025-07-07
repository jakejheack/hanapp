<?php
// hanapp_backend/api/get_listings.php
// Fetches job listings, optionally filtered by status, lister_id, or doer_id.
// This file uses db_connect.php for database connection.

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once '../../db_connect.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Check if database connection is working
    if (!$conn || $conn->connect_error) {
        throw new Exception("Database connection failed: " . ($conn ? $conn->connect_error : "No connection"));
    }

    $status = $_GET['status'] ?? '';
    $lister_id = $_GET['lister_id'] ?? '';
    $doer_id = $_GET['doer_id'] ?? ''; // Changed from owner_id to doer_id

    // Base SQL query to get listings and join with users to get lister's name and profile picture
    // Also include subqueries for views and applicants count
    $sql = "SELECT 
                l.id, 
                l.lister_id, 
                l.title, 
                l.price, 
                l.description, 
                l.address, 
                l.category, 
                l.tags, 
                l.image_url, 
                l.status, 
                l.created_at, 
                u.full_name AS lister_name, 
                u.profile_picture_url AS lister_profile_picture_url,
                COALESCE(lv.views, 0) AS views, -- Get views, default to 0 if no entry
                COALESCE(app_counts.applicants_count, 0) AS applicants_count -- Get applicants count, default to 0
            FROM 
                listings l 
            JOIN 
                users u ON l.lister_id = u.id
            LEFT JOIN 
                (SELECT listing_id, COUNT(*) AS views FROM listing_views GROUP BY listing_id) lv ON l.id = lv.listing_id
            LEFT JOIN
                (SELECT listing_id, COUNT(*) AS applicants_count FROM applications GROUP BY listing_id) app_counts ON l.id = app_counts.listing_id";


    $params = []; // Array to hold parameters for prepared statement
    $types = ""; // String to hold parameter types for prepared statement
    $where_clauses = []; // Array to build WHERE clauses

    // Add conditions based on query parameters
    if (!empty($status) && $status !== 'all') {
        $where_clauses[] = "l.status = ?";
        $params[] = $status;
        $types .= "s"; // 's' for string
    }

    if (!empty($lister_id)) {
        $where_clauses[] = "l.lister_id = ?";
        $params[] = $lister_id;
        $types .= "i"; // 'i' for integer
    }

    if (!empty($doer_id)) { // Changed from owner_id to doer_id
        // If filtering by doer_id, we need to join with the applications table
        // Ensure DISTINCT to avoid duplicate listings if a doer applies multiple times (though unique constraint prevents this)
        $sql = "SELECT DISTINCT 
                    l.id, 
                    l.lister_id, 
                    l.title, 
                    l.price, 
                    l.description, 
                    l.address, 
                    l.category, 
                    l.tags, 
                    l.image_url, 
                    l.status, 
                    l.created_at, 
                    u.full_name AS lister_name, 
                    u.profile_picture_url AS lister_profile_picture_url,
                    COALESCE(lv.views, 0) AS views,
                    COALESCE(app_counts.applicants_count, 0) AS applicants_count
                FROM 
                    listings l 
                JOIN 
                    users u ON l.lister_id = u.id 
                JOIN 
                    applications a ON l.id = a.listing_id
                LEFT JOIN 
                    (SELECT listing_id, COUNT(*) AS views FROM listing_views GROUP BY listing_id) lv ON l.id = lv.listing_id
                LEFT JOIN
                    (SELECT listing_id, COUNT(*) AS applicants_count FROM applications GROUP BY listing_id) app_counts ON l.id = app_counts.listing_id";

        $where_clauses[] = "a.applicant_id = ?";
        $params[] = $doer_id; // Changed to doer_id
        $types .= "i";
    }

    // Append WHERE clauses if any
    if (!empty($where_clauses)) {
        $sql .= " WHERE " . implode(" AND ", $where_clauses);
    }

    $sql .= " ORDER BY l.created_at DESC"; // Order by creation date, newest first

    // Debug: Log the SQL query
    error_log("get_listings.php - SQL Query: " . $sql);
    error_log("get_listings.php - Parameters: " . json_encode($params));

    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Prepare statement failed: " . $conn->error);
    }

    // Bind parameters if there are any
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result(); // Get the result set
    
    if (!$result) {
        throw new Exception("Get result failed: " . $stmt->error);
    }

    $listings = [];
    while ($row = $result->fetch_assoc()) {
        $listings[] = $row; // Fetch each row as an associative array
    }

    echo json_encode([
        "success" => true, 
        "listings" => $listings,
        "count" => count($listings),
        "debug" => [
            "sql" => $sql,
            "params" => $params,
            "types" => $types
        ]
    ]); // Return listings as JSON

    $stmt->close();

} catch (Exception $e) {
    error_log("get_listings.php - Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        "success" => false, 
        "error" => $e->getMessage(),
        "debug" => [
            "file" => __FILE__,
            "line" => __LINE__
        ]
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?> 