<?php
// hanapp_backend/api/asap/convert_to_public.php
// Convert ASAP listing to public listing when no doers accept

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../config/db_connect.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $listingId = $input['listing_id'] ?? null;
    $listerId = $input['lister_id'] ?? null;
    
    if (!$listingId || !$listerId) {
        throw new Exception('Missing required parameters: listing_id, lister_id');
    }
    
    // Start transaction
    $conn->begin_transaction();
    
    try {
        // Get the ASAP listing details
        $listingQuery = "SELECT * FROM asap_listings WHERE id = ? AND lister_id = ? AND status = 'pending'";
        $listingStmt = $conn->prepare($listingQuery);
        $listingStmt->bind_param('ii', $listingId, $listerId);
        $listingStmt->execute();
        $listingResult = $listingStmt->get_result();
        
        if ($listingResult->num_rows === 0) {
            throw new Exception('ASAP listing not found or not in pending status');
        }
        
        $listing = $listingResult->fetch_assoc();
        
        // Check if any doers have applied
        $applicationsQuery = "SELECT COUNT(*) as count FROM applicationsv2 WHERE listing_id = ? AND listing_type = 'ASAP'";
        $applicationsStmt = $conn->prepare($applicationsQuery);
        $applicationsStmt->bind_param('i', $listingId);
        $applicationsStmt->execute();
        $applicationsResult = $applicationsStmt->get_result();
        $applicationsCount = $applicationsResult->fetch_assoc()['count'];
        
        if ($applicationsCount > 0) {
            throw new Exception('Cannot convert to public: doers have already applied');
        }
        
        // Insert into listingsv2 table (no listing_type column)
        $insertPublicQuery = "INSERT INTO listingsv2 (
            lister_id, title, description, price, latitude, longitude, location_address, 
            category, preferred_doer_gender, pictures_urls, payment_method, status, is_active, 
            created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', 1, NOW(), NOW())";
        
        $insertPublicStmt = $conn->prepare($insertPublicQuery);
        // Always set category to 'Onsite' when converting
        $category = 'Onsite';
        $insertPublicStmt->bind_param(
            'issddssssss',
            $listing['lister_id'],
            $listing['title'],
            $listing['description'],
            $listing['price'],
            $listing['latitude'],
            $listing['longitude'],
            $listing['location_address'],
            $category, // Always 'Onsite'
            $listing['preferred_doer_gender'],
            $listing['pictures_urls'],
            $listing['payment_method']
        );
        $insertPublicStmt->execute();
        
        $newPublicListingId = $conn->insert_id;
        
        // Update ASAP listing status to 'converted'
        $updateAsapQuery = "UPDATE asap_listings SET status = 'converted', updated_at = NOW() WHERE id = ?";
        $updateAsapStmt = $conn->prepare($updateAsapQuery);
        $updateAsapStmt->bind_param('i', $listingId);
        $updateAsapStmt->execute();
        
        // Create notification for lister (no listing_id column)
        $notificationQuery = "INSERT INTO notificationsv2 (
            user_id, sender_id, type, title, content, associated_id, created_at
        ) VALUES (?, ?, 'asap_converted', 'ASAP Listing Converted', ?, ?, NOW())";
        
        $notificationTitle = "Your ASAP listing '{$listing['title']}' has been converted to a public listing";
        $notificationStmt = $conn->prepare($notificationQuery);
        $notificationStmt->bind_param('iisi', $listerId, $listerId, $notificationTitle, $newPublicListingId);
        $notificationStmt->execute();
        
        // Commit transaction
        $conn->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'ASAP listing converted to public successfully',
            'new_public_listing_id' => $newPublicListingId,
            'original_asap_listing_id' => $listingId,
            'listing' => [
                'title' => $listing['title'],
                'price' => $listing['price'],
                'location_address' => $listing['location_address'],
            ]
        ]);
        
    } catch (Exception $e) {
        // Rollback transaction on error
        $conn->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("convert_to_public.php error: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?> 