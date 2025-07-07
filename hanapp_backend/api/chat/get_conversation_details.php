<?php
// hanapp_backend/api/chat/get_conversation_details.php
// Fetches details of a specific conversation

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

require_once '../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $conversationId = $_GET['conversation_id'] ?? null;

    if (empty($conversationId) || !is_numeric($conversationId)) {
        throw new Exception("Conversation ID is required and must be numeric.");
    }

    $sql = "
        SELECT
            c.id,
            c.listing_id,
            c.listing_type,
            c.lister_id,
            c.doer_id,
            c.created_at,
            c.last_message_at,
            COALESCE(pl.title, al.title) AS listing_title,
            COALESCE(pl.description, al.description) AS listing_description,
            COALESCE(pl.price, al.price) AS listing_price,
            u_lister.full_name AS lister_name,
            u_lister.profile_picture_url AS lister_profile_picture_url,
            u_doer.full_name AS doer_name,
            u_doer.profile_picture_url AS doer_profile_picture_url,
            a.id AS application_id,
            a.status AS application_status,
            a.message AS application_message
        FROM
            conversationsv2 c
        LEFT JOIN
            listingsv2 pl ON c.listing_id = pl.id AND c.listing_type = 'PUBLIC'
        LEFT JOIN
            asap_listings al ON c.listing_id = al.id AND c.listing_type = 'ASAP'
        LEFT JOIN
            users u_lister ON c.lister_id = u_lister.id
        LEFT JOIN
            users u_doer ON c.doer_id = u_doer.id
        LEFT JOIN
            applicationsv2 a ON c.listing_id = a.listing_id 
            AND c.listing_type = a.listing_type
            AND ((c.lister_id = a.lister_id AND c.doer_id = a.doer_id) 
                 OR (c.lister_id = a.doer_id AND c.doer_id = a.lister_id))
        WHERE
            c.id = ?
    ";

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $stmt->bind_param("i", $conversationId);
    
    if (!$stmt->execute()) {
        throw new Exception("Failed to execute query: " . $stmt->error);
    }

    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception("Conversation not found.");
    }

    $conversation = $result->fetch_assoc();
    $stmt->close();

    echo json_encode([
        'success' => true,
        'details' => [
            'id' => (int)$conversation['id'],
            'listing_id' => (int)$conversation['listing_id'],
            'listing_type' => $conversation['listing_type'],
            'lister_id' => (int)$conversation['lister_id'],
            'doer_id' => (int)$conversation['doer_id'],
            'created_at' => $conversation['created_at'],
            'last_message_at' => $conversation['last_message_at'],
            'listing_title' => $conversation['listing_title'],
            'listing_description' => $conversation['listing_description'],
            'listing_price' => $conversation['listing_price'] ? (float)$conversation['listing_price'] : null,
            'lister_name' => $conversation['lister_name'],
            'lister_profile_picture_url' => $conversation['lister_profile_picture_url'],
            'doer_name' => $conversation['doer_name'],
            'doer_profile_picture_url' => $conversation['doer_profile_picture_url'],
            'application_id' => $conversation['application_id'] ? (int)$conversation['application_id'] : null,
            'application_status' => $conversation['application_status'],
            'application_message' => $conversation['application_message'],
        ],
        'message' => 'Conversation details retrieved successfully.'
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_conversation_details.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to retrieve conversation details: ' . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 