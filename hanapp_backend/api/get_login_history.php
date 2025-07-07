<?php
// get_login_history.php
// Returns login history for a user: date, time, location, device

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'db_connect.php';

$userId = $_POST['user_id'] ?? $_GET['user_id'] ?? null;
if (!$userId) {
    echo json_encode(['success' => false, 'message' => 'Missing user_id.']);
    exit();
}

$sql = "SELECT login_timestamp, location, device_info FROM login_history WHERE user_id = ? ORDER BY login_timestamp DESC LIMIT 20";
$stmt = $conn->prepare($sql);
if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $conn->error]);
    exit();
}
$stmt->bind_param('i', $userId);
$stmt->execute();
$result = $stmt->get_result();

$history = [];
while ($row = $result->fetch_assoc()) {
    $dt = new DateTime($row['login_timestamp'], new DateTimeZone('UTC'));
    $dt->setTimezone(new DateTimeZone('Asia/Manila')); // Change to your local timezone if needed
    $history[] = [
        'date' => $dt->format('Y-m-d'),
        'time' => $dt->format('h:i A'),
        'location' => $row['location'] ?? 'Unknown',
        'device' => $row['device_info'] ?? 'Unknown',
    ];
}
$stmt->close();
$conn->close();

if (empty($history)) {
    echo json_encode(['success' => true, 'history' => [], 'message' => 'No login history found.']);
    exit();
}

echo json_encode(['success' => true, 'history' => $history]); 