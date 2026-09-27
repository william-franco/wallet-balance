class TransactionModel {
  final int id;
  final double amount;
  final String merchant;
  final String description;
  final DateTime occurredAt;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.description,
    required this.occurredAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      merchant: json['merchant'] as String,
      description: json['description'] as String? ?? '',
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }
}
