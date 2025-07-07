<?php
// hanapp_backend/api/applications/get_listing_applicants.php
// Returns all applicants for a specific listing

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
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
    $listingId = $_GET['listing_id'] ?? null;
    $listingType = $_GET['listing_type'] ?? null;

    // Basic validation
    if (empty($listingId) || !is_numeric($listingId)) {
        throw new Exception("Listing ID is required and must be numeric.");
    }
    if (empty($listingType)) {
        throw new Exception("Listing Type is required.");
    }

    // Get applicants for this listing
    $sql = "
        SELECT 
            a.id,
            a.listing_id,
            a.listing_type,
            a.lister_id,
            a.doer_id,
            a.listing_title,
            a.message,
            a.status,
            a.applied_at,
            a.conversation_id,
            u.full_name AS doer_full_name,
            u.profile_picture_url AS doer_profile_picture_url,
            u.email AS doer_email,
            u.phone AS doer_phone
        FROM applicationsv2 a
        LEFT JOIN users u ON a.doer_id = u.id
        WHERE a.listing_id = ? AND a.listing_type = ?
        ORDER BY a.applied_at DESC
    ";

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $stmt->bind_param("is", $listingId, $listingType);
    $stmt->execute();
    $result = $stmt->get_result();

    $applicants = [];
    while ($row = $result->fetch_assoc()) {
        // Convert applied_at to UTC ISO format
        $appliedAt = new DateTime($row['applied_at'], new DateTimeZone('Asia/Manila'));
        $appliedAtUTC = $appliedAt->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d\TH:i:s.v\Z');

        $applicant = [
            'id' => intval($row['id']),
            'listing_id' => intval($row['listing_id']),
            'listing_type' => $row['listing_type'],
            'lister_id' => intval($row['lister_id']),
            'doer_id' => intval($row['doer_id']),
            'listing_title' => $row['listing_title'],
            'message' => $row['message'],
            'status' => $row['status'],
            'applied_at' => $appliedAtUTC,
            'conversation_id' => $row['conversation_id'] ? intval($row['conversation_id']) : null,
            'doer' => [
                'id' => intval($row['doer_id']),
                'full_name' => $row['doer_full_name'],
                'profile_picture_url' => $row['doer_profile_picture_url'],
                'email' => $row['doer_email'],
                'phone' => $row['doer_phone']
            ]
        ];
        
        $applicants[] = $applicant;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "applicants" => $applicants,
        "count" => count($applicants)
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_listing_applicants.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch applicants: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 