<?php
// hanapp_backend/api/wallet/initiate_xendit_payment.php
// Initiates a real Xendit payment by creating an Invoice.
// Wallet balance and transaction status will be updated via Xendit webhooks.

ini_set('display_errors', 0); // Keep this at 0 for production
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

// FIXED: Correct path to db_connect.php
require_once '../../config/db_connect.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log("initiate_xendit_payment.php: JSON decode error: " . json_last_error_msg() . ". Raw input: " . $input, 0);
        throw new Exception("Invalid JSON payload.");
    }

    $userId = $data['user_id'] ?? null;
    $amount = $data['amount'] ?? null;
    $paymentMethod = $data['payment_method'] ?? null; // 'gcash', 'paymaya', 'card', 'bank_transfer'
    $userEmail = $data['user_email'] ?? null;
    $userFullName = $data['user_full_name'] ?? null;
    $contactNumber = $data['contact_number'] ?? null; // NEW: Get contact number from Flutter

    if (empty($userId) || !is_numeric($userId) || empty($amount) || !is_numeric($amount) || $amount <= 0 || empty($paymentMethod)) {
        echo json_encode(["success" => false, "message" => "User ID, positive Amount, and Payment Method are required."]);
        exit();
    }

    // --- Xendit Configuration ---
    $xendit_secret_key = 'xnd_production_k5NqlGpmZlTPGEvBlYrk7a9ukwr8b2DzfQtEh3YThOcZazymwOlXwFT5ZEHIZm2'; // REPLACE WITH YOUR ACTUAL SECRET KEY
    $xendit_base_url = 'https://api.xendit.co';
    $invoice_api_url = $xendit_base_url . '/v2/invoices';

    // IMPORTANT: Replace with your actual app's success and failure redirect URLs
    $success_redirect_url = 'https://yourdomain.com/hanapp_success';
    $failure_redirect_url = 'https://yourdomain.com/hanapp_failure';

    // Map internal payment method names to Xendit payment channel codes
    $payment_method_mapping = [
        'gcash' => 'GCASH',
        'paymaya' => 'PH_PAYMAYA',
        'card' => 'CREDIT_CARD',
        'bank_transfer' => 'BANK_TRANSFER',
    ];

    if (!isset($payment_method_mapping[$paymentMethod])) {
        echo json_encode(["success" => false, "message" => "Invalid payment method specified."]);
        exit();
    }

    $xendit_payment_channel = $payment_method_mapping[$paymentMethod];
    $external_id = 'hanapp-cashin-' . $userId . '-' . uniqid();

    $customer_details = [
        'given_names' => $userFullName ?? "HanApp User",
        'email' => $userEmail ?? "hanappuser@example.com",
    ];

    // Conditionally add mobile_number for e-wallets
    if (in_array($paymentMethod, ['gcash', 'paymaya']) && !empty($contactNumber)) {
        $customer_details['mobile_number'] = $contactNumber;
    }

    $invoice_payload = [
        'external_id' => $external_id,
        'amount' => floatval($amount),
        'currency' => 'PHP',
        'description' => "HanApp Cash In for user $userId via " . ucfirst($paymentMethod),
        'payer_email' => $userEmail ?? "hanappuser@example.com", // This might be used by Xendit for notifications
        'customer' => $customer_details, // Use the dynamically built customer details
        'items' => [
            [
                'name' => 'Cash In',
                'quantity' => 1,
                'price' => floatval($amount)
            ]
        ],
        'payment_methods' => [$xendit_payment_channel],
        'success_redirect_url' => $success_redirect_url,
        'failure_redirect_url' => $failure_redirect_url,
    ];

    // --- Initiate Xendit Invoice Creation via cURL ---
    $ch = curl_init($invoice_api_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($invoice_payload));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Basic ' . base64_encode($xendit_secret_key . ':')
    ]);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);

    $xendit_response = curl_exec($ch);
    $http_status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    curl_close($ch);

    $xendit_data = json_decode($xendit_response, true);

    if ($http_status >= 200 && $http_status < 300 && isset($xendit_data['invoice_url'])) {
        $conn->begin_transaction();

        $transaction_type = 'cash_in';
        $transaction_status = 'pending';
        $transaction_description = "Cash In initiation via " . ucfirst($paymentMethod) . (isset($contactNumber) ? " (Mobile: $contactNumber)" : "");

        $stmt_transaction = $conn->prepare("
            INSERT INTO transactions (user_id, type, method, amount, status, description, transaction_date, xendit_invoice_id)
            VALUES (?, ?, ?, ?, ?, ?, NOW(), ?)
        ");
        if ($stmt_transaction === false) {
            throw new Exception("Failed to prepare pending transaction statement: " . $conn->error);
        }
        $stmt_transaction->bind_param("issdsss",
            $userId, $transaction_type, $paymentMethod, floatval($amount), $transaction_status, $transaction_description, $xendit_data['id']
        );
        if (!$stmt_transaction->execute()) {
            throw new Exception("Failed to record pending transaction: " . $stmt_transaction->error);
        }
        $stmt_transaction->close();

        $conn->commit();

        echo json_encode([
            "success" => true,
            "message" => "Xendit invoice created successfully. Redirecting for payment...",
            "redirect_url" => $xendit_data['invoice_url'],
            "xendit_invoice_id" => $xendit_data['id']
        ]);
    } else {
        $error_message = "Xendit API error (HTTP $http_status).";
        if ($curl_error) { $error_message .= " cURL Error: $curl_error."; }
        if (isset($xendit_data['message'])) { $error_message .= " Xendit Message: " . $xendit_data['message']; }
        else if (isset($xendit_data['error_code'])) { $error_message .= " Xendit Error Code: " . $xendit_data['error_code']; }
        else if ($xendit_response) { $error_message .= " Raw Xendit Response: " . $xendit_response; }

        error_log("initiate_xendit_payment.php: Xendit call failed: " . $error_message, 0);
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Failed to initiate payment with Xendit. Please try again. (Details: " . $error_message . ")"
        ]);
    }

} catch (Exception $e) {
    if (isset($conn) && $conn instanceof mysqli && $conn->in_transaction) {
        $conn->rollback();
    }
    http_response_code(500);
    error_log("initiate_xendit_payment.php: Caught exception: " . $e->getMessage(), 0);
    echo json_encode([
        "success" => false,
        "message" => "An internal error occurred during payment initiation: " . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn instanceof mysqli && $conn->ping()) {
        $conn->close();
    }
}
?> 