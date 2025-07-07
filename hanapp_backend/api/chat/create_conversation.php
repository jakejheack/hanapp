<?php
// hanapp_backend/api/chat/create_conversation.php
// Creates a new conversation or gets an existing one

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
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

try {
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("Invalid JSON payload.");
    }

    // Extract data from the payload
    $listerId = $data['lister_id'] ?? null;
    $doerId = $data['doer_id'] ?? null;
    $listingId = $data['listing_id'] ?? null;
    $listingType = $data['listing_type'] ?? null;

    // Validation
    if (empty($listerId) || !is_numeric($listerId)) {
        throw new Exception("Lister ID is required and must be numeric.");
    }
    if (empty($doerId) || !is_numeric($doerId)) {
        throw new Exception("Doer ID is required and must be numeric.");
    }
    if (empty($listingId) || !is_numeric($listingId)) {
        throw new Exception("Listing ID is required and must be numeric.");
    }
    if (empty($listingType)) {
        throw new Exception("Listing type is required.");
    }

    // Check if conversation already exists
    $checkSql = "
        SELECT id FROM conversationsv2 
        WHERE listing_id = ? AND listing_type = ? AND lister_id = ? AND doer_id = ?
    ";
    
    $checkStmt = $conn->prepare($checkSql);
    if ($checkStmt === false) {
        throw new Exception("Failed to prepare check statement: " . $conn->error);
    }

    $checkStmt->bind_param("isii", $listingId, $listingType, $listerId, $doerId);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    
    if ($checkResult->num_rows > 0) {
        // Conversation already exists, return it
        $existingConversation = $checkResult->fetch_assoc();
        $checkStmt->close();
        
        echo json_encode([
            'success' => true,
            'conversation_id' => (int)$existingConversation['id'],
            'message' => 'Existing conversation found.',
            'is_new' => false
        ]);
        return;
    }
    $checkStmt->close();

    // Create new conversation
    $insertSql = "
        INSERT INTO conversationsv2 (
            listing_id, listing_type, lister_id, doer_id, created_at, last_message_at
        ) VALUES (?, ?, ?, ?, NOW(), NOW())
    ";

    $insertStmt = $conn->prepare($insertSql);
    if ($insertStmt === false) {
        throw new Exception("Failed to prepare insert statement: " . $conn->error);
    }

    $insertStmt->bind_param("isii", $listingId, $listingType, $listerId, $doerId);

    if (!$insertStmt->execute()) {
        throw new Exception("Failed to create conversation: " . $insertStmt->error);
    }

    $conversationId = $conn->insert_id;
    $insertStmt->close();

    echo json_encode([
        'success' => true,
        'conversation_id' => $conversationId,
        'message' => 'Conversation created successfully.',
        'is_new' => true
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("create_conversation.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to create conversation: ' . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 