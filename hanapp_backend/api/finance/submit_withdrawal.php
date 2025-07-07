<?php
// hanapp_backend/api/finance/submit_withdrawal.php
// Handles the submission of a withdrawal request.

// --- DEBUGGING: Temporarily enable error display for development ---
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
// --- END DEBUGGING ---

require_once '../config/db_connect.php'; // Adjust path as needed

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (!isset($conn) || $conn->connect_error) {
    error_log("submit_withdrawal.php: Database connection not established: " . $conn->connect_error);
    echo json_encode(["success" => false, "message" => "Database connection not established."]);
    exit();
}

$input = file_get_contents("php://input");
error_log("submit_withdrawal.php: Raw input: " . $input);
$data = json_decode($input, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    error_log("submit_withdrawal.php: JSON decode error: " . json_last_error_msg());
    echo json_encode(["success" => false, "message" => "Invalid JSON payload."]);
    exit();
}

$userId = $data['user_id'] ?? null;
$amount = $data['amount'] ?? null;
$method = $data['method'] ?? null;
$accountDetails = $data['account_details'] ?? null;

error_log("submit_withdrawal.php: Received data - user_id: $userId, amount: $amount, method: $method"); // Avoid logging sensitive account details

// Basic validation
if (empty($userId) || !is_numeric($userId) || empty($amount) || !is_numeric($amount) || empty($method) || empty($accountDetails)) {
    error_log("submit_withdrawal.php: Validation failed - Missing required fields.");
    echo json_encode(["success" => false, "message" => "All fields (amount, method, account details) are required."]);
    exit();
}

$amount = (double)$amount;
$minimumAmount = 200.00; // Define your minimum withdrawal amount

// 1. Check if user exists, is a doer, and is verified
$userStmt = $conn->prepare("SELECT id, role, is_verified, id_verified, total_profit FROM users WHERE id = ?");
if ($userStmt === false) {
    error_log("submit_withdrawal.php: Failed to prepare user check statement: " . $conn->error);
    echo json_encode(["success" => false, "message" => "Internal server error during user check."]);
    exit();
}
$userStmt->bind_param("i", $userId);
$userStmt->execute();
$userResult = $userStmt->get_result();

if ($userResult->num_rows === 0) {
    error_log("submit_withdrawal.php: User $userId not found.");
    echo json_encode(["success" => false, "message" => "User not found."]);
    $userStmt->close();
    exit();
}

$user = $userResult->fetch_assoc();
$userStmt->close();

// Check if user is a doer
if ($user['role'] !== 'doer') {
    error_log("submit_withdrawal.php: User $userId is not a doer. Role: " . $user['role']);
    echo json_encode(["success" => false, "message" => "Only doers can submit withdrawal requests."]);
    exit();
}

// Check if user is fully verified (both email and ID verification)
if (!$user['is_verified']) {
    error_log("submit_withdrawal.php: User $userId email not verified.");
    echo json_encode(["success" => false, "message" => "Email verification is required before withdrawal."]);
    exit();
}

if (!$user['id_verified']) {
    error_log("submit_withdrawal.php: User $userId ID not verified.");
    echo json_encode(["success" => false, "message" => "ID verification is required before withdrawal."]);
    exit();
}

// 2. Check if amount meets minimum
if ($amount < $minimumAmount) {
    error_log("submit_withdrawal.php: Withdrawal amount $amount is less than minimum $minimumAmount for user $userId.");
    echo json_encode(["success" => false, "message" => "Minimum amount of P" . number_format($minimumAmount, 2) . " required for withdrawal."]);
    exit();
}

// 3. Check if user has sufficient profit
$userProfit = (double)$user['total_profit'];
if ($amount > $userProfit) {
    error_log("submit_withdrawal.php: Insufficient profit for user $userId. Requested: $amount, Available: $userProfit.");
    echo json_encode(["success" => false, "message" => "Insufficient balance. Your total profit is P" . number_format($userProfit, 2) . "."]);
    exit();
}

// Start a transaction for atomicity
$conn->begin_transaction();

try {
    // 4. Record the withdrawal request
    $insertStmt = $conn->prepare("INSERT INTO withdrawal_requests (user_id, amount, method, account_details, status) VALUES (?, ?, ?, ?, 'pending')");
    if ($insertStmt === false) {
        throw new Exception("Failed to prepare insert withdrawal request statement: " . $conn->error);
    }
    $insertStmt->bind_param("idss", $userId, $amount, $method, $accountDetails);
    if (!$insertStmt->execute()) {
        throw new Exception("Failed to insert withdrawal request: " . $insertStmt->error);
    }
    $insertStmt->close();

    // 5. Deduct the amount from user's total_profit
    $updateProfitStmt = $conn->prepare("UPDATE users SET total_profit = total_profit - ? WHERE id = ?");
    if ($updateProfitStmt === false) {
        throw new Exception("Failed to prepare update profit statement: " . $conn->error);
    }
    $updateProfitStmt->bind_param("di", $amount, $userId);
    if (!$updateProfitStmt->execute()) {
        throw new Exception("Failed to deduct profit: " . $updateProfitStmt->error);
    }
    $updateProfitStmt->close();

    $conn->commit();
    error_log("submit_withdrawal.php: Withdrawal request successfully submitted for user $userId, amount $amount.");
    echo json_encode(["success" => true, "message" => "Withdrawal request submitted successfully!"]);

} catch (Exception $e) {
    $conn->rollback();
    error_log("submit_withdrawal.php: Transaction failed: " . $e->getMessage());
    echo json_encode(["success" => false, "message" => "Failed to process withdrawal: " . $e->getMessage()]);
}

$conn->close();
?> 