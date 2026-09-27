class InvoiceModel {
  final int id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime dueDate;
  final double totalAmount;
  final String status;

  const InvoiceModel({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.totalAmount,
    required this.status,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as int,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      status: json['status'] as String,
    );
  }
}
