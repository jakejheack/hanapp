<?php
// hanapp_backend/api/finance/get_withdrawal_history.php
// Fetches withdrawal request history for a user

// --- DEBUGGING: Temporarily enable error display for development ---
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
// --- END DEBUGGING ---

require_once '../db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (!isset($conn) || $conn->connect_error) {
    error_log("get_withdrawal_history.php: Database connection not established: " . $conn->connect_error);
    echo json_encode(["success" => false, "message" => "Database connection not established."]);
    exit();
}

$userId = $_GET['user_id'] ?? null;

if (empty($userId) || !is_numeric($userId)) {
    error_log("get_withdrawal_history.php: Invalid user_id: $userId");
    echo json_encode(["success" => false, "message" => "Valid user_id is required."]);
    exit();
}

// Check if user exists and is a doer
$userStmt = $conn->prepare("SELECT id, role FROM users WHERE id = ?");
if ($userStmt === false) {
    error_log("get_withdrawal_history.php: Failed to prepare user check statement: " . $conn->error);
    echo json_encode(["success" => false, "message" => "Internal server error during user check."]);
    exit();
}

$userStmt->bind_param("i", $userId);
$userStmt->execute();
$userResult = $userStmt->get_result();

if ($userResult->num_rows === 0) {
    error_log("get_withdrawal_history.php: User $userId not found.");
    echo json_encode(["success" => false, "message" => "User not found."]);
    $userStmt->close();
    exit();
}

$user = $userResult->fetch_assoc();
$userStmt->close();

// Check if user is a doer
if ($user['role'] !== 'doer') {
    error_log("get_withdrawal_history.php: User $userId is not a doer. Role: " . $user['role']);
    echo json_encode(["success" => false, "message" => "Only doers can view withdrawal history."]);
    exit();
}

// Fetch withdrawal requests for the user
$withdrawalStmt = $conn->prepare("
    SELECT 
        id,
        amount,
        method,
        status,
        admin_notes,
        request_date,
        processed_date
    FROM withdrawal_requests 
    WHERE user_id = ? 
    ORDER BY request_date DESC
    LIMIT 50
");

if ($withdrawalStmt === false) {
    error_log("get_withdrawal_history.php: Failed to prepare withdrawal history statement: " . $conn->error);
    echo json_encode(["success" => false, "message" => "Internal server error during withdrawal history fetch."]);
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
        'created_at' => $row['request_date'],
        'updated_at' => $row['processed_date'],
    ];
}

$withdrawalStmt->close();
$conn->close();

error_log("get_withdrawal_history.php: Successfully fetched " . count($withdrawals) . " withdrawal requests for user $userId");
echo json_encode([
    "success" => true,
    "withdrawals" => $withdrawals,
    "count" => count($withdrawals)
]);
?> 