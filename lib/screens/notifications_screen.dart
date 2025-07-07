import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hanapp/models/notification.dart'; // Ensure this path is correct
import 'package:hanapp/utils/constants.dart' as Constants;
import 'package:hanapp/screens/listing_details_screen.dart';
import '../models/notification_model.dart';
import 'package:hanapp/services/notification_service.dart';
import 'package:hanapp/utils/auth_service.dart';
// Add imports for doer screens
import 'package:hanapp/screens/doer/doer_job_listings_mark_screen.dart';
import 'package:hanapp/screens/doer/application_details_screen.dart';
import 'package:hanapp/screens/lister/lister_application_details_screen.dart';
import 'package:hanapp/screens/chat_screen.dart';
import 'package:hanapp/models/doer_job.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = await AuthService.getUser();
    if (user == null || user.id == null) {
      setState(() {
        _error = 'User not logged in. Please log in to view notifications.';
        _isLoading = false;
      });
      return;
    }
    final int currentUserId = user.id!;

    print('DEBUG: Current user ID: $currentUserId');
    print('DEBUG: User role: ${user.role}');
    print('DEBUG: User details: ${user.toJson()}');

    // Check user role and use appropriate endpoint
    Map<String, dynamic> response;
    if (user.role == 'lister') {
      print('DEBUG: Using lister notifications endpoint');
      response = await NotificationService().getNotifications(userId: currentUserId);
    } else {
      print('DEBUG: Using doer notifications endpoint');
      response = await NotificationService().getDoerNotifications(userId: currentUserId);
    }

    print('DEBUG: Full response from notifications: $response');
    print('DEBUG: Response success: ${response['success']}');
    print('DEBUG: Response message: ${response['message']}');
    print('DEBUG: Notifications count: ${response['notifications']?.length ?? 0}');

    if (response['success']) {
      setState(() {
        _notifications = response['notifications'];
        _isLoading = false;
      });
      print('DEBUG: Set notifications successfully. Count: ${_notifications.length}');
    } else {
      setState(() {
        _error = response['message'] ?? 'Failed to load notifications.';
        _isLoading = false;
      });
      print('DEBUG: Failed to load notifications. Error: $_error');
    }
  }

  void _handleNotificationTap(NotificationModel notification) async {
    final user = await AuthService.getUser();
    if (user == null) return;

    // Mark notification as read based on user role
    if (!notification.isRead) {
      Map<String, dynamic> response;
      if (user.role == 'lister') {
        response = await NotificationService().markNotificationAsRead(notificationId: notification.id);
      } else {
        response = await NotificationService().markDoerNotificationAsRead(notificationId: notification.id);
      }

      if (response['success']) {
        // Update the notification in the list to mark it as read
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = _notifications[index].copyWith(isRead: true);
          }
        });
      }
    }

    // Handle navigation based on notification type and user role
    if (notification.type == 'application_submitted' && notification.listingId != null) {
      if (user.role == 'lister') {
        // Lister navigates to listing details to see the application
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ListingDetailsScreen(listingId: notification.listingId!),
          ),
        );
      } else {
        // Doer navigates to their job listings
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoerJobListingsScreenMark(),
          ),
        );
      }
    } else if (notification.type == 'message' || notification.type == 'message_received') {
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
    } else if (notification.type == 'application_accepted' ||
               notification.type == 'application_rejected' ||
               notification.type == 'job_started' ||
               notification.type == 'job_completed' ||
               notification.type == 'job_cancelled') {

      if (user.role == 'lister') {
        // Lister navigates to application details
        if (notification.associatedId != null && notification.senderId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListerApplicationDetailsScreen(
                applicationId: notification.associatedId!,
                doerId: notification.senderId!,
              ),
            ),
          );
        } else {
          // Fallback: navigate to job listings
          Navigator.pushNamed(context, '/job_listings');
        }
      } else {
        // Doer navigates to their job details
        if (notification.associatedId != null) {
          // For doers, we need to create a DoerJob object or navigate to job listings
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoerJobListingsScreenMark(),
            ),
          );
        } else {
          // Fallback: navigate to job listings
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoerJobListingsScreenMark(),
            ),
          );
        }
      }
    } else {
      // For unknown notification types, navigate to notifications screen
      Navigator.pushNamed(context, '/notifications');
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    final List<NotificationModel> todayNotifications = _notifications
        .where((n) => n.createdAt.isAfter(today))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final List<NotificationModel> thisWeekNotifications = _notifications
        .where((n) => n.createdAt.isAfter(startOfWeek) && n.createdAt.isBefore(today))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final List<NotificationModel> earlierNotifications = _notifications
        .where((n) => n.createdAt.isBefore(startOfWeek))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      body: Column( // Use Column to stack the custom header and the list view
        children: [
          // Custom Header Section
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 0, // Adjust for status bar and padding
              left: 0,
              right: 0,
              bottom: 4,
            ),
            color: Colors.white, // Background color for the header
            child: const Row( // Use const if children are const
              children: [
                Text(
                  'Notifications', // Your heading text
                  style: TextStyle(
                    fontSize: 4,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Text color for the heading
                  ),
                ),
              ],
            ),
          ),
          // End Custom Header Section

          Expanded( // Expanded to take the remaining space
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _notifications.isEmpty
                ? const Center(child: Text('No notifications yet.'))
                : ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                if (todayNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Text('Today', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  ...todayNotifications.map((notification) => _buildNotificationItem(notification)).toList(),
                ],
                if (thisWeekNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Text('This week', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  ...thisWeekNotifications.map((notification) => _buildNotificationItem(notification)).toList(),
                ],
                if (earlierNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Text('Earlier', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  ...earlierNotifications.map((notification) => _buildNotificationItem(notification)).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    IconData icon;
    Color iconColor;
    String typeLabel;

    switch (notification.type) {
      case 'application_submitted':
        icon = Icons.handshake;
        iconColor = Colors.blue.shade700;
        typeLabel = 'Application Submitted';
        break;
      case 'application_accepted':
        icon = Icons.check_circle;
        iconColor = Colors.green.shade700;
        typeLabel = 'Application Accepted';
        break;
      case 'application_rejected':
        icon = Icons.cancel;
        iconColor = Colors.red.shade700;
        typeLabel = 'Application Rejected';
        break;
      case 'job_started':
        icon = Icons.play_circle;
        iconColor = Colors.orange.shade700;
        typeLabel = 'Job Started';
        break;
      case 'job_completed':
        icon = Icons.task_alt;
        iconColor = Colors.green.shade700;
        typeLabel = 'Job Completed';
        break;
      case 'job_cancelled':
        icon = Icons.cancel_outlined;
        iconColor = Colors.red.shade700;
        typeLabel = 'Job Cancelled';
        break;
      case 'message_received':
        icon = Icons.message;
        iconColor = Colors.purple.shade700;
        typeLabel = 'New Message';
        break;
      case 'payment_received':
        icon = Icons.payment;
        iconColor = Colors.green.shade700;
        typeLabel = 'Payment Received';
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.grey.shade700;
        typeLabel = 'Notification';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      elevation: notification.isRead ? 1 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: notification.isRead ? null : Colors.blue.shade50,
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.content,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _getTimeAgo(notification.createdAt),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
