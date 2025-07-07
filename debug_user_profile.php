<?php
// Debug script to test what get_user_profile.php returns for your account
header('Content-Type: application/json');

// Your database connection details (replace with your actual values)
$servername = "localhost"; // or your database host
$username = "your_db_username";
$password = "your_db_password"; 
$dbname = "u688984333_hanapp_db_new";

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }
    
    // Query for your specific account
    $stmt = $conn->prepare("SELECT * FROM users WHERE email = ?");
    $email = 'izaacriverazxc@gmail.com';
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $user = $result->fetch_assoc();
        
        echo "=== RAW DATABASE DATA ===\n";
        echo json_encode($user, JSON_PRETTY_PRINT);
        
        echo "\n\n=== FIELD TYPES ===\n";
        echo "verification_status: " . gettype($user['verification_status']) . " = '" . $user['verification_status'] . "'\n";
        echo "badge_status: " . gettype($user['badge_status']) . " = '" . $user['badge_status'] . "'\n";
        echo "id_verified: " . gettype($user['id_verified']) . " = " . $user['id_verified'] . "\n";
        echo "badge_acquired: " . gettype($user['badge_acquired']) . " = " . $user['badge_acquired'] . "\n";
        echo "role: " . gettype($user['role']) . " = '" . $user['role'] . "'\n";
        echo "is_verified: " . gettype($user['is_verified']) . " = " . $user['is_verified'] . "\n";
        echo "is_available: " . gettype($user['is_available']) . " = " . $user['is_available'] . "\n";
        
    } else {
        echo "User not found!";
    }
    
    $conn->close();
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage();
}
?>
