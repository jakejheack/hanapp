<?php
// hanapp_backend/api/wallet/get_transaction_history.php
// Fetches transaction history for a given user.

// --- DEBUGGING: Temporarily enable error display for development ---
// Set to 1 for debugging, 0 for production. Set to 1 to see the exact PHP error.
ini_set('display_errors', 1); // <--- IMPORTANT: SET TO 1 FOR DEBUGGING!
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
    error_log("get_transaction_history.php: Database connection not established: " . $conn->connect_error);
    echo json_encode(["success" => false, "message" => "Database connection not established."]);
    exit();
}

try {
    $userId = $_GET['user_id'] ?? null;

    if (empty($userId) || !is_numeric($userId)) {
        echo json_encode(["success" => false, "message" => "User ID is required and must be numeric."]);
        exit(); // Exit here as validation failed before any database operation
    }

    $stmt = $conn->prepare("SELECT id, user_id, type, method, amount, status, description, transaction_date, xendit_invoice_id FROM transactions WHERE user_id = ? ORDER BY transaction_date DESC");
    if ($stmt === false) {
        // Log the exact SQL error if prepare fails
        error_log("get_transaction_history.php: Failed to prepare statement: " . $conn->error, 0);
        throw new Exception("Failed to prepare database statement.");
    }

    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    $transactions = [];
    while ($row = $result->fetch_assoc()) {
        $transactions[] = $row;
    }

    $stmt->close();

    echo json_encode([
        "success" => true,
        "transactions" => $transactions
    ]);

} catch (Exception $e) {
    http_response_code(500);
    error_log("get_transaction_history.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An error occurred: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 