<?php
// hanapp_backend/api/chat/get_messages.php
// Fetches messages for a specific conversation

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
    $lastMessageId = $_GET['last_message_id'] ?? 0;

    if (empty($conversationId) || !is_numeric($conversationId)) {
        throw new Exception("Conversation ID is required and must be numeric.");
    }

    $sql = "
        SELECT
            m.id,
            m.conversation_id,
            m.sender_id,
            m.receiver_id,
            m.content AS message_content,
            m.type AS message_type,
            m.sent_at AS created_at,
            m.extra_data,
            s.full_name AS sender_name,
            s.profile_picture_url AS sender_profile_picture_url,
            r.full_name AS receiver_name,
            r.profile_picture_url AS receiver_profile_picture_url
        FROM
            messagesv2 m
        LEFT JOIN
            users s ON m.sender_id = s.id
        LEFT JOIN
            users r ON m.receiver_id = r.id
        WHERE
            m.conversation_id = ? AND m.id > ?
        ORDER BY
            m.sent_at ASC
    ";

    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        throw new Exception("Failed to prepare statement: " . $conn->error);
    }

    $stmt->bind_param("ii", $conversationId, $lastMessageId);
    
    if (!$stmt->execute()) {
        throw new Exception("Failed to execute query: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $messages = [];

    while ($row = $result->fetch_assoc()) {
        // Format the timestamp properly for Flutter app
        if (!empty($row['sent_at'])) {
            $row['sent_at'] = date('Y-m-d H:i:s', strtotime($row['sent_at']));
        }
        
        // If extra_data exists and is not null, attempt to JSON decode it
        if (!empty($row['extra_data'])) {
            $decodedExtraData = json_decode($row['extra_data'], true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $row['location_data'] = $decodedExtraData; // Pass as 'location_data' to Flutter
            } else {
                error_log("get_messages.php: Failed to decode extra_data for message ID {$row['id']}: " . json_last_error_msg(), 0);
            }
        }
        unset($row['extra_data']); // Remove extra_data from raw row before sending to Flutter

        $messages[] = $row;
    }

    $stmt->close();

    echo json_encode([
        'success' => true,
        'messages' => $messages,
        'message' => 'Messages retrieved successfully.'
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_messages.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to retrieve messages: ' . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 