<?php
// hanapp_backend/api/reviews/submit_review.php
// Handles submission of a review for a doer after a project is completed.

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (!isset($conn) || $conn->connect_error) {
    error_log("submit_review.php: Database connection not established: " . ($conn->connect_error ?? 'Unknown error'), 0);
    echo json_encode(["success" => false, "message" => "Database connection not established."]);
    exit();
}

$input = file_get_contents("php://input");
error_log('submit_review.php: Raw input: ' . $input); // Log raw input before decoding
$data = json_decode($input, true);
error_log('submit_review.php: Decoded data: ' . print_r($data, true)); // Log decoded data

$applicationId = $data['application_id'] ?? null;
$listerId = $data['lister_id'] ?? null;
$doerId = $data['doer_id'] ?? null;
$rating = $data['rating'] ?? null;
$reviewContent = $data['review_content'] ?? null;
$images = $data['images'] ?? [];
$saveToFavorites = $data['save_to_favorites'] ?? false;
$shareToMyday = $data['share_to_myday'] ?? false;
$mydayCaption = $data['myday_caption'] ?? $reviewContent;
// $mediaUrls = $data['media_urls'] ?? []; // If you handle media URLs from Flutter

// Basic validation
if (empty($applicationId) || !is_numeric($applicationId) ||
    empty($listerId) || !is_numeric($listerId) ||
    empty($doerId) || !is_numeric($doerId) ||
    empty($rating) || !is_numeric($rating) || $rating < 0 || $rating > 5) {
    error_log("submit_review.php: Validation failed - Missing or invalid required fields. Data: " . json_encode($data), 0);
    echo json_encode(["success" => false, "message" => "Application ID, Lister ID, Doer ID, and a valid rating (0-5) are required."]);
    exit();
}

$conn->begin_transaction();

try {
    // Debug: Log the input data
    error_log("submit_review.php: Input data - applicationId: $applicationId, listerId: $listerId, doerId: $doerId, rating: $rating", 0);
    
    // First, let's check if the application exists at all
    $checkAppExistsSql = "SELECT id FROM applicationsv2 WHERE id = ?";
    $checkAppExistsStmt = $conn->prepare($checkAppExistsSql);
    if ($checkAppExistsStmt === false) {
        throw new Exception("Failed to prepare application existence check: " . $conn->error);
    }
    $checkAppExistsStmt->bind_param("i", $applicationId);
    $checkAppExistsStmt->execute();
    $checkAppExistsResult = $checkAppExistsStmt->get_result();
    error_log("submit_review.php: Application exists check - rows: " . $checkAppExistsResult->num_rows, 0);
    $checkAppExistsStmt->close();
    
    if ($checkAppExistsResult->num_rows === 0) {
        throw new Exception("Application ID $applicationId does not exist in applicationsv2 table.");
    }
    
    // Get application and listing details for notification
    $getApplicationSql = "SELECT a.*, l.title as listing_title, a.listing_type 
                          FROM applicationsv2 a 
                          JOIN listingsv2 l ON a.listing_id = l.id 
                          WHERE a.id = ?";
    $getApplicationStmt = $conn->prepare($getApplicationSql);
    if ($getApplicationStmt === false) {
        throw new Exception("Failed to prepare application query: " . $conn->error);
    }
    $getApplicationStmt->bind_param("i", $applicationId);
    $getApplicationStmt->execute();
    $applicationResult = $getApplicationStmt->get_result();
    $application = $applicationResult->fetch_assoc();
    $getApplicationStmt->close();

    // Debug: Log the query result
    error_log("submit_review.php: Application query result - rows: " . $applicationResult->num_rows, 0);
    if ($application) {
        error_log("submit_review.php: Application found - ID: " . $application['id'] . ", Title: " . $application['listing_title'], 0);
    } else {
        error_log("submit_review.php: Application not found for ID: $applicationId - this might be due to missing listing or join issue", 0);
    }

    if (!$application) {
        throw new Exception("Application not found. This might be due to missing listing or join issue.");
    }

    // Get lister details for notification
    $getListerSql = "SELECT full_name FROM users WHERE id = ?";
    $getListerStmt = $conn->prepare($getListerSql);
    if ($getListerStmt === false) {
        throw new Exception("Failed to prepare lister query: " . $conn->error);
    }
    $getListerStmt->bind_param("i", $listerId);
    $getListerStmt->execute();
    $listerResult = $getListerStmt->get_result();
    $lister = $listerResult->fetch_assoc();
    $getListerStmt->close();

    if (!$lister) {
        throw new Exception("Lister not found.");
    }

    $listerName = $lister['full_name'];
    $listingTitle = $application['listing_title'];
    $listingType = $application['listing_type'];
    $listingId = $application['listing_id'];

    // Optional: Check if a review already exists for this application to prevent duplicates
    $checkStmt = $conn->prepare("SELECT id FROM reviews WHERE application_id = ?");
    if ($checkStmt === false) {
        throw new Exception("Failed to prepare check statement: " . $conn->error);
    }
    $checkStmt->bind_param("i", $applicationId);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    if ($checkResult->num_rows > 0) {
        throw new Exception("A review for this application already exists.");
    }
    $checkStmt->close();

    // Insert review into reviews table
    $insertSql = "INSERT INTO reviews (application_id, lister_id, doer_id, rating, review_content, listing_type, doer_reply_message, created_at) VALUES (?, ?, ?, ?, ?, ?, '', NOW())";
    $insertStmt = $conn->prepare($insertSql);
    if ($insertStmt === false) {
        throw new Exception("Failed to prepare insert statement: " . $conn->error);
    }
    $insertStmt->bind_param("iiidss", $applicationId, $listerId, $doerId, $rating, $reviewContent, $listingType);

    if (!$insertStmt->execute()) {
        throw new Exception("Failed to submit review: " . $insertStmt->error);
    }
    $reviewId = $conn->insert_id;
    $insertStmt->close();

    // Save images to disk and insert into review_images table
    if (!empty($images) && is_array($images)) {
        $uploadDir = __DIR__ . '/../../uploads/review_images/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0777, true);
        }
        foreach ($images as $idx => $base64) {
            if (preg_match('/^data:image\/(\w+);base64,/', $base64, $typeMatch)) {
                $base64 = substr($base64, strpos($base64, ',') + 1);
                $type = strtolower($typeMatch[1]); // jpg, png, gif
            } else {
                $type = 'jpg'; // fallback
            }
            $base64 = str_replace(' ', '+', $base64);
            $imageData = base64_decode($base64);
            if ($imageData === false) continue;
            $filename = 'review_' . $reviewId . '_' . uniqid() . '.' . $type;
            $filePath = $uploadDir . $filename;
            file_put_contents($filePath, $imageData);
            // Save relative path to DB
            $relativePath = 'uploads/review_images/' . $filename;
            $imgStmt = $conn->prepare("INSERT INTO review_images (review_id, image_url) VALUES (?, ?)");
            if ($imgStmt) {
                $imgStmt->bind_param("is", $reviewId, $relativePath);
                $imgStmt->execute();
                $imgStmt->close();
            }
        }
    }

    // Save to favorites if requested
    if ($saveToFavorites) {
        $favStmt = $conn->prepare("INSERT IGNORE INTO favorites (user_id, favorite_user_id) VALUES (?, ?)");
        if ($favStmt) {
            $favStmt->bind_param("ii", $listerId, $doerId);
            $favStmt->execute();
            $favStmt->close();
        }
    }

    // Share to Myday if requested
    if ($shareToMyday) {
        // Get all image paths for this review
        $imgResult = $conn->query("SELECT image_url FROM review_images WHERE review_id = $reviewId");
        $imgPaths = [];
        while ($row = $imgResult->fetch_assoc()) {
            $imgPaths[] = $row['image_url'];
        }
        $imgJson = json_encode($imgPaths);
        $mydayStmt = $conn->prepare("INSERT INTO myday_posts (user_id, review_id, caption, images) VALUES (?, ?, ?, ?)");
        if ($mydayStmt) {
            $mydayStmt->bind_param("iiss", $listerId, $reviewId, $mydayCaption, $imgJson);
            $mydayStmt->execute();
            $mydayStmt->close();
        }
    }

    // Update the average rating for the Doer (optional, but good practice)
    // You might also have a separate `doer_ratings` table or directly update `users` table
    $updateDoerRatingSql = "UPDATE users SET average_rating = (SELECT AVG(rating) FROM reviews WHERE doer_id = ?), total_reviews = (SELECT COUNT(id) FROM reviews WHERE doer_id = ?) WHERE id = ?";
    $updateRatingStmt = $conn->prepare($updateDoerRatingSql);
    if ($updateRatingStmt === false) {
        throw new Exception("Failed to prepare doer rating update statement: " . $conn->error);
    }
    $updateRatingStmt->bind_param("iii", $doerId, $doerId, $doerId);
    $updateRatingStmt->execute();
    $updateRatingStmt->close();

    // Create notification for the doer
    $doerNotificationType = 'review_received';
    $doerNotificationTitle = 'New Review Received!';
    $doerNotificationContent = "$listerName left you a " . number_format($rating, 1) . "-star review for \"$listingTitle\".";
    
    // Insert into doer_notifications table
    $doerNotificationSql = "INSERT INTO doer_notifications 
                            (user_id, sender_id, type, title, content, associated_id, 
                             conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                             related_listing_title, created_at) 
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";
    
    $doerNotificationStmt = $conn->prepare($doerNotificationSql);
    if ($doerNotificationStmt === false) {
        error_log("submit_review.php: Failed to prepare doer notification statement: " . $conn->error, 0);
        // Don't throw exception here as the review was successful
    } else {
        // For doer notifications, we don't have a conversation_id, so we'll use 0
        $conversationId = 0;
        
        $doerNotificationStmt->bind_param("iisssiiiss", 
            $doerId,             // user_id (doer - receives notification)
            $listerId,           // sender_id (lister - sent the review)
            $doerNotificationType,   // type
            $doerNotificationTitle,  // title
            $doerNotificationContent, // content
            $applicationId,      // associated_id
            $conversationId,     // conversation_id_for_chat_nav
            $listerId,           // conversation_lister_id
            $doerId,             // conversation_doer_id
            $listingTitle        // related_listing_title
        );
        
        if (!$doerNotificationStmt->execute()) {
            error_log("submit_review.php: Failed to insert doer notification: " . $doerNotificationStmt->error, 0);
            // Don't throw exception here as the review was successful
        } else {
            error_log("submit_review.php: Doer notification inserted successfully for doer $doerId", 0);
        }
        $doerNotificationStmt->close();
    }

    // Create notification for the lister (review submitted)
    $listerNotificationType = 'review_submitted';
    $listerNotificationTitle = 'Review Submitted';
    $listerNotificationContent = "You have successfully submitted a " . number_format($rating, 1) . "-star review for \"$listingTitle\".";
    
    // Insert into notificationsv2 table for lister
    $listerNotificationSql = "INSERT INTO notificationsv2 
                              (user_id, sender_id, type, title, content, associated_id, 
                               conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                               related_listing_title, created_at) 
                              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";
    
    $listerNotificationStmt = $conn->prepare($listerNotificationSql);
    if ($listerNotificationStmt === false) {
        error_log("submit_review.php: Failed to prepare lister notification statement: " . $conn->error, 0);
        // Don't throw exception here as the review was successful
    } else {
        // For lister notifications, we don't have a conversation_id, so we'll use 0
        $conversationId = 0;
        
        $listerNotificationStmt->bind_param("iisssiiiss", 
            $listerId,           // user_id (lister - receives notification)
            $listerId,           // sender_id (lister - submitted the review)
            $listerNotificationType,   // type
            $listerNotificationTitle,  // title
            $listerNotificationContent, // content
            $applicationId,      // associated_id
            $conversationId,     // conversation_id_for_chat_nav
            $listerId,           // conversation_lister_id
            $doerId,             // conversation_doer_id
            $listingTitle        // related_listing_title
        );
        
        if (!$listerNotificationStmt->execute()) {
            error_log("submit_review.php: Failed to insert lister notification: " . $listerNotificationStmt->error, 0);
            // Don't throw exception here as the review was successful
        } else {
            error_log("submit_review.php: Lister notification inserted successfully for lister $listerId", 0);
        }
        $listerNotificationStmt->close();
    }

    $conn->commit();
    echo json_encode(["success" => true, "message" => "Review submitted successfully!"]);

} catch (Exception $e) {
    // Fix for PHP version compatibility - check if in_transaction property exists
    if (method_exists($conn, 'in_transaction') && $conn->in_transaction) {
        $conn->rollback();
    } elseif (property_exists($conn, 'in_transaction') && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("submit_review.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode(["success" => false, "message" => "An error occurred: " . $e->getMessage()]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
} 