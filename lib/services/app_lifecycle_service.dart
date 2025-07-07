import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'package:hanapp/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AppLifecycleService {
  static const String _lastActiveTimeKey = 'last_active_time';
  static const String _wasOnlineKey = 'was_online_before_background';
  static const Duration _inactivityThreshold = Duration(minutes: 5); // Consider offline after 5 minutes of inactivity
  static const Duration _statusCheckInterval = Duration(minutes: 2); // Check status every 2 minutes
  
  static AppLifecycleService? _instance;
  static AppLifecycleService get instance => _instance ??= AppLifecycleService._();
  
  AppLifecycleService._();
  
  bool _isInitialized = false;
  bool _isOnline = false;
  User? _currentUser;
  DateTime? _lastActiveTime;
  Timer? _statusCheckTimer;
  Timer? _debounceTimer;
  bool _isUpdatingStatus = false;
  
  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _currentUser = await AuthService.getUser();
    _lastActiveTime = await _getLastActiveTime();
    _isOnline = _currentUser?.isAvailable ?? false;
    
    // For doers, set them online by default when app opens
    if (_currentUser?.role == 'doer' && !_isOnline) {
      print('AppLifecycleService: Setting doer online by default on app open');
      await _setOnlineStatus(true);
    }
    
    // Start periodic status check for doers
    if (_currentUser?.role == 'doer') {
      _startPeriodicStatusCheck();
    }
    
    _isInitialized = true;
    print('AppLifecycleService: Initialized with user: ${_currentUser?.fullName}, online: $_isOnline');
  }
  
  // Start periodic status check
  void _startPeriodicStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(_statusCheckInterval, (timer) {
      _checkAndUpdateStatus();
    });
  }
  
  // Stop periodic status check
  void _stopPeriodicStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }
  
  // Check and update status based on inactivity
  Future<void> _checkAndUpdateStatus() async {
    if (_currentUser?.role != 'doer' || !_isOnline) return;
    
    final lastActive = await _getLastActiveTime();
    if (lastActive != null) {
      final timeSinceLastActive = DateTime.now().difference(lastActive);
      if (timeSinceLastActive > _inactivityThreshold) {
        print('AppLifecycleService: User inactive for ${timeSinceLastActive.inMinutes} minutes, setting offline');
        await _setOnlineStatus(false);
      }
    }
  }
  
  // Handle app lifecycle changes
  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }
  
  // App resumed - user is actively using the app
  Future<void> _onAppResumed() async {
    print('AppLifecycleService: App resumed');
    
    // For doers, ensure they are online when app is resumed
    if (_currentUser?.role == 'doer' && !_isOnline) {
      print('AppLifecycleService: Setting doer online on app resume');
      await _setOnlineStatus(true);
    }
    
    // Check if user was offline due to inactivity
    if (_lastActiveTime != null) {
      final timeSinceLastActive = DateTime.now().difference(_lastActiveTime!);
      if (timeSinceLastActive > _inactivityThreshold) {
        print('AppLifecycleService: User was inactive for ${timeSinceLastActive.inMinutes} minutes');
        
        // If user was online before going inactive, restore their online status
        final wasOnline = await _getWasOnlineBeforeBackground();
        if (wasOnline && _currentUser?.role == 'doer') {
          await _setOnlineStatus(true);
          print('AppLifecycleService: Restored online status after inactivity');
        }
      }
    }
    
    // Update last active time
    await _updateLastActiveTime();
    _lastActiveTime = DateTime.now();
  }
  
  // App inactive - user is switching between apps or receiving calls
  Future<void> _onAppInactive() async {
    print('AppLifecycleService: App inactive');
    // Don't change status immediately for brief interruptions
  }
  
  // App paused - user has left the app (backgrounded)
  Future<void> _onAppPaused() async {
    print('AppLifecycleService: App paused');
    
    // Save current online status before going to background
    if (_currentUser?.role == 'doer') {
      await _saveWasOnlineBeforeBackground(_isOnline);
      print('AppLifecycleService: Saved online status before background: $_isOnline');
    }
    
    // Update last active time
    await _updateLastActiveTime();
    _lastActiveTime = DateTime.now();
  }
  
  // App detached - app is being terminated
  Future<void> _onAppDetached() async {
    print('AppLifecycleService: App detached');
    
    // Set user offline when app is terminated
    if (_currentUser?.role == 'doer' && _isOnline) {
      await _setOnlineStatus(false);
      print('AppLifecycleService: Set offline due to app termination');
    }
  }
  
  // App hidden - app is hidden but not terminated (Android)
  Future<void> _onAppHidden() async {
    print('AppLifecycleService: App hidden');
    
    // Similar to paused - save status and update time
    if (_currentUser?.role == 'doer') {
      await _saveWasOnlineBeforeBackground(_isOnline);
    }
    
    await _updateLastActiveTime();
    _lastActiveTime = DateTime.now();
  }
  
  // Set online/offline status
  Future<void> _setOnlineStatus(bool isOnline) async {
    if (_currentUser?.role != 'doer') return;
    
    try {
      print('AppLifecycleService: Making API call to update status to: $isOnline');
      
      final response = await AuthService().updateAvailabilityStatus(
        userId: _currentUser!.id!,
        isAvailable: isOnline,
      );
      
      if (response['success']) {
        // Update local state only after successful API call
        _isOnline = isOnline;
        print('AppLifecycleService: Successfully set online status to: $isOnline');
        // Update user's local state to match
        await _updateUserLocalState(isOnline);
      } else {
        print('AppLifecycleService: Failed to set online status: ${response['message']}');
        
        // Handle specific error types
        if (response['error_type'] == 'html_response') {
          print('AppLifecycleService: API endpoint configuration error detected');
          throw Exception('API endpoint error: Please check server configuration. Error: ${response['message']}');
        }
        
        throw Exception(response['message']);
      }
    } catch (e) {
      print('AppLifecycleService: Error setting online status: $e');
      throw e;
    }
  }
  
  // Update last active time
  Future<void> _updateLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActiveTimeKey, DateTime.now().toIso8601String());
  }
  
  // Get last active time
  Future<DateTime?> _getLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_lastActiveTimeKey);
    if (timeString != null) {
      try {
        return DateTime.parse(timeString);
      } catch (e) {
        print('AppLifecycleService: Error parsing last active time: $e');
      }
    }
    return null;
  }
  
  // Save online status before going to background
  Future<void> _saveWasOnlineBeforeBackground(bool wasOnline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wasOnlineKey, wasOnline);
  }
  
  // Get online status before going to background
  Future<bool> _getWasOnlineBeforeBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wasOnlineKey) ?? false;
  }
  
  // Manual online status toggle (for settings screen)
  Future<void> toggleOnlineStatus(bool isOnline) async {
    // Prevent rapid successive calls
    if (_isUpdatingStatus) {
      print('AppLifecycleService: Status update already in progress, ignoring request');
      return;
    }
    
    // Cancel any pending debounce
    _debounceTimer?.cancel();
    
    // Always make the API call to ensure database is updated
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      print('AppLifecycleService: Toggling status to: $isOnline (current: $_isOnline)');
      
      _isUpdatingStatus = true;
      try {
        await _setOnlineStatus(isOnline);
      } finally {
        _isUpdatingStatus = false;
      }
    });
  }
  
  // Check if status change is needed
  bool isStatusChangeNeeded(bool newStatus) {
    return _isOnline != newStatus;
  }
  
  // Get current status description
  String get statusDescription {
    if (_currentUser?.role != 'doer') return 'Not a doer';
    return _isOnline ? 'Online and available for jobs' : 'Offline and not available for jobs';
  }
  
  // Manually update activity (for testing or manual triggers)
  Future<void> updateActivity() async {
    await _updateLastActiveTime();
    _lastActiveTime = DateTime.now();
    print('AppLifecycleService: Activity updated manually');
  }
  
  // Get current online status
  bool get isOnline => _isOnline;
  
  // Set local online status (for immediate UI updates)
  void setLocalOnlineStatus(bool status) {
    _isOnline = status;
    // Also update the user's local state if available
    _updateUserLocalState(status);
  }

  // Update user's local state to match the online status
  Future<void> _updateUserLocalState(bool status) async {
    try {
      final user = await AuthService.getUser();
      if (user != null && user.role == 'doer') {
        final updatedUser = user.copyWith(isAvailable: status);
        await AuthService.saveUser(updatedUser);
        print('AppLifecycleService: Updated user local state to: $status');
      }
    } catch (e) {
      print('AppLifecycleService: Error updating user local state: $e');
    }
  }
  
  // Check if user is a doer
  bool get isDoer => _currentUser?.role == 'doer';
  
  // Get last active time for debugging
  DateTime? get lastActiveTime => _lastActiveTime;
  
  // Get inactivity threshold for debugging
  Duration get inactivityThreshold => _inactivityThreshold;
  
  // Refresh user data
  Future<void> refreshUser() async {
    _currentUser = await AuthService.getUser();
    _isOnline = _currentUser?.isAvailable ?? false;
    
    // Ensure user's local state matches the service state
    if (_currentUser?.role == 'doer') {
      await _updateUserLocalState(_isOnline);
      _startPeriodicStatusCheck();
    } else {
      _stopPeriodicStatusCheck();
    }
  }
  
  // Force refresh status from backend
  Future<void> forceRefreshStatus() async {
    if (_currentUser?.role != 'doer' || _currentUser?.id == null) return;
    
    try {
      print('AppLifecycleService: Force refreshing status from backend...');
      
      // First, get the current user data from the backend
      final userResponse = await AuthService.checkUserStatus(
        userId: _currentUser!.id!,
        action: 'check',
      );
      
      if (userResponse['success'] && userResponse['user'] != null) {
        final backendStatus = userResponse['user']['is_available'] ?? false;
        print('AppLifecycleService: Backend status: $backendStatus, Local status: $_isOnline');
        
        if (backendStatus != _isOnline) {
          _isOnline = backendStatus;
          await _updateUserLocalState(backendStatus);
          print('AppLifecycleService: Synced local status with backend: $_isOnline');
        } else {
          print('AppLifecycleService: Local status already matches backend');
        }
      } else {
        print('AppLifecycleService: Failed to get user status from backend');
      }
    } catch (e) {
      print('AppLifecycleService: Error force refreshing status: $e');
    }
  }
  
  // Clean up when user logs out
  Future<void> onLogout() async {
    // Stop periodic status check
    _stopPeriodicStatusCheck();
    
    // Set offline before logout
    if (_currentUser?.role == 'doer' && _isOnline) {
      await _setOnlineStatus(false);
    }
    
    // Clear saved data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActiveTimeKey);
    await prefs.remove(_wasOnlineKey);
    
    _currentUser = null;
    _isOnline = false;
    _lastActiveTime = null;
    _isInitialized = false;
    
    print('AppLifecycleService: Cleaned up on logout');
  }
} 