import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_balance_app/src/features/wallet/models/card_summary_model.dart';
import 'package:wallet_balance_app/src/features/wallet/widgets/legacy_credit_card_widget.dart';

void main() {
  testWidgets('legacy card smoke', (tester) async {
    const card = CardSummaryModel(
      creditLimit: 5000,
      currentBalance: 100,
      available: 4900,
      holderName: 'Test',
      lastFour: '1234',
      brand: 'Mastercard',
      expiry: '01/30',
    );
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LegacyCreditCardWidget(card: card))),
    );
    expect(find.text('Test'), findsOneWidget);
  });
}
