# Backend Modifications for Social Login

## 1. Modify your existing `register.php` file

Add these modifications to your existing `register.php` file:

### Add these fields to handle social registration:

```php
// Add these lines after getting the existing POST data
$profile_picture_url = isset($_POST['profile_picture_url']) ? $_POST['profile_picture_url'] : null;
$firebase_uid = isset($_POST['firebase_uid']) ? $_POST['firebase_uid'] : null;
$auth_provider = isset($_POST['auth_provider']) ? $_POST['auth_provider'] : 'email';
$is_verified = isset($_POST['is_verified']) ? (bool)$_POST['is_verified'] : false;
$social_registration = isset($_POST['social_registration']) ? (bool)$_POST['social_registration'] : false;

// For social registrations, make some fields optional
if ($social_registration) {
    // Allow empty values for social registrations
    $birthday = !empty($_POST['birthday']) ? $_POST['birthday'] : '1990-01-01';
    $address_details = !empty($_POST['address_details']) ? $_POST['address_details'] : '';
    $gender = !empty($_POST['gender']) ? $_POST['gender'] : '';
    $contact_number = !empty($_POST['contact_number']) ? $_POST['contact_number'] : '';
}
```

### Modify your INSERT statement to include new fields:

```php
// Update your INSERT statement to include the new fields
$stmt = $pdo->prepare("
    INSERT INTO users (
        first_name, middle_name, last_name, birthday, address_details, 
        gender, contact_number, email, password, role, latitude, longitude,
        profile_picture_url, firebase_uid, auth_provider, is_verified,
        created_at, updated_at
    ) VALUES (
        :first_name, :middle_name, :last_name, :birthday, :address_details,
        :gender, :contact_number, :email, :password, :role, :latitude, :longitude,
        :profile_picture_url, :firebase_uid, :auth_provider, :is_verified,
        NOW(), NOW()
    )
");

// Add the new parameters to your execute array
$stmt->execute([
    ':first_name' => $first_name,
    ':middle_name' => $middle_name,
    ':last_name' => $last_name,
    ':birthday' => $birthday,
    ':address_details' => $address_details,
    ':gender' => $gender,
    ':contact_number' => $contact_number,
    ':email' => $email,
    ':password' => $hashed_password,
    ':role' => $role,
    ':latitude' => $latitude,
    ':longitude' => $longitude,
    ':profile_picture_url' => $profile_picture_url,
    ':firebase_uid' => $firebase_uid,
    ':auth_provider' => $auth_provider,
    ':is_verified' => $is_verified ? 1 : 0
]);
```

## 2. Modify your existing `login.php` file

Add these modifications to your existing `login.php` file:

### Add social login handling:

```php
// Add this after getting email and password from POST
$social_login = isset($_POST['social_login']) ? (bool)$_POST['social_login'] : false;
$firebase_uid = isset($_POST['firebase_uid']) ? $_POST['firebase_uid'] : null;

// Modify your user lookup query
if ($social_login && $firebase_uid) {
    // For social login, look up by email AND firebase_uid
    $stmt = $pdo->prepare("
        SELECT * FROM users 
        WHERE email = :email AND firebase_uid = :firebase_uid 
        LIMIT 1
    ");
    $stmt->execute([
        ':email' => $email,
        ':firebase_uid' => $firebase_uid
    ]);
} else {
    // Regular email/password login
    $stmt = $pdo->prepare("SELECT * FROM users WHERE email = :email LIMIT 1");
    $stmt->execute([':email' => $email]);
}

$user = $stmt->fetch(PDO::FETCH_ASSOC);

if ($user) {
    if ($social_login) {
        // For social login, verify firebase_uid matches
        if ($user['firebase_uid'] === $firebase_uid) {
            // Social login successful
            // Update last_login
            $update_stmt = $pdo->prepare("UPDATE users SET last_login = NOW() WHERE id = :user_id");
            $update_stmt->execute([':user_id' => $user['id']]);
            
            // Return success response with user data
            echo json_encode([
                'success' => true,
                'message' => 'Social login successful',
                'user' => formatUserData($user)
            ]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Invalid social login credentials']);
        }
    } else {
        // Regular password verification for email/password login
        if (password_verify($password, $user['password'])) {
            // Regular login successful
            // ... your existing login success code
        } else {
            echo json_encode(['success' => false, 'message' => 'Invalid password']);
        }
    }
} else {
    echo json_encode(['success' => false, 'message' => 'User not found']);
}
```

## 3. Database Schema Updates

Run this SQL in your Hostinger phpMyAdmin to add the required columns:

```sql
-- Add columns for social login support
ALTER TABLE users ADD COLUMN firebase_uid VARCHAR(255) NULL UNIQUE AFTER id;
ALTER TABLE users ADD COLUMN auth_provider VARCHAR(50) DEFAULT 'email' AFTER password;
ALTER TABLE users ADD COLUMN profile_picture_url TEXT NULL AFTER email;
ALTER TABLE users ADD COLUMN last_login TIMESTAMP NULL AFTER updated_at;

-- Create indexes for better performance
CREATE INDEX idx_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_auth_provider ON users(auth_provider);
```

## 4. Testing

After making these changes:

1. Test Facebook login in your app
2. Check that new users are created in the database
3. Test that existing users can log in again
4. Verify that users can proceed to role selection

The beauty of this approach is that you're using your existing, tested endpoints instead of creating new ones!
