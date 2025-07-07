<?php
// hanapp_backend/api/finance/get_withdrawal_history_test.php
// Test version that bypasses role check

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/db_connect.php';

if (!isset($conn) || $conn->connect_error) {
    echo json_encode([
        "success" => false, 
        "message" => "Database connection failed: " . ($conn->connect_error ?? 'Unknown error')
    ]);
    exit();
}

$userId = $_GET['user_id'] ?? null;

if (empty($userId) || !is_numeric($userId)) {
    echo json_encode([
        "success" => false, 
        "message" => "Valid user_id is required. Received: " . ($userId ?? 'null')
    ]);
    exit();
}

// Check if user exists (but don't check role)
$userCheck = $conn->prepare("SELECT id, role FROM users WHERE id = ?");
if (!$userCheck) {
    echo json_encode([
        "success" => false, 
        "message" => "Failed to prepare user check: " . $conn->error
    ]);
    exit();
}

$userCheck->bind_param("i", $userId);
$userCheck->execute();
$userResult = $userCheck->get_result();

if ($userResult->num_rows === 0) {
    echo json_encode([
        "success" => false, 
        "message" => "User not found with ID: $userId"
    ]);
    $userCheck->close();
    exit();
}

$user = $userResult->fetch_assoc();
$userCheck->close();

// TEMPORARILY SKIP ROLE CHECK FOR TESTING
// if ($user['role'] !== 'doer') {
//     echo json_encode([
//         "success" => false, 
//         "message" => "Only doers can view withdrawal history. User role: " . $user['role']
//     ]);
//     exit();
// }

// Check if withdrawal_requests table exists
$tableCheck = $conn->query("SHOW TABLES LIKE 'withdrawal_requests'");
if ($tableCheck->num_rows === 0) {
    echo json_encode([
        "success" => false, 
        "message" => "withdrawal_requests table does not exist"
    ]);
    exit();
}

// Fetch withdrawal requests
$withdrawalQuery = "
    SELECT 
        id,
        amount,
        method,
        status,
        admin_notes,
        processed_at,
        created_at,
        updated_at
    FROM withdrawal_requests 
    WHERE user_id = ? 
    ORDER BY created_at DESC
    LIMIT 50
";

$withdrawalStmt = $conn->prepare($withdrawalQuery);
if (!$withdrawalStmt) {
    echo json_encode([
        "success" => false, 
        "message" => "Failed to prepare withdrawal query: " . $conn->error
    ]);
    exit();
}

$withdrawalStmt->bind_param("i", $userId);
$withdrawalStmt->execute();
$withdrawalResult = $withdrawalStmt->get_result();

$withdrawals = [];
while ($row = $withdrawalResult->fetch_assoc()) {
    $withdrawals[] = [
        'id' => $row['id'],
        'amount' => (float)$row['amount'],
        'method' => $row['method'],
        'status' => $row['status'],
        'admin_notes' => $row['admin_notes'],
        'processed_at' => $row['processed_at'],
        'created_at' => $row['created_at'],
        'updated_at' => $row['updated_at'],
    ];
}

$withdrawalStmt->close();
$conn->close();

echo json_encode([
    "success" => true,
    "withdrawals" => $withdrawals,
    "count" => count($withdrawals),
    "debug" => [
        "user_id" => $userId,
        "user_role" => $user['role'],
        "table_exists" => true,
        "note" => "Role check bypassed for testing"
    ]
]);
?> 