<?php
// hanapp_backend/api/reviews/get_review_for_job.php
// Fetches a specific review for a job between a lister and doer

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
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
    $listerId = $_GET['lister_id'] ?? null;
    $doerId = $_GET['doer_id'] ?? null;

    if (!$listerId || !$doerId) {
        throw new Exception("Both lister_id and doer_id are required.");
    }

    // Get the review with lister details and listing information
    $sql = "SELECT r.*, u.full_name as lister_full_name, u.profile_picture_url as lister_profile_picture_url,
                   a.listing_id, a.listing_type
            FROM reviews r
            JOIN users u ON r.lister_id = u.id
            JOIN applicationsv2 a ON r.application_id = a.id
            WHERE r.lister_id = ? AND r.doer_id = ?
            ORDER BY r.created_at DESC
            LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare query: " . $conn->error);
    }
    
    $stmt->bind_param("ii", $listerId, $doerId);
    $stmt->execute();
    $result = $stmt->get_result();
    $review = $result->fetch_assoc();
    $stmt->close();

    if (!$review) {
        echo json_encode([
            "success" => false,
            "message" => "No review found for this job."
        ]);
        exit();
    }

    $reviewData = [
        'id' => $review['id'],
        'listing_id' => $review['listing_id'],
        'listing_type' => $review['listing_type'],
        'lister_id' => $review['lister_id'],
        'lister_full_name' => $review['lister_full_name'],
        'lister_profile_picture_url' => $review['lister_profile_picture_url'],
        'doer_id' => $review['doer_id'],
        'rating' => (float)$review['rating'],
        'review_content' => $review['review_content'],
        'created_at' => $review['created_at'],
        'doer_reply_message' => $review['doer_reply_message'],
        'replied_at' => $review['replied_at'],
        'application_id' => $review['application_id'],
        'review_image_urls' => $review['media_urls'] ?? ''
    ];

    echo json_encode([
        "success" => true,
        "review" => $reviewData
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_review_for_job.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch review: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 