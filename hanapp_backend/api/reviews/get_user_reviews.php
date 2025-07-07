<?php
// hanapp_backend/api/reviews/get_user_reviews.php
// Fetches all reviews for a specific user (can be used for both listers and doers)

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
    $userId = $_GET['user_id'] ?? null;

    if (!$userId) {
        throw new Exception("User ID is required.");
    }

    // Get reviews where the user is the doer (received reviews)
    $sql = "SELECT r.*, u.full_name as lister_full_name, u.profile_picture_url as lister_profile_picture_url
            FROM reviews r
            JOIN users u ON r.lister_id = u.id
            WHERE r.doer_id = ? AND r.rating > 0
            ORDER BY r.reviewed_at DESC";
    
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare query: " . $conn->error);
    }
    
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $reviews = [];
    while ($row = $result->fetch_assoc()) {
        $reviews[] = [
            'id' => $row['id'],
            'listing_id' => $row['listing_id'],
            'listing_type' => $row['listing_type'],
            'lister_id' => $row['lister_id'],
            'lister_full_name' => $row['lister_full_name'],
            'lister_profile_picture_url' => $row['lister_profile_picture_url'],
            'doer_id' => $row['doer_id'],
            'rating' => (float)$row['rating'],
            'review_content' => $row['review_message'],
            'created_at' => $row['reviewed_at'],
            'doer_reply_message' => $row['doer_reply_message'],
            'replied_at' => $row['replied_at'],
            'application_id' => $row['application_id'],
            'review_image_urls' => $row['review_image_urls'] ?? ''
        ];
    }
    $stmt->close();

    // Calculate average rating and total reviews
    $avgSql = "SELECT AVG(rating) as average_rating, COUNT(*) as total_reviews 
               FROM reviews 
               WHERE doer_id = ? AND rating > 0";
    $avgStmt = $conn->prepare($avgSql);
    if ($avgStmt === false) {
        throw new Exception("Failed to prepare average query: " . $conn->error);
    }
    
    $avgStmt->bind_param("i", $userId);
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
    error_log("get_user_reviews.php: Caught exception: " . $e->getMessage(), 0);
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