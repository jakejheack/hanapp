// lib/models/withdrawal_request.dart
import 'package:flutter/material.dart';

class WithdrawalRequest {
  final int id;
  final double amount;
  final String method;
  final String status;
  final String? adminNotes;
  final DateTime requestDate;
  final DateTime? processedDate;

  WithdrawalRequest({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    this.adminNotes,
    required this.requestDate,
    this.processedDate,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      try {
        return DateTime.parse(dateString).toLocal();
      } catch (e) {
        print('Error parsing date: $dateString -> $e');
        return null;
      }
    }

    return WithdrawalRequest(
      id: int.parse(json['id'].toString()),
      amount: double.parse(json['amount'].toString()),
      method: json['method'] as String,
      status: json['status'] as String,
      adminNotes: json['admin_notes'] as String?,
      requestDate: parseDateTime(json['request_date']) ?? DateTime.now(),
      processedDate: parseDateTime(json['processed_date']),
    );
  }

  String getStatusDisplayText() {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Color getStatusColor() {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(requestDate);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
} 