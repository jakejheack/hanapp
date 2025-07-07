<?php
// hanapp_backend/api/reviews/get_lister_reviews.php
// Fetches all reviews given by a lister (where the user is the lister_id)

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

    if (!$listerId) {
        throw new Exception("Lister ID is required.");
    }

    // Get reviews where the user is the lister (reviews they gave)
    $sql = "SELECT r.*, u.full_name as doer_full_name, u.profile_picture_url as doer_profile_picture_url,
                   a.listing_title, a.listing_id
            FROM reviews r
            JOIN users u ON r.doer_id = u.id
            LEFT JOIN applicationsv2 a ON r.application_id = a.id
            WHERE r.lister_id = ? AND r.rating > 0
            ORDER BY r.created_at DESC";
    
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare query: " . $conn->error);
    }
    
    $stmt->bind_param("i", $listerId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $reviews = [];
    while ($row = $result->fetch_assoc()) {
        $reviews[] = [
            'id' => $row['id'],
            'listing_id' => $row['listing_id'] ?? 0,
            'application_id' => $row['application_id'],
            'listing_type' => $row['listing_type'],
            'lister_id' => $row['lister_id'],
            'doer_id' => $row['doer_id'],
            'doer_full_name' => $row['doer_full_name'],
            'doer_profile_picture_url' => $row['doer_profile_picture_url'],
            'rating' => (float)$row['rating'],
            'review_content' => $row['review_content'],
            'created_at' => $row['created_at'],
            'doer_reply_message' => $row['doer_reply_message'],
            'replied_at' => $row['replied_at'],
            'review_image_urls' => $row['media_urls'] ?? '',
            'project_title' => $row['listing_title'] ?? 'Project #' . $row['application_id']
        ];
    }
    $stmt->close();

    // Calculate average rating and total reviews given
    $avgSql = "SELECT AVG(rating) as average_rating, COUNT(*) as total_reviews 
               FROM reviews 
               WHERE lister_id = ? AND rating > 0";
    $avgStmt = $conn->prepare($avgSql);
    if ($avgStmt === false) {
        throw new Exception("Failed to prepare average query: " . $conn->error);
    }
    
    $avgStmt->bind_param("i", $listerId);
    $avgStmt->execute();
    $avgResult = $avgStmt->get_result();
    $avgData = $avgResult->fetch_assoc();
    $avgStmt->close();

    $averageRating = $avgData['average_rating'] ? (float)$avgData['average_rating'] : 0.0;
    $totalReviews = (int)$avgData['total_reviews'];

    echo json_encode([
        "success" => true,
        "reviews" => $reviews,
        "average_rating" => $averageRating,
        "total_reviews" => $totalReviews
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_lister_reviews.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch reviews: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 