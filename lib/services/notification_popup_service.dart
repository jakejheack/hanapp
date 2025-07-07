import 'package:flutter/material.dart';
import 'package:hanapp/models/notification_model.dart';
import 'package:hanapp/widgets/notification_popup.dart';
import 'package:hanapp/services/notification_service.dart';
import 'package:hanapp/utils/auth_service.dart';
import 'dart:async';

class NotificationPopupService {
  static final NotificationPopupService _instance = NotificationPopupService._internal();
  factory NotificationPopupService() => _instance;
  NotificationPopupService._internal();

  final List<NotificationModel> _recentNotifications = [];
  final int _maxRecentNotifications = 10;
  Timer? _pollingTimer;
  bool _isPolling = false;
  BuildContext? _currentContext;
  int? _lastNotificationId = 0;

  // Start polling for new notifications
  void startPolling(BuildContext context) {
    if (_isPolling) return;
    
    _currentContext = context;
    _isPolling = true;
    
    // Poll immediately
    _pollForNotifications();
    
    // Then poll every 30 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pollForNotifications();
    });
    
    print('NotificationPopupService: Started polling for notifications');
  }

  // Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _currentContext = null;
    print('NotificationPopupService: Stopped polling for notifications');
  }

  // Poll for new notifications
  Future<void> _pollForNotifications() async {
    if (_currentContext == null || !_currentContext!.mounted) {
      stopPolling();
      return;
    }

    try {
      final user = await AuthService.getUser();
      if (user == null || user.id == null) return;

      Map<String, dynamic> response;
      if (user.role == 'lister') {
        response = await NotificationService().getNotifications(userId: user.id!);
      } else {
        response = await NotificationService().getDoerNotifications(userId: user.id!);
      }

      if (response['success'] && response['notifications'] != null) {
        final List<NotificationModel> notifications = response['notifications'];
        
        // Calculate 5 minutes ago
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        
        // Find new unread notifications from the last 5 minutes
        final newNotifications = notifications.where((notification) {
          final isUnread = !notification.isRead;
          final isRecent = notification.createdAt.isAfter(fiveMinutesAgo);
          final isNew = notification.id > (_lastNotificationId ?? 0);
          
          return isUnread && isRecent && isNew;
        }).toList();

        // Show popup for each new notification
        for (final notification in newNotifications) {
          if (_currentContext != null && _currentContext!.mounted) {
            _showNotificationPopup(_currentContext!, notification);
            _lastNotificationId = notification.id;
          }
        }

        if (newNotifications.isNotEmpty) {
          print('NotificationPopupService: Found ${newNotifications.length} new notifications from last 5 minutes');
        }
      }
    } catch (e) {
      print('NotificationPopupService: Error polling for notifications: $e');
    }
  }

  // Show a popup notification manually
  void showNotification(BuildContext context, NotificationModel notification) {
    _showNotificationPopup(context, notification);
  }

  // Show a popup notification
  void _showNotificationPopup(BuildContext context, NotificationModel notification) {
    // Check if context is still valid
    if (!context.mounted) return;

    final overlay = Overlay.of(context);
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => NotificationPopup(
        notification: notification,
        onTap: () => _handleNotificationTap(context, notification),
        onDismiss: () {
          overlayEntry?.remove();
        },
        duration: const Duration(seconds: 5),
      ),
    );

    overlay.insert(overlayEntry);
  }

  // Handle notification tap
  void _handleNotificationTap(BuildContext context, NotificationModel notification) {
    // Mark notification as read
    _markNotificationAsRead(notification);
    
    // Navigate based on notification type
    _navigateToNotification(context, notification);
  }

  // Mark notification as read
  Future<void> _markNotificationAsRead(NotificationModel notification) async {
    try {
      final user = await AuthService.getUser();
      if (user == null) return;

      if (user.role == 'lister') {
        await NotificationService().markNotificationAsRead(notificationId: notification.id);
      } else {
        await NotificationService().markDoerNotificationAsRead(notificationId: notification.id);
      }
    } catch (e) {
      print('NotificationPopupService: Error marking notification as read: $e');
    }
  }

  // Navigate to appropriate screen based on notification type
  void _navigateToNotification(BuildContext context, NotificationModel notification) {
    // Remove the overlay first
    if (Overlay.of(context).mounted) {
      // Find and remove the notification overlay
      final overlay = Overlay.of(context);
      // Note: We can't directly access entries, so we'll let the notification dismiss itself
      // The notification will be removed when the user taps it
    }

    // Handle navigation based on notification type
    switch (notification.type) {
      case 'message':
      case 'message_received':
        // Navigate to chat conversation
        if (notification.conversationIdForChat != null) {
          Navigator.pushNamed(
            context, 
            '/chat_screen',
            arguments: {
              'conversationId': notification.conversationIdForChat,
              'otherUserId': notification.senderId,
              'listingTitle': notification.relatedListingTitle ?? 'Chat',
            },
          );
        } else {
          // Navigate to chat list if no specific conversation
          Navigator.pushNamed(context, '/chat_list');
        }
        break;
        
      case 'application':
      case 'application_submitted':
        // Navigate to application details
        if (notification.associatedId != null) {
          Navigator.pushNamed(
            context,
            '/application_details',
            arguments: {
              'applicationId': notification.associatedId,
              'listingTitle': notification.relatedListingTitle ?? 'Application',
            },
          );
        } else {
          // Navigate to job listings
          Navigator.pushNamed(context, '/job_listings');
        }
        break;
        
      case 'project_started':
      case 'job_started':
        // Navigate to job details or chat
        if (notification.conversationIdForChat != null) {
          Navigator.pushNamed(
            context, 
            '/chat_screen',
            arguments: {
              'conversationId': notification.conversationIdForChat,
              'otherUserId': notification.senderId,
              'listingTitle': notification.relatedListingTitle ?? 'Project',
            },
          );
        } else {
          Navigator.pushNamed(context, '/job_listings');
        }
        break;
        
      case 'job_completed':
        // Navigate to job details or chat
        if (notification.conversationIdForChat != null) {
          Navigator.pushNamed(
            context, 
            '/chat_screen',
            arguments: {
              'conversationId': notification.conversationIdForChat,
              'otherUserId': notification.senderId,
              'listingTitle': notification.relatedListingTitle ?? 'Completed Job',
            },
          );
        } else {
          Navigator.pushNamed(context, '/job_listings');
        }
        break;
        
      case 'review_received':
        // Navigate to reviews screen - we'll need to get the current user's reviews
        // For now, navigate to notifications where they can see the review notification
        Navigator.pushNamed(context, '/notifications');
        break;
        
      case 'application_accepted':
      case 'application_rejected':
        // Navigate to application details
        if (notification.associatedId != null) {
          Navigator.pushNamed(
            context,
            '/application_details',
            arguments: {
              'applicationId': notification.associatedId,
              'listingTitle': notification.relatedListingTitle ?? 'Application',
            },
          );
        } else {
          Navigator.pushNamed(context, '/job_listings');
        }
        break;
        
      default:
        // Navigate to notifications screen for unknown types
        Navigator.pushNamed(context, '/notifications');
        break;
    }
  }

  // Clear recent notifications (useful for logout)
  void clearRecentNotifications() {
    _recentNotifications.clear();
  }

  // Get recent notifications
  List<NotificationModel> get recentNotifications => List.unmodifiable(_recentNotifications);
} 