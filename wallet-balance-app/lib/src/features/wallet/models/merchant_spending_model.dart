class MerchantSpendingModel {
  final String merchant;
  final double total;

  const MerchantSpendingModel({required this.merchant, required this.total});

  factory MerchantSpendingModel.fromJson(Map<String, dynamic> json) {
    return MerchantSpendingModel(
      merchant: json['merchant'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }
}
