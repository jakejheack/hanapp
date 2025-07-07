# User Status Verification and Multiple Device Prevention

This implementation adds comprehensive user status verification and multiple device prevention to the HanApp application.

## Overview

The system checks user status (lister/doer) from the database and prevents multiple device usage by:

1. **User Status Verification**: Checks if the user account is active, not banned, not deleted
2. **Multiple Device Prevention**: Detects and prevents concurrent logins from different devices
3. **Automatic Verification**: Runs verification checks at app launch, login, and periodically

## Components

### Backend API (`hanapp_backend/api/check_user_status.php`)

- **Endpoint**: `POST /api/check_user_status.php`
- **Parameters**:
  - `user_id`: User ID to verify
  - `device_info`: Device information for multiple device detection
  - `action`: 'check' or 'login' (login action checks for multiple devices)

- **Checks**:
  - User exists in database
  - Account is not deleted
  - Account is not banned
  - Multiple device usage (for login action)

### Flutter Services

#### `UserStatusService` (`lib/services/user_status_service.dart`)

Main service for handling user status verification:

- `verifyUserStatus()`: Verifies user status and shows appropriate dialogs
- `verifyUserStatusWithInterval()`: Verifies with time-based interval checking
- `shouldCheckUserStatus()`: Determines if verification is needed based on time interval
- `updateLastCheckTime()`: Updates the last check timestamp

#### `AuthService` (`lib/utils/auth_service.dart`)

Added `checkUserStatus()` method to communicate with the backend API.

### Screens Updated

1. **Login Screen** (`lib/screens/auth/login_screen.dart`)
   - Verifies user status after successful login
   - Prevents navigation if status is invalid

2. **Wrapper with Verification** (`lib/screens/wrapper_with_verification.dart`)
   - New wrapper that includes user status verification
   - Used for app launch and navigation

3. **Dashboard Screens**
   - **Lister Dashboard**: Added periodic status verification
   - **Doer Dashboard**: Added periodic status verification

4. **Splash Screen**: Updated to use the new wrapper

## Error Handling

The system handles various error scenarios:

### Account Deleted
- Shows dialog: "Account has been deleted"
- Logs out user and redirects to login

### Account Banned
- Shows dialog with ban duration
- Logs out user and redirects to login

### Multiple Devices Detected
- Shows dialog: "Multiple devices detected. Please use only one device at a time"
- Offers options to logout or try again

### User Not Found
- Shows dialog: "User not found"
- Logs out user and redirects to login

### Network Errors
- Shows generic error dialog
- Allows user to retry

## Configuration

### Check Interval
The system checks user status every 5 minutes by default. This can be modified in `UserStatusService`:

```dart
static const Duration _checkInterval = Duration(minutes: 5);
```

### Multiple Device Detection Window
The backend checks for multiple device usage within the last 5 minutes:

```php
AND login_timestamp > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
```

## Usage

### Automatic Verification
The system automatically verifies user status:
- On app launch (via wrapper)
- After login
- Periodically on dashboard screens

### Manual Verification
You can manually verify user status:

```dart
final isValid = await UserStatusService.verifyUserStatus(
  context: context,
  userId: user.id!,
  action: 'check', // or 'login' for multiple device check
);
```

### Force Check
You can force a status check regardless of the time interval:

```dart
final isValid = await UserStatusService.verifyUserStatusWithInterval(
  context: context,
  userId: user.id!,
  action: 'check',
  forceCheck: true,
);
```

## Security Features

1. **Device Information Tracking**: Each login is logged with device information
2. **Time-based Detection**: Multiple device detection uses a 5-minute window
3. **Automatic Logout**: Invalid users are automatically logged out
4. **Interval-based Checking**: Reduces server load by checking periodically
5. **Comprehensive Error Handling**: Handles all possible error scenarios

## Testing

Run the tests to verify the implementation:

```bash
flutter test test/user_status_verification_test.dart
```

## API Endpoints

### Check User Status
- **URL**: `POST /api/check_user_status.php`
- **Headers**: `Content-Type: application/json`
- **Body**:
  ```json
  {
    "user_id": 123,
    "device_info": "Samsung Galaxy S21 (Android 12)",
    "action": "check"
  }
  ```

### Response Format
```json
{
  "success": true,
  "message": "User status verified successfully.",
  "user": {
    "id": 123,
    "full_name": "John Doe",
    "email": "john@example.com",
    "role": "lister",
    "is_verified": true,
    "profile_picture_url": "https://...",
    "address_details": "123 Main St",
    "latitude": 14.5995,
    "longitude": 120.9842,
    "is_available": true,
    "contact_number": "+1234567890",
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-01 00:00:00"
  },
  "timestamp": 1704067200
}
```

### Error Response Format
```json
{
  "success": false,
  "message": "Multiple devices detected. Please use only one device at a time.",
  "error_type": "multiple_devices",
  "login_count": 2
}
```

## Error Types

- `missing_user_id`: User ID not provided
- `user_not_found`: User doesn't exist in database
- `account_deleted`: User account has been deleted
- `account_banned`: User account is banned
- `multiple_devices`: Multiple devices detected
- `server_error`: Server-side error
- `network_error`: Network connectivity error

## Future Enhancements

1. **Session Management**: Implement proper session tokens
2. **Device Whitelist**: Allow users to whitelist trusted devices
3. **Push Notifications**: Notify users of suspicious login attempts
4. **Geolocation Tracking**: Track login locations for security
5. **Two-Factor Authentication**: Add 2FA for additional security 