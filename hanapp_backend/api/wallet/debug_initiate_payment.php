<?php
// Debug version of initiate_xendit_payment.php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Log all incoming data
error_log("DEBUG: Request method: " . $_SERVER['REQUEST_METHOD']);
error_log("DEBUG: Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
error_log("DEBUG: Content-Length: " . ($_SERVER['CONTENT_LENGTH'] ?? 'not set'));

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Get raw input
    $raw_input = file_get_contents("php://input");
    error_log("DEBUG: Raw input received: " . $raw_input);
    error_log("DEBUG: Raw input length: " . strlen($raw_input));
    
    // Check if input is empty
    if (empty($raw_input)) {
        error_log("DEBUG: Input is empty");
        echo json_encode([
            "success" => false,
            "message" => "No input data received",
            "debug_info" => [
                "raw_input" => $raw_input,
                "content_type" => $_SERVER['CONTENT_TYPE'] ?? 'not set',
                "content_length" => $_SERVER['CONTENT_LENGTH'] ?? 'not set'
            ]
        ]);
        exit();
    }
    
    // Try to decode JSON
    $data = json_decode($raw_input, true);
    $json_error = json_last_error();
    $json_error_msg = json_last_error_msg();
    
    error_log("DEBUG: JSON decode error code: " . $json_error);
    error_log("DEBUG: JSON decode error message: " . $json_error_msg);
    
    if ($json_error !== JSON_ERROR_NONE) {
        echo json_encode([
            "success" => false,
            "message" => "Invalid JSON payload: " . $json_error_msg,
            "debug_info" => [
                "json_error_code" => $json_error,
                "json_error_message" => $json_error_msg,
                "raw_input" => $raw_input,
                "raw_input_length" => strlen($raw_input),
                "content_type" => $_SERVER['CONTENT_TYPE'] ?? 'not set'
            ]
        ]);
        exit();
    }
    
    // Log decoded data
    error_log("DEBUG: Decoded data: " . print_r($data, true));
    
    // Check required fields
    $userId = $data['user_id'] ?? null;
    $amount = $data['amount'] ?? null;
    $paymentMethod = $data['payment_method'] ?? null;
    
    error_log("DEBUG: user_id: " . ($userId ?? 'null'));
    error_log("DEBUG: amount: " . ($amount ?? 'null'));
    error_log("DEBUG: payment_method: " . ($paymentMethod ?? 'null'));
    
    if (empty($userId) || !is_numeric($userId) || empty($amount) || !is_numeric($amount) || $amount <= 0 || empty($paymentMethod)) {
        echo json_encode([
            "success" => false,
            "message" => "User ID, positive Amount, and Payment Method are required.",
            "debug_info" => [
                "user_id" => $userId,
                "amount" => $amount,
                "payment_method" => $paymentMethod,
                "user_id_valid" => !empty($userId) && is_numeric($userId),
                "amount_valid" => !empty($amount) && is_numeric($amount) && $amount > 0,
                "payment_method_valid" => !empty($paymentMethod)
            ]
        ]);
        exit();
    }
    
    // If we get here, everything is valid
    echo json_encode([
        "success" => true,
        "message" => "JSON payload is valid",
        "data" => $data
    ]);
    
} catch (Exception $e) {
    error_log("DEBUG: Exception caught: " . $e->getMessage());
    echo json_encode([
        "success" => false,
        "message" => "Exception occurred: " . $e->getMessage(),
        "debug_info" => [
            "exception_message" => $e->getMessage(),
            "exception_file" => $e->getFile(),
            "exception_line" => $e->getLine()
        ]
    ]);
}
?> 