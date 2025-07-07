<?php
// hanapp_backend/api/doer_jobs/get_doer_job_listings.php
// Fetches job listings for a specific Doer, filtered by application status.

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../../config/db_connect.php'; // Fixed path - should be two levels up

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
        error_log("get_doer_job_listings.php: Database connection not established: " . ($conn->connect_error ?? 'Unknown error'), 0);
        throw new Exception("Database connection not established.");
    }

    $doerId = $_GET['doer_id'] ?? null;
    $statusFilter = $_GET['status_filter'] ?? 'all';

    if (empty($doerId) || !is_numeric($doerId)) {
        error_log("get_doer_job_listings.php: Validation failed - Doer ID is missing or invalid. Received doer_id: " . var_export($doerId, true), 0);
        throw new Exception("Doer ID is required and must be numeric.");
    }

    $doerId = intval($doerId);
    $whereClause = "a.doer_id = ?";
    $params = [$doerId];
    $types = "i";

    // Add status filter only if not 'all'
    if ($statusFilter !== 'all') {
        switch ($statusFilter) {
            case 'in_progress': // Flutter's 'Ongoing' tab requests 'in_progress' filter
                $whereClause .= " AND a.status = 'in_progress'";
                break;
            case 'pending':
                $whereClause .= " AND a.status = 'pending'";
                break;
            case 'completed':
                $whereClause .= " AND a.status = 'completed'";
                break;
            case 'cancelled':
                $whereClause .= " AND a.status = 'cancelled'";
                break;
            case 'rejected':
                $whereClause .= " AND a.status = 'rejected'";
                break;
            case 'accepted':
                $whereClause .= " AND a.status = 'accepted'";
                break;
            default:
                // For unknown status filters, still filter by doer_id only
                error_log("get_doer_job_listings.php: Unknown status filter: $statusFilter", 0);
                break;
        }
    }

    $sql = "
        SELECT
            a.id AS application_id,
            a.listing_id,
            a.listing_type,
            a.message, -- This is the application message
            a.status AS application_status,
            a.applied_at,
            a.earned_amount,
            a.transaction_no,
            a.cancellation_reason,
            COALESCE(pl.title, al.title) AS listing_title,
            COALESCE(pl.description, al.description) AS listing_description,
            COALESCE(pl.price, al.price) AS listing_price,
            COALESCE(pl.location_address, al.location_address) AS listing_location_address,
            COALESCE(pl.category) AS listing_category,
            COALESCE(pl.created_at, al.created_at) AS listing_created_at,
            COALESCE(pl.lister_id, al.lister_id) AS lister_id,
            COALESCE(pl.is_asap, al.is_asap) AS is_asap, -- Added is_asap
            u.full_name AS lister_full_name,
            u.profile_picture_url AS lister_profile_picture_url,
            cv.id AS conversation_id, -- Added conversation_id by joining conversationsv2

            -- Subquery to count views for this listing
            (SELECT COUNT(*) FROM listing_views WHERE listing_id = a.listing_id) AS views,
            -- Subquery to count applicants for this listing
            (SELECT COUNT(*) FROM applicationsv2 app_count WHERE app_count.listing_id = a.listing_id) AS applicants_count
        FROM
            applicationsv2 a
        LEFT JOIN
            listingsv2 pl ON a.listing_id = pl.id AND a.listing_type = 'PUBLIC'
        LEFT JOIN
            asap_listings al ON a.listing_id = al.id AND a.listing_type = 'ASAP'
        LEFT JOIN
            users u ON COALESCE(pl.lister_id, al.lister_id) = u.id
        LEFT JOIN -- Join with conversationsv2 to get conversation_id
            conversationsv2 cv ON (
                cv.listing_id = a.listing_id AND
                cv.lister_id = COALESCE(pl.lister_id, al.lister_id) AND
                cv.doer_id = a.doer_id
            )
        WHERE
            $whereClause
        ORDER BY
            a.applied_at DESC
    ";

    $stmt = $conn->prepare($sql);

    if ($stmt === false) {
        error_log("get_doer_job_listings.php: Failed to prepare statement: " . $conn->error, 0);
        throw new Exception("Failed to prepare SQL statement.");
    }

    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    $jobs = [];
    while ($row = $result->fetch_assoc()) {
        // Convert server local timestamps to UTC for frontend
        $appliedAtUTC = null;
        $listingCreatedAtUTC = null;
        
        if ($row['applied_at']) {
            // Convert server local time to UTC
            $appliedAtUTC = gmdate('Y-m-d H:i:s', strtotime($row['applied_at']));
        }
        
        if ($row['listing_created_at']) {
            // Convert server local time to UTC
            $listingCreatedAtUTC = gmdate('Y-m-d H:i:s', strtotime($row['listing_created_at']));
        }
        
        // Format the job data to match DoerJob model expectations
        $job = [
            'id' => $row['application_id'], // Use application_id as the main ID
            'doer_id' => $doerId,
            'application_id' => $row['application_id'],
            'listing_id' => $row['listing_id'],
            'listing_type' => $row['listing_type'],
            'message' => $row['message'],
            'application_status' => $row['application_status'],
            'applied_at' => $appliedAtUTC,
            'title' => $row['listing_title'],
            'description' => $row['listing_description'],
            'price' => $row['listing_price'] !== null ? floatval($row['listing_price']) : null,
            'location_address' => $row['listing_location_address'],
            'category' => $row['listing_category'],
            'listing_created_at' => $listingCreatedAtUTC,
            'lister_id' => $row['lister_id'],
            'lister_full_name' => $row['lister_full_name'],
            'lister_profile_picture_url' => $row['lister_profile_picture_url'],
            'earned_amount' => $row['earned_amount'] !== null ? floatval($row['earned_amount']) : null,
            'transaction_no' => $row['transaction_no'],
            'cancellation_reason' => $row['cancellation_reason'],
            'views' => intval($row['views']),
            'applicants_count' => intval($row['applicants_count']),
            'is_asap' => (bool)($row['is_asap'] ?? 0),
            'conversation_id' => $row['conversation_id']
        ];
        
        $jobs[] = $job;
    }
    
    $stmt->close();

    error_log("get_doer_job_listings.php: Fetched " . count($jobs) . " jobs for doer $doerId with status filter '$statusFilter'.", 0);
    echo json_encode([
        "success" => true,
        "jobs" => $jobs,
        "count" => count($jobs)
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_doer_job_listings.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
}
?> 