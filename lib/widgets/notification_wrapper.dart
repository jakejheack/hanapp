import 'package:flutter/material.dart';
import 'package:hanapp/services/notification_popup_service.dart';

class NotificationWrapper extends StatefulWidget {
  final Widget child;
  final bool enablePolling;

  const NotificationWrapper({
    Key? key,
    required this.child,
    this.enablePolling = true,
  }) : super(key: key);

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  final NotificationPopupService _notificationService = NotificationPopupService();

  @override
  void initState() {
    super.initState();
    if (widget.enablePolling) {
      // Start polling for notifications after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationService.startPolling(context);
      });
    }
  }

  @override
  void dispose() {
    _notificationService.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 