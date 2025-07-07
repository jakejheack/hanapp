<?php
// hanapp_backend/api/utils/convert_asap_to_public.php
// Converts ASAP listings to PUBLIC listings if they haven't been accepted within 10 minutes

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../config/db_connect.php';

// This script can be run manually or via cron job
// Recommended cron job: */10 * * * * (every 10 minutes) for more precise timing

try {
    // Find ASAP listings that are older than 10 minutes and haven't been accepted
    $sql = "
        SELECT al.id, al.lister_id, al.title, al.description, al.price, 
               al.location_address, al.created_at, al.latitude, al.longitude,
               TIMESTAMPDIFF(MINUTE, al.created_at, NOW()) as minutes_old
        FROM asap_listings al
        LEFT JOIN applicationsv2 a ON al.id = a.listing_id AND a.status = 'accepted'
        WHERE al.is_active = TRUE 
        AND al.status = 'pending'
        AND al.created_at < DATE_SUB(NOW(), INTERVAL 10 MINUTE)
        AND a.id IS NULL
        ORDER BY al.created_at ASC
    ";
    
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception("Query failed: " . $conn->error);
    }
    
    $convertedCount = 0;
    $errors = [];
    $currentTime = date('Y-m-d H:i:s');
    
    error_log("ASAP conversion check started at: $currentTime");
    
    while ($asapListing = $result->fetch_assoc()) {
        $conn->begin_transaction();
        
        try {
            error_log("Processing ASAP listing ID {$asapListing['id']} - Created: {$asapListing['created_at']} - Age: {$asapListing['minutes_old']} minutes");
            
            // Insert into listingsv2 table with 'Remote' category
            $insertSql = "
                INSERT INTO listingsv2 (
                    lister_id, title, description, price, location_address, 
                    category, status, is_active, created_at, latitude, longitude
                ) VALUES (?, ?, ?, ?, ?, 'Remote', 'open', TRUE, ?, ?, ?)
            ";
            
            $insertStmt = $conn->prepare($insertSql);
            if ($insertStmt === false) {
                throw new Exception("Failed to prepare insert statement: " . $conn->error);
            }
            
            $insertStmt->bind_param("issdssdd",
                $asapListing['lister_id'],
                $asapListing['title'],
                $asapListing['description'],
                $asapListing['price'],
                $asapListing['location_address'],
                $asapListing['created_at'],
                $asapListing['latitude'],
                $asapListing['longitude']
            );
            
            if (!$insertStmt->execute()) {
                throw new Exception("Failed to insert into listingsv2: " . $insertStmt->error);
            }
            
            $newListingId = $conn->insert_id;
            $insertStmt->close();
            
            // Update any existing applications to point to the new listing
            $updateApplicationsSql = "
                UPDATE applicationsv2 
                SET listing_id = ?, listing_type = 'PUBLIC' 
                WHERE listing_id = ? AND listing_type = 'ASAP'
            ";
            
            $updateStmt = $conn->prepare($updateApplicationsSql);
            if ($updateStmt === false) {
                throw new Exception("Failed to prepare update applications statement: " . $conn->error);
            }
            
            $updateStmt->bind_param("ii", $newListingId, $asapListing['id']);
            
            if (!$updateStmt->execute()) {
                throw new Exception("Failed to update applications: " . $updateStmt->error);
            }
            
            $updateStmt->close();
            
            // Deactivate the ASAP listing
            $deactivateSql = "
                UPDATE asap_listings 
                SET is_active = FALSE, status = 'converted_to_public'
                WHERE id = ?
            ";
            
            $deactivateStmt = $conn->prepare($deactivateSql);
            if ($deactivateStmt === false) {
                throw new Exception("Failed to prepare deactivate statement: " . $conn->error);
            }
            
            $deactivateStmt->bind_param("i", $asapListing['id']);
            
            if (!$deactivateStmt->execute()) {
                throw new Exception("Failed to deactivate ASAP listing: " . $deactivateStmt->error);
            }
            
            $deactivateStmt->close();
            
            // Create notification for the lister about the conversion
            // First check if the user exists
            $checkUserSql = "SELECT id FROM users WHERE id = ?";
            $checkUserStmt = $conn->prepare($checkUserSql);
            if ($checkUserStmt === false) {
                error_log("Failed to prepare user check statement: " . $conn->error);
            } else {
                $checkUserStmt->bind_param("i", $asapListing['lister_id']);
                $checkUserStmt->execute();
                $userResult = $checkUserStmt->get_result();
                
                if ($userResult->num_rows > 0) {
                    // User exists, create notification
                    $notificationSql = "
                        INSERT INTO notificationsv2 (
                            user_id, sender_id, type, title, content, associated_id,
                            conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                            related_listing_title, is_read
                        ) VALUES (?, NULL, 'asap_converted_to_public', 'ASAP Job Converted to Public', 
                                 'Your ASAP job \"{$asapListing['title']}\" has been automatically converted to a public listing after 10 minutes without acceptance.', 
                                 ?, NULL, NULL, NULL, ?, 0)
                    ";
                    
                    $notificationStmt = $conn->prepare($notificationSql);
                    if ($notificationStmt === false) {
                        error_log("Failed to prepare notification statement: " . $conn->error);
                    } else {
                        $notificationStmt->bind_param("iis",
                            $asapListing['lister_id'],
                            $newListingId,
                            $asapListing['title']
                        );
                        
                        if (!$notificationStmt->execute()) {
                            error_log("Failed to insert notification: " . $notificationStmt->error);
                        }
                        $notificationStmt->close();
                    }
                } else {
                    error_log("User ID {$asapListing['lister_id']} does not exist, skipping notification");
                }
                $checkUserStmt->close();
            }
            
            $conn->commit();
            $convertedCount++;
            
            $conversionTime = date('Y-m-d H:i:s');
            error_log("SUCCESS: Converted ASAP listing ID {$asapListing['id']} to PUBLIC listing ID $newListingId at $conversionTime (Age: {$asapListing['minutes_old']} minutes)");
            
        } catch (Exception $e) {
            $conn->rollback();
            $errors[] = "Failed to convert ASAP listing ID {$asapListing['id']}: " . $e->getMessage();
            error_log("Error converting ASAP listing ID {$asapListing['id']}: " . $e->getMessage());
        }
    }
    
    $result->free();
    
    // Log summary
    $summary = [
        'success' => true,
        'converted_count' => $convertedCount,
        'errors' => $errors,
        'timestamp' => $currentTime
    ];
    
    error_log("ASAP to PUBLIC conversion completed at $currentTime: " . json_encode($summary));
    
    // If run via web, return JSON response
    if (isset($_SERVER['HTTP_HOST'])) {
        header('Content-Type: application/json');
        echo json_encode($summary);
    } else {
        // If run via CLI, output to console
        echo "ASAP to PUBLIC conversion completed at $currentTime:\n";
        echo "Converted: $convertedCount listings\n";
        echo "Errors: " . count($errors) . "\n";
        if (!empty($errors)) {
            echo "Error details:\n";
            foreach ($errors as $error) {
                echo "- $error\n";
            }
        }
    }
    
} catch (Exception $e) {
    $errorMsg = "ASAP to PUBLIC conversion failed: " . $e->getMessage();
    error_log($errorMsg);
    
    if (isset($_SERVER['HTTP_HOST'])) {
        header('Content-Type: application/json');
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => $errorMsg
        ]);
    } else {
        echo $errorMsg . "\n";
    }
}
?> 