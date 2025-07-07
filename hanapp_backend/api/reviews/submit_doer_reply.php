<?php
// hanapp_backend/api/reviews/submit_doer_reply.php
// Allows a Doer to submit a reply to a review.

// Basic error logging
error_log("submit_doer_reply.php: Script started");

// Strict error reporting for production
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ERROR | E_PARSE);

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function respond($success, $message) {
    error_log("submit_doer_reply.php: Responding - success=$success, message=$message");
    echo json_encode(['success' => $success, 'message' => $message]);
    exit();
}

try {
    error_log("submit_doer_reply.php: Starting main logic");
    
    // 1. Include database connection
    require_once '../config/db_connect.php';
    error_log("submit_doer_reply.php: Database connection included");
    
    // 2. Parse and validate input
    $input = file_get_contents("php://input");
    error_log("submit_doer_reply.php: Raw input: " . $input);
    
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        respond(false, "Invalid JSON payload.");
    }

    $reviewId = $data['review_id'] ?? null;
    $doerReplyMessage = $data['doer_reply_message'] ?? null;
    $doerId = $data['doer_id'] ?? null;

    error_log("submit_doer_reply.php: Parsed data - reviewId=$reviewId, doerId=$doerId, message=$doerReplyMessage");

    if (
        empty($reviewId) || !is_numeric($reviewId) ||
        empty($doerReplyMessage) ||
        empty($doerId) || !is_numeric($doerId)
    ) {
        respond(false, "Review ID, reply message, and Doer ID are required.");
    }

    // 3. Verify review exists and belongs to this doer
    $verifySql = "SELECT r.*, u.full_name as lister_name 
                  FROM reviews r
                  JOIN users u ON r.lister_id = u.id
                  WHERE r.id = ? LIMIT 1";
    $verifyStmt = $conn->prepare($verifySql);
    if (!$verifyStmt) {
        error_log("submit_doer_reply.php: Failed to prepare verify statement: " . $conn->error);
        throw new Exception("Failed to prepare review verification: " . $conn->error);
    }
    
    $verifyStmt->bind_param("i", $reviewId);
    $verifyStmt->execute();
    $result = $verifyStmt->get_result();
    $review = $result->fetch_assoc();
    $verifyStmt->close();

    if (!$review) respond(false, "Review not found.");
    if ($review['doer_id'] != $doerId) respond(false, "Unauthorized: You can only reply to reviews meant for you.");
    if (!empty($review['doer_reply_message'])) respond(false, "You have already replied to this review.");

    error_log("submit_doer_reply.php: Review verification passed");

    // 4. Update the review with the doer's reply
    $updateSql = "UPDATE reviews SET doer_reply_message = ?, replied_at = NOW() WHERE id = ?";
    $updateStmt = $conn->prepare($updateSql);
    if (!$updateStmt) {
        error_log("submit_doer_reply.php: Failed to prepare update statement: " . $conn->error);
        throw new Exception("Failed to prepare review update: " . $conn->error);
    }
    
    $updateStmt->bind_param("si", $doerReplyMessage, $reviewId);
    if (!$updateStmt->execute()) {
        error_log("submit_doer_reply.php: Failed to execute update: " . $updateStmt->error);
        throw new Exception("Failed to submit reply: " . $updateStmt->error);
    }
    $updateStmt->close();

    error_log("submit_doer_reply.php: Review update completed successfully");

    // 5. Send a chat message to the lister
    try {
        error_log("submit_doer_reply.php: Attempting to send chat message");
        
        // Get conversation between doer and lister
        $conversationSql = "SELECT id FROM conversationsv2 WHERE 
            (lister_id = ? AND doer_id = ?) OR (lister_id = ? AND doer_id = ?) 
            LIMIT 1";
        $conversationStmt = $conn->prepare($conversationSql);
        if ($conversationStmt) {
            $conversationStmt->bind_param("iiii", 
                $review['lister_id'], $doerId, 
                $doerId, $review['lister_id']
            );
            $conversationStmt->execute();
            $conversationResult = $conversationStmt->get_result();
            $conversation = $conversationResult->fetch_assoc();
            $conversationStmt->close();
            
            if ($conversation) {
                $conversationId = $conversation['id'];
                error_log("submit_doer_reply.php: Found conversation ID: $conversationId");
                
                // Send message
                $messageContent = "I have replied to your review. Check it out!";
                $messageType = 'text';
                
                $insertStmt = $conn->prepare("INSERT INTO messagesv2 (conversation_id, sender_id, receiver_id, content, sent_at, type, extra_data) VALUES (?, ?, ?, ?, NOW(), ?, ?)");
                if ($insertStmt) {
                    $extraData = null; // Create a variable for the null value
                    $insertStmt->bind_param("iiisss", 
                        $conversationId, 
                        $doerId,           // sender (doer)
                        $review['lister_id'], // receiver (lister)
                        $messageContent,
                        $messageType,
                        $extraData         // Use the variable instead of null directly
                    );
                    
                    if ($insertStmt->execute()) {
                        $newMessageId = $conn->insert_id;
                        error_log("submit_doer_reply.php: Chat message sent successfully. Message ID: $newMessageId");
                        
                        // Update conversation last_message_at
                        $updateConvStmt = $conn->prepare("UPDATE conversationsv2 SET last_message_at = NOW() WHERE id = ?");
                        if ($updateConvStmt) {
                            $updateConvStmt->bind_param("i", $conversationId);
                            $updateConvStmt->execute();
                            $updateConvStmt->close();
                        }
                        
                        // Create notification for the lister
                        try {
                            error_log("submit_doer_reply.php: Creating notification for lister");
                            
                            // Get sender's name
                            $senderName = '';
                            $senderStmt = $conn->prepare("SELECT full_name FROM users WHERE id = ?");
                            if ($senderStmt) {
                                $senderStmt->bind_param("i", $doerId);
                                $senderStmt->execute();
                                $senderResult = $senderStmt->get_result();
                                if ($senderRow = $senderResult->fetch_assoc()) {
                                    $senderName = $senderRow['full_name'];
                                }
                                $senderStmt->close();
                            }
                            
                            // Get receiver's role
                            $receiverRole = '';
                            $roleStmt = $conn->prepare("SELECT role FROM users WHERE id = ?");
                            if ($roleStmt) {
                                $roleStmt->bind_param("i", $review['lister_id']);
                                $roleStmt->execute();
                                $roleResult = $roleStmt->get_result();
                                if ($roleRow = $roleResult->fetch_assoc()) {
                                    $receiverRole = $roleRow['role'];
                                }
                                $roleStmt->close();
                            }
                            
                            $notificationTitle = "Review Reply";
                            $notificationContent = "$senderName replied to your review";
                            $notificationType = "review_reply";
                            
                            if ($receiverRole === 'doer') {
                                // Insert into doer_notifications table
                                $doerNotificationSql = "
                                    INSERT INTO doer_notifications (
                                        user_id, sender_id, type, title, content, associated_id,
                                        conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                                        related_listing_title, listing_id, listing_type, lister_id, lister_name, is_read
                                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                                ";
                                
                                $doerNotificationStmt = $conn->prepare($doerNotificationSql);
                                if ($doerNotificationStmt) {
                                    $listingId = null;
                                    $listingType = null;
                                    $listerId = null;
                                    $listerName = null;
                                    $relatedListingTitle = '';
                                    
                                    $doerNotificationStmt->bind_param("iisssiiissiiss",
                                        $review['lister_id'], // user_id (lister)
                                        $doerId,              // sender_id (doer)
                                        $notificationType,    // type
                                        $notificationTitle,   // title
                                        $notificationContent, // content
                                        $newMessageId,        // associated_id (message_id)
                                        $conversationId,      // conversation_id_for_chat_nav
                                        $review['lister_id'], // conversation_lister_id
                                        $doerId,              // conversation_doer_id
                                        $relatedListingTitle, // related_listing_title
                                        $listingId,           // listing_id
                                        $listingType,         // listing_type
                                        $listerId,            // lister_id
                                        $listerName           // lister_name
                                    );
                                    
                                    $doerNotificationStmt->execute();
                                    $doerNotificationStmt->close();
                                    error_log("submit_doer_reply.php: Doer notification created for review reply");
                                }
                            } else {
                                // Insert into notificationsv2 table for lister or other roles
                                $listerNotificationSql = "
                                    INSERT INTO notificationsv2 (
                                        user_id, sender_id, type, title, content, associated_id,
                                        conversation_id_for_chat_nav, conversation_lister_id, conversation_doer_id,
                                        related_listing_title, is_read
                                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                                ";
                                
                                $listerNotificationStmt = $conn->prepare($listerNotificationSql);
                                if ($listerNotificationStmt) {
                                    $relatedListingTitle = '';
                                    
                                    $listerNotificationStmt->bind_param("iisssiiiss",
                                        $review['lister_id'], // user_id (lister)
                                        $doerId,              // sender_id (doer)
                                        $notificationType,    // type
                                        $notificationTitle,   // title
                                        $notificationContent, // content
                                        $newMessageId,        // associated_id (message_id)
                                        $conversationId,      // conversation_id_for_chat_nav
                                        $review['lister_id'], // conversation_lister_id
                                        $doerId,              // conversation_doer_id
                                        $relatedListingTitle  // related_listing_title
                                    );
                                    
                                    $listerNotificationStmt->execute();
                                    $listerNotificationStmt->close();
                                    error_log("submit_doer_reply.php: Lister notification created for review reply");
                                }
                            }
                            
                        } catch (Exception $notificationError) {
                            error_log("submit_doer_reply.php: Notification error: " . $notificationError->getMessage());
                            // Don't fail the entire operation if notification fails
                            // The review reply and chat message are still successful
                        }
                        
                        $insertStmt->close();
                    } else {
                        error_log("submit_doer_reply.php: Failed to send chat message: " . $insertStmt->error);
                    }
                }
            } else {
                error_log("submit_doer_reply.php: No conversation found between doer and lister");
            }
        }
        
    } catch (Exception $messageError) {
        error_log("submit_doer_reply.php: Chat message error: " . $messageError->getMessage());
        // Don't fail the entire operation if message fails
        // The review reply is still successful
    }

    respond(true, "Reply submitted successfully!");

} catch (Exception $e) {
    error_log("submit_doer_reply.php: Exception caught: " . $e->getMessage());
    http_response_code(500);
    respond(false, "An error occurred: " . $e->getMessage());
} catch (Error $e) {
    error_log("submit_doer_reply.php: Error caught: " . $e->getMessage());
    http_response_code(500);
    respond(false, "An error occurred: " . $e->getMessage());
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}

error_log("submit_doer_reply.php: Script finished");