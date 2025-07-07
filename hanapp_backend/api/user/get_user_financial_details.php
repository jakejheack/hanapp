<?php
// hanapp_backend/api/user/get_user_financial_details.php
// Fetches a user's balance, total profit, and verification status.
// IMPORTANT: This API now relies on user_id for authorization instead of auth tokens as per request.
// This is a security risk if user_id is not inherently authenticated.

ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

require_once '../config/db_connect.php';
// require_once '../../utils/auth_middleware.php'; // Removed as token validation is no longer desired for this endpoint

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (!isset($conn) || $conn->connect_error) {
    error_log("get_user_financial_details.php: Database connection not established: " . $conn->connect_error, 0);
    echo json_encode(["success" => false, "message" => "Database connection not established."]);
    exit();
}

$userId = $_GET['user_id'] ?? null;

if (empty($userId) || !is_numeric($userId)) {
    error_log("get_user_financial_details.php: Validation failed - User ID is missing or invalid. Received user_id: " . var_export($userId, true), 0);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit();
}

$sql = "SELECT id, role, balance, total_profit, is_verified, id_verified FROM users WHERE id = ?";
$stmt = $conn->prepare($sql);

if ($stmt === false) {
    error_log("get_user_financial_details.php: Failed to prepare statement: " . $conn->error, 0);
    echo json_encode(["success" => false, "message" => "Internal server error."]);
    exit();
}

$stmt->bind_param("i", $userId);
$stmt->execute();
$result = $stmt->get_result();

if ($data = $result->fetch_assoc()) {
    // Check if user is a doer
    if ($data['role'] !== 'doer') {
        echo json_encode(["success" => false, "message" => "Only doers can access financial details."]);
        $stmt->close();
        $conn->close();
        exit();
    }

    $data['balance'] = (double)$data['balance'];
    $data['total_profit'] = (double)$data['total_profit'];
    $data['is_verified'] = (bool)$data['is_verified'];
    $data['id_verified'] = (bool)$data['id_verified'];
    
    // Calculate if user is fully verified (both email and ID verification)
    $isFullyVerified = $data['is_verified'] && $data['id_verified'];

    $transactionHistory = []; // Placeholder for now; implement separate endpoint for full history

    echo json_encode([
        "success" => true,
        "balance" => $data['balance'],
        "total_profit" => $data['total_profit'],
        "is_verified" => $isFullyVerified,
        "email_verified" => $data['is_verified'],
        "id_verified" => $data['id_verified'],
        "transaction_history" => $transactionHistory
    ]);
} else {
    echo json_encode(["success" => false, "message" => "User financial details not found."]);
}

$stmt->close();
$conn->close();
?> 