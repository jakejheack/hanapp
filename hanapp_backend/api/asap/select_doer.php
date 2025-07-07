<?php
// hanapp_backend/api/asap/select_doer.php
// Select a doer for an ASAP listing and create application

// Enable error reporting for debugging
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    error_log("select_doer.php: Starting doer selection process");
    
    require_once '../config/db_connect.php';
    error_log("select_doer.php: Database connection established");
    
    $rawInput = file_get_contents('php://input');
    error_log("select_doer.php: Raw input: " . $rawInput);
    
    $input = json_decode($rawInput, true);
    error_log("select_doer.php: Parsed input: " . print_r($input, true));
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $listingId = $input['listing_id'] ?? null;
    $doerId = $input['doer_id'] ?? null;
    $listerId = $input['lister_id'] ?? null;
    
    error_log("select_doer.php: Parameters - listing_id: $listingId, doer_id: $doerId, lister_id: $listerId");
    
    if (!$listingId || !$doerId || !$listerId) {
        throw new Exception('Missing required parameters: listing_id, doer_id, lister_id');
    }
    
    // Start transaction
    $conn->begin_transaction();
    error_log("select_doer.php: Transaction started");
    
    try {
        // Check if the ASAP listing exists and is in pending status
        $listingQuery = "SELECT * FROM asap_listings WHERE id = ? AND lister_id = ? AND status = 'pending'";
        error_log("select_doer.php: Checking listing with query: $listingQuery");
        error_log("select_doer.php: Parameters - listing_id: $listingId, lister_id: $listerId");
        
        $listingStmt = $conn->prepare($listingQuery);
        if (!$listingStmt) {
            throw new Exception("Failed to prepare listing query: " . $conn->error);
        }
        
        $listingStmt->bind_param('ii', $listingId, $listerId);
        $listingStmt->execute();
        $listingResult = $listingStmt->get_result();
        
        error_log("select_doer.php: Listing query executed, found " . $listingResult->num_rows . " rows");
        
        if ($listingResult->num_rows === 0) {
            // Let's check what the actual status is
            $checkStatusQuery = "SELECT id, title, lister_id, status FROM asap_listings WHERE id = ?";
            $checkStmt = $conn->prepare($checkStatusQuery);
            $checkStmt->bind_param('i', $listingId);
            $checkStmt->execute();
            $checkResult = $checkStmt->get_result();
            
            if ($checkResult->num_rows > 0) {
                $checkListing = $checkResult->fetch_assoc();
                error_log("select_doer.php: Listing exists but wrong status - ID: {$checkListing['id']}, Lister ID: {$checkListing['lister_id']}, Status: {$checkListing['status']}");
                throw new Exception("ASAP listing found but status is '{$checkListing['status']}', expected 'pending'");
            } else {
                error_log("select_doer.php: No listing found with ID: $listingId");
                throw new Exception('ASAP listing not found');
            }
        }
        
        $listing = $listingResult->fetch_assoc();
        error_log("select_doer.php: Found listing: " . print_r($listing, true));
        
        // Check if doer is available
        $doerQuery = "SELECT * FROM users WHERE id = ? AND role = 'doer' AND is_available = 1";
        error_log("select_doer.php: Checking doer with query: $doerQuery");
        
        $doerStmt = $conn->prepare($doerQuery);
        if (!$doerStmt) {
            throw new Exception("Failed to prepare doer query: " . $conn->error);
        }
        
        $doerStmt->bind_param('i', $doerId);
        $doerStmt->execute();
        $doerResult = $doerStmt->get_result();
        
        error_log("select_doer.php: Doer query executed, found " . $doerResult->num_rows . " rows");
        
        if ($doerResult->num_rows === 0) {
            throw new Exception('Doer not found or not available');
        }
        
        $doer = $doerResult->fetch_assoc();
        error_log("select_doer.php: Found doer: " . print_r($doer, true));
        
        // Check if doer has already applied to this listing
        $existingApplicationQuery = "SELECT id FROM applicationsv2 WHERE listing_id = ? AND doer_id = ? AND listing_type = 'ASAP'";
        error_log("select_doer.php: Checking existing application with query: $existingApplicationQuery");
        
        $existingStmt = $conn->prepare($existingApplicationQuery);
        if (!$existingStmt) {
            throw new Exception("Failed to prepare existing application query: " . $conn->error);
        }
        
        $existingStmt->bind_param('ii', $listingId, $doerId);
        $existingStmt->execute();
        $existingResult = $existingStmt->get_result();
        
        error_log("select_doer.php: Existing application query executed, found " . $existingResult->num_rows . " rows");
        
        if ($existingResult->num_rows > 0) {
            throw new Exception('Doer has already applied to this listing');
        }
        
        // Create application
        $applicationQuery = "INSERT INTO applicationsv2 (listing_id, listing_type, lister_id, doer_id, message, status, applied_at) VALUES (?, 'ASAP', ?, ?, 'ASAP listing selected by lister', 'accepted', NOW())";
        error_log("select_doer.php: Creating application with query: $applicationQuery");
        
        $applicationStmt = $conn->prepare($applicationQuery);
        if (!$applicationStmt) {
            throw new Exception("Failed to prepare application query: " . $conn->error);
        }
        
        $applicationStmt->bind_param('iii', $listingId, $listerId, $doerId);
        $applicationStmt->execute();
        
        $applicationId = $conn->insert_id;
        error_log("select_doer.php: Application created with ID: $applicationId");
        
        // Update ASAP listing status to 'matched'
        $updateListingQuery = "UPDATE asap_listings SET status = 'matched', updated_at = NOW() WHERE id = ?";
        error_log("select_doer.php: Updating listing status with query: $updateListingQuery");
        
        $updateListingStmt = $conn->prepare($updateListingQuery);
        if (!$updateListingStmt) {
            throw new Exception("Failed to prepare update listing query: " . $conn->error);
        }
        
        $updateListingStmt->bind_param('i', $listingId);
        $updateListingStmt->execute();
        error_log("select_doer.php: Listing status updated to 'matched'");
        
        // Create conversation
        $conversationQuery = "INSERT INTO conversationsv2 (listing_id, listing_type, lister_id, doer_id, created_at, last_message_at) VALUES (?, 'ASAP', ?, ?, NOW(), NOW())";
        error_log("select_doer.php: Creating conversation with query: $conversationQuery");
        
        $conversationStmt = $conn->prepare($conversationQuery);
        if (!$conversationStmt) {
            throw new Exception("Failed to prepare conversation query: " . $conn->error);
        }
        
        $conversationStmt->bind_param('iii', $listingId, $listerId, $doerId);
        $conversationStmt->execute();
        
        $conversationId = $conn->insert_id;
        error_log("select_doer.php: Conversation created with ID: $conversationId");
        
        // Create notification for doer
        $notificationQuery = "INSERT INTO notificationsv2 (user_id, sender_id, type, title, content, associated_id, conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id, related_listing_title, is_read) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        error_log("select_doer.php: Creating notification with query: $notificationQuery");
        
        $notificationType = 'asap_selected';
        $notificationTitle = 'ASAP Task Selected';
        $notificationContent = "You have been selected for the ASAP task: " . $listing['title'];
        $isRead = 0;
        
        $notificationStmt = $conn->prepare($notificationQuery);
        if (!$notificationStmt) {
            throw new Exception("Failed to prepare notification query: " . $conn->error);
        }
        
        $notificationStmt->bind_param('iisssiiissi', $doerId, $listerId, $notificationType, $notificationTitle, $notificationContent, $applicationId, $conversationId, $listerId, $doerId, $listing['title'], $isRead);
        $notificationStmt->execute();
        error_log("select_doer.php: Notification created successfully");
        
        // Commit transaction
        $conn->commit();
        error_log("select_doer.php: Transaction committed successfully");
        
        $response = [
            'success' => true,
            'message' => 'Doer selected successfully',
            'application_id' => $applicationId,
            'conversation_id' => $conversationId,
            'doer' => [
                'id' => $doer['id'],
                'full_name' => $doer['full_name'],
                'profile_picture_url' => $doer['profile_picture_url'],
                'average_rating' => $doer['average_rating'],
                'review_count' => $doer['review_count'],
            ],
            'listing' => [
                'id' => $listing['id'],
                'title' => $listing['title'],
                'price' => $listing['price'],
                'location_address' => $listing['location_address'],
            ]
        ];
        
        error_log("select_doer.php: Sending success response: " . json_encode($response));
        echo json_encode($response);
        
    } catch (Exception $e) {
        // Rollback transaction on error
        $conn->rollback();
        error_log("select_doer.php: Transaction rolled back due to error: " . $e->getMessage());
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("select_doer.php error: " . $e->getMessage());
    error_log("select_doer.php error trace: " . $e->getTraceAsString());
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

if (isset($conn)) {
    $conn->close();
}
?> 