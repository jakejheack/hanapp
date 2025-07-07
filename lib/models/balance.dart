class Balance {
  final double amount;

  Balance({required this.amount});

  factory Balance.fromJson(Map<String, dynamic> json) {
    return Balance(
      amount: double.parse(json['amount'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
    };
  }
}