import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet_balance_app/src/features/wallet/models/card_summary_model.dart';

class ModernCreditCardWidget extends StatelessWidget {
  final CardSummaryModel card;

  const ModernCreditCardWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final percent = card.usagePercent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF5C6BC0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.brand,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.2,
                  ),
                ),
                const Icon(Icons.contactless_outlined, color: Colors.white, size: 32),
              ],
            ),
            const SizedBox(height: 24),
            const Icon(Icons.sim_card_outlined, color: Colors.amber, size: 36),
            const SizedBox(height: 16),
            Text(
              '•••• •••• •••• ${card.lastFour}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              card.holderName.toUpperCase(),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text('Validade ${card.expiry}', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: percent > 0.85 ? Colors.orangeAccent : Colors.lightGreenAccent,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Usado ${currency.format(card.currentBalance)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Limite ${currency.format(card.creditLimit)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
