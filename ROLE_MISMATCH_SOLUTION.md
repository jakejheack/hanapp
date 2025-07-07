# Role Mismatch Solution

## Problem Description

When users close the app temporarily and their role is changed on the server (e.g., from "lister" to "doer"), the app continues to use the cached local role. This causes issues where:

1. The app shows the wrong dashboard (lister dashboard when user is actually a doer)
2. The role switch button doesn't work because it compares against the cached role
3. Users can't access features appropriate to their actual role

## Solution Overview

The solution implements automatic role mismatch detection and resolution:

### 1. Role Mismatch Detection (`UserStatusService.checkAndUpdateRoleMismatch`)

- Compares local cached role with server role
- Automatically updates local user data when mismatch is detected
- Shows user-friendly dialog explaining the role change
- Navigates to appropriate dashboard after role update

### 2. Enhanced Role Switch Logic

- Checks for role mismatches before attempting role switch
- Updates local data if server role differs from cached role
- Ensures role switch button works even when there's a mismatch

### 3. Automatic Checking

- Dashboard screens check for role mismatches on load
- Profile settings screen checks for mismatches when opened
- User status verification includes role mismatch detection

## Implementation Details

### Backend API (`check_user_status.php`)

```php
// Returns user data including current role from server
{
  "success": true,
  "user": {
    "id": 75,
    "role": "doer", // Current role on server
    "full_name": "User Name",
    // ... other user data
  }
}
```

### Flutter Implementation

#### UserStatusService.checkAndUpdateRoleMismatch()

```dart
static Future<bool> checkAndUpdateRoleMismatch({
  required BuildContext context,
  required int userId,
  bool showUpdateDialog = true,
}) async {
  // 1. Get local user data
  final localUser = await AuthService.getUser();
  
  // 2. Check server for current user data
  final response = await AuthService.checkUserStatus(userId: userId);
  
  // 3. Compare roles
  final serverRole = response['user']['role'];
  final localRole = localUser.role;
  
  // 4. Update if mismatch detected
  if (serverRole != localRole) {
    final updatedUser = User.fromJson(response['user']);
    await AuthService.saveUser(updatedUser);
    
    if (showUpdateDialog) {
      _showRoleUpdatedDialog(context, localRole, serverRole);
    }
    
    return true; // Role was updated
  }
  
  return false; // No mismatch
}
```

#### Enhanced Role Switch Logic

```dart
Future<void> _switchRole() async {
  // 1. Check for role mismatch first
  final roleUpdated = await UserStatusService.checkAndUpdateRoleMismatch(
    context: context,
    userId: _currentUser!.id!,
    showUpdateDialog: false,
  );
  
  // 2. Reload user data if role was updated
  if (roleUpdated) {
    await _loadCurrentUser();
  }
  
  // 3. Determine new role based on current role (after potential update)
  String newRole = (_currentUser!.role == 'lister') ? 'doer' : 'lister';
  
  // 4. Update role on server
  final response = await _authService.updateRole(userId: _currentUser!.id.toString(), role: newRole);
  
  // 5. Handle success/failure
  if (response['success']) {
    await _loadCurrentUser();
    // Navigate to appropriate dashboard
  }
}
```

## User Experience

### When Role Mismatch is Detected

1. **Automatic Detection**: App detects role change when screens load
2. **User Notification**: Shows dialog explaining the role change
3. **Automatic Update**: Updates local data to match server
4. **Navigation**: Automatically navigates to correct dashboard

### Dialog Example

```
┌─────────────────────────────┐
│         Role Updated        │
│                             │
│    ℹ️                       │
│                             │
│ Your role has been updated  │
│ from LISTER to DOER on the  │
│ server.                     │
│                             │
│ The app has been updated to │
│ reflect this change.        │
│                             │
│        [Continue]           │
└─────────────────────────────┘
```

## Integration Points

### Screens with Role Mismatch Checking

1. **DashboardScreen** - Main dashboard
2. **ListerDashboardScreen** - Lister-specific dashboard
3. **DoerDashboardScreen** - Doer-specific dashboard
4. **ProfileSettingsScreen** - Profile settings with role switch

### When Checks Occur

- **Screen Load**: When any dashboard screen is opened
- **Role Switch**: Before attempting to change role
- **Profile Access**: When profile settings screen is opened
- **App Resume**: When app comes back from background

## Testing

### Unit Tests

```dart
test('should detect role mismatch between local and server', () async {
  // Mock local user with 'lister' role
  final localUser = User(role: 'lister');
  
  // Mock server response with 'doer' role
  final mockServerResponse = {
    'user': {'role': 'doer'}
  };
  
  // Should detect mismatch
  expect(localUser.role != mockServerResponse['user']['role'], isTrue);
});
```

### Manual Testing Scenarios

1. **Close app, change role on server, reopen app**
   - Expected: Role mismatch detected, user notified, app updated

2. **Try to switch role when there's a mismatch**
   - Expected: Local role updated first, then role switch proceeds

3. **Multiple role changes**
   - Expected: App always reflects current server role

## Benefits

1. **Seamless Experience**: Users don't get stuck with wrong role
2. **Automatic Resolution**: No manual intervention required
3. **Clear Communication**: Users understand what happened
4. **Consistent State**: App always matches server state
5. **Robust Role Switching**: Works even with cached data issues

## Future Enhancements

1. **Real-time Updates**: WebSocket notifications for role changes
2. **Conflict Resolution**: Handle simultaneous role changes
3. **Audit Trail**: Log role change history
4. **Admin Controls**: Allow admins to force role updates

## Troubleshooting

### Common Issues

1. **Role not updating**: Check network connectivity and API endpoint
2. **Dialog not showing**: Verify `showUpdateDialog` parameter
3. **Navigation issues**: Check route names in navigation logic

### Debug Logs

Enable debug logging to see role mismatch detection:

```dart
print('UserStatusService: Role mismatch detected! Local: $localRole, Server: $serverRole');
```

## Security Considerations

1. **Server Validation**: All role changes must be validated on server
2. **User Authentication**: Only authenticated users can change roles
3. **Audit Logging**: Log all role change attempts
4. **Rate Limiting**: Prevent rapid role switching abuse 