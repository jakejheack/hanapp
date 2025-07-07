<?php
// hanapp_backend/api/reviews/has_review.php
// Checks if a review exists for a given application ID

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
    $applicationId = $_GET['application_id'] ?? null;

    if (!$applicationId || !is_numeric($applicationId)) {
        throw new Exception("Valid application_id is required.");
    }

    // Check if a review exists for this application
    $sql = "SELECT id FROM reviews WHERE application_id = ? LIMIT 1";
    
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare query: " . $conn->error);
    }
    
    $stmt->bind_param("i", $applicationId);
    $stmt->execute();
    $result = $stmt->get_result();
    $hasReview = $result->num_rows > 0;
    $stmt->close();

    echo json_encode([
        "success" => true,
        "has_review" => $hasReview,
        "application_id" => $applicationId
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("has_review.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "Failed to check review: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 