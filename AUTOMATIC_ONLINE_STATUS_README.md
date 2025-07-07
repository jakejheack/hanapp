# Automatic Online/Offline Status Management

## Overview

The HANAPP now includes automatic online/offline status management for Doers. This feature ensures that Doers' availability status is automatically updated based on their app usage and activity.

## Features

### Automatic Status Management
- **App Lifecycle Detection**: Automatically detects when the app is in foreground, background, or terminated
- **Inactivity Detection**: Sets Doers offline after 5 minutes of inactivity
- **Status Restoration**: Restores online status when Doers return to the app after brief interruptions
- **Periodic Checks**: Performs status checks every 2 minutes to ensure accuracy

### Manual Control
- **Settings Toggle**: Doers can still manually toggle their online/offline status in the Profile Settings screen
- **Real-time Updates**: Status changes are immediately reflected in the UI and backend

### Smart Behavior
- **Background Handling**: Saves current status before app goes to background
- **Termination Handling**: Sets Doers offline when app is terminated
- **Login/Logout Integration**: Properly manages status during authentication events

## Technical Implementation

### AppLifecycleService
Located in `lib/services/app_lifecycle_service.dart`

**Key Methods:**
- `initialize()`: Sets up the service and starts periodic checks
- `handleAppLifecycleState()`: Handles app lifecycle changes
- `toggleOnlineStatus()`: Manual status toggle
- `updateActivity()`: Manual activity update for testing

**Configuration:**
- Inactivity threshold: 5 minutes
- Status check interval: 2 minutes
- Automatic cleanup on logout

### Integration Points

1. **Main App** (`lib/main.dart`):
   - Initializes the service on app startup
   - Registers for app lifecycle changes
   - Handles lifecycle state changes

2. **Profile Settings** (`lib/screens/profile_settings_screen.dart`):
   - Integrates with the service for manual status toggle
   - Shows debug information in debug mode

3. **AuthService** (`lib/utils/auth_service.dart`):
   - Cleans up lifecycle service on logout
   - Preserves availability status during authentication

## Usage

### For Doers
1. **Automatic**: Status is managed automatically based on app usage
2. **Manual**: Use the "Active Status" toggle in Profile Settings
3. **Debug**: In debug mode, tap the "Debug: Lifecycle Status" tile to manually update activity

### For Developers
1. **Testing**: Use the debug tile in Profile Settings to test activity updates
2. **Configuration**: Modify thresholds in `AppLifecycleService` constants
3. **Monitoring**: Check console logs for service activity

## Debug Features

In debug mode, Doers will see an additional tile in Profile Settings showing:
- Current online status
- Last active time
- Inactivity threshold
- Manual activity update button

## Logging

The service provides detailed logging for debugging:
- Service initialization
- App lifecycle changes
- Status updates
- Error handling
- Cleanup operations

## Error Handling

- Network errors during status updates are logged but don't crash the app
- Invalid user states are handled gracefully
- Service continues to function even if backend calls fail

## Future Enhancements

- Configurable inactivity thresholds
- Push notifications for status changes
- Analytics for user activity patterns
- Integration with notification preferences 