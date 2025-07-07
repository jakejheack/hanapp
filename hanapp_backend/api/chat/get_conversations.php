<?php
// hanapp_backend/api/chat/get_conversations.php
// Fetches all conversations for a given user, including details of the other participant,
// the listing, and the last message in each conversation.

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
    $userId = $_GET['user_id'] ?? null;

    if (empty($userId) || !is_numeric($userId)) {
        error_log("get_conversations.php: Validation failed - User ID is missing or invalid. Received user_id: " . var_export($userId, true), 0);
        throw new Exception("User ID is required to fetch conversations.");
    }

    $conversations = [];

    // Subquery to get the last message for each conversation from messagesv2
    $last_message_subquery = "
        SELECT
            m.conversation_id,
            m.content, -- Use correct column name
            m.sent_at -- Use correct column name
        FROM
            messagesv2 m
        INNER JOIN (
            SELECT
                conversation_id,
                MAX(sent_at) AS max_sent_at -- Use correct column name
            FROM
                messagesv2
            GROUP BY
                conversation_id
        ) AS latest_msg ON m.conversation_id = latest_msg.conversation_id AND m.sent_at = latest_msg.max_sent_at
        GROUP BY
            m.conversation_id, m.content, m.sent_at
    ";

    $sql = "
        SELECT
            c.id AS conversation_id,
            c.listing_id,
            c.listing_type,
            c.lister_id,
            c.doer_id,
            COALESCE(pl.title, al.title) AS listing_title, -- Handle both listing types
            u_other.id AS other_user_id,
            u_other.full_name AS other_user_name,
            u_other.profile_picture_url AS other_user_profile_picture_url,
            u_other.address_details AS other_user_address_details,
            lm.content AS last_message_content, -- Use correct column name
            lm.sent_at AS last_message_timestamp -- Use correct column name
        FROM
            conversationsv2 c
        LEFT JOIN
            listingsv2 pl ON c.listing_id = pl.id AND c.listing_type = 'PUBLIC' -- Only join public listings
        LEFT JOIN
            asap_listings al ON c.listing_id = al.id AND c.listing_type = 'ASAP' -- Join ASAP listings
        LEFT JOIN
            users u_other ON
            (c.lister_id = ? AND u_other.id = c.doer_id) OR (c.doer_id = ? AND u_other.id = c.lister_id)
        LEFT JOIN
            ($last_message_subquery) AS lm ON c.id = lm.conversation_id
        WHERE
            c.lister_id = ? OR c.doer_id = ?
        ORDER BY
            lm.sent_at DESC, c.created_at DESC
    ";

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        error_log("get_conversations.php: Failed to prepare statement: " . $conn->error, 0);
        throw new Exception("Database query preparation failed: " . $conn->error);
    }
    $stmt->bind_param("iiii", $userId, $userId, $userId, $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    while ($row = $result->fetch_assoc()) {
        $row['last_message_timestamp'] = $row['last_message_timestamp'] ? date('Y-m-d H:i:s', strtotime($row['last_message_timestamp'])) : null;
        $conversations[] = $row;
    }
    $stmt->close();

    echo json_encode([
        "success" => true,
        "conversations" => $conversations
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_conversations.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An internal server error occurred. Please check server logs for PHP errors. (Error: " . $e->getMessage() . ")"
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 