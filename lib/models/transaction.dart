// lib/models/transaction.dart
class Transaction {
  final int id;
  final int userId;
  final String type;
  final String? method;
  final double amount;
  final String status;
  final String? description;
  final DateTime transactionDate;
  final String? xenditInvoiceId; // NEW: Store Xendit Invoice ID

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    this.method,
    required this.amount,
    required this.status,
    this.description,
    required this.transactionDate,
    this.xenditInvoiceId, // NEW
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    try {
      if (json['transaction_date'] != null && json['transaction_date'] is String && (json['transaction_date'] as String).isNotEmpty) {
        // Parse as UTC and convert to local time
        final utcDateTime = DateTime.parse(json['transaction_date'] + 'Z'); // Add Z to treat as UTC
        parsedDate = utcDateTime.toLocal();
        print('Transaction: Parsed UTC timestamp "${json['transaction_date']}" to local time: $parsedDate');
      } else {
        parsedDate = null;
      }
    } catch (e) {
      print('Transaction: Error parsing transaction_date for transaction ${json['id']}: ${json['transaction_date']} -> $e');
      parsedDate = DateTime.now(); // Fallback
    }

    return Transaction(
      id: int.parse(json['id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      type: json['type'] as String,
      method: json['method'] as String?,
      amount: double.parse(json['amount'].toString()),
      status: json['status'] as String,
      description: json['description'] as String?,
      transactionDate: parsedDate!,
      xenditInvoiceId: json['xendit_invoice_id'] as String?, // NEW
    );
  }
}