<?php
// log_login_history.php
// Function to log user login history - can be included in any login script

function logLoginHistory($conn, $user_id, $location = null, $device_info = null, $ip_address = null) {
    try {
        // If location is not provided, try to get it from IP
        if ($location === null) {
            $ip = $ip_address ?? $_SERVER['REMOTE_ADDR'] ?? '';
            if (!empty($ip)) {
                $geo = @json_decode(file_get_contents("http://ip-api.com/json/$ip"));
                if ($geo && $geo->status === 'success') {
                    $location = $geo->city . ', ' . $geo->country;
                } else {
                    $location = 'Unknown';
                }
            } else {
                $location = 'Unknown';
            }
        }
        
        // If device info is not provided, get it from user agent
        if ($device_info === null) {
            $device_info = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
        }
        
        // If IP address is not provided, get it from server
        if ($ip_address === null) {
            $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';
        }
        
        // Insert into login_history table
        $stmt = $conn->prepare("INSERT INTO login_history (user_id, login_timestamp, location, device_info, ip_address) VALUES (?, NOW(), ?, ?, ?)");
        if ($stmt) {
            $stmt->bind_param("isss", $user_id, $location, $device_info, $ip_address);
            $insert_result = $stmt->execute();
            
            if ($insert_result) {
                error_log("log_login_history.php: Login history inserted successfully for user ID: $user_id");
                return true;
            } else {
                error_log("log_login_history.php: Login history insert failed for user ID: $user_id. Error: " . $stmt->error);
                return false;
            }
            $stmt->close();
        } else {
            error_log("log_login_history.php: Failed to prepare login history statement. Error: " . $conn->error);
            return false;
        }
    } catch (Exception $e) {
        error_log("log_login_history.php: Exception during login history insert: " . $e->getMessage());
        return false;
    }
}

// Alternative function for PDO connections
function logLoginHistoryPDO($pdo, $user_id, $location = null, $device_info = null, $ip_address = null) {
    try {
        // If location is not provided, try to get it from IP
        if ($location === null) {
            $ip = $ip_address ?? $_SERVER['REMOTE_ADDR'] ?? '';
            if (!empty($ip)) {
                $geo = @json_decode(file_get_contents("http://ip-api.com/json/$ip"));
                if ($geo && $geo->status === 'success') {
                    $location = $geo->city . ', ' . $geo->country;
                } else {
                    $location = 'Unknown';
                }
            } else {
                $location = 'Unknown';
            }
        }
        
        // If device info is not provided, get it from user agent
        if ($device_info === null) {
            $device_info = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
        }
        
        // If IP address is not provided, get it from server
        if ($ip_address === null) {
            $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';
        }
        
        // Insert into login_history table using PDO
        $stmt = $pdo->prepare("INSERT INTO login_history (user_id, login_timestamp, location, device_info, ip_address) VALUES (?, NOW(), ?, ?, ?)");
        if ($stmt) {
            $insert_result = $stmt->execute([$user_id, $location, $device_info, $ip_address]);
            
            if ($insert_result) {
                error_log("log_login_history.php: Login history inserted successfully for user ID: $user_id (PDO)");
                return true;
            } else {
                error_log("log_login_history.php: Login history insert failed for user ID: $user_id (PDO)");
                return false;
            }
        } else {
            error_log("log_login_history.php: Failed to prepare login history statement (PDO)");
            return false;
        }
    } catch (Exception $e) {
        error_log("log_login_history.php: Exception during login history insert (PDO): " . $e->getMessage());
        return false;
    }
}

// Handle direct API calls from Flutter app
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['user_id'])) {
    require_once 'db_connect.php';
    
    header('Content-Type: application/json');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit();
    }
    
    try {
        $input = file_get_contents("php://input");
        $data = json_decode($input, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            echo json_encode(['success' => false, 'message' => 'Invalid JSON payload']);
            exit();
        }
        
        $userId = $data['user_id'] ?? null;
        $deviceInfo = $data['device_info'] ?? null;
        
        if (!$userId) {
            echo json_encode(['success' => false, 'message' => 'Missing user_id']);
            exit();
        }
        
        // Log the login history with device information from Flutter
        $result = logLoginHistory($conn, $userId, null, $deviceInfo, null);
        
        if ($result) {
            echo json_encode([
                'success' => true,
                'message' => 'Login history logged successfully',
                'device_info' => $deviceInfo
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'message' => 'Failed to log login history'
            ]);
        }
        
    } catch (Exception $e) {
        error_log("log_login_history.php API: Error: " . $e->getMessage());
        echo json_encode([
            'success' => false,
            'message' => 'An error occurred: ' . $e->getMessage()
        ]);
    } finally {
        if (isset($conn)) {
            $conn->close();
        }
    }
}
?> 