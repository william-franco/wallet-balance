class CardSummaryModel {
  final double creditLimit;
  final double currentBalance;
  final double available;
  final String holderName;
  final String lastFour;
  final String brand;
  final String expiry;

  const CardSummaryModel({
    required this.creditLimit,
    required this.currentBalance,
    required this.available,
    required this.holderName,
    required this.lastFour,
    required this.brand,
    required this.expiry,
  });

  factory CardSummaryModel.fromJson(Map<String, dynamic> json) {
    return CardSummaryModel(
      creditLimit: (json['creditLimit'] as num).toDouble(),
      currentBalance: (json['currentBalance'] as num).toDouble(),
      available: (json['available'] as num).toDouble(),
      holderName: json['holderName'] as String,
      lastFour: json['lastFour'] as String,
      brand: json['brand'] as String,
      expiry: json['expiry'] as String,
    );
  }

  double get usagePercent =>
      creditLimit <= 0 ? 0 : (currentBalance / creditLimit).clamp(0, 1);
}
