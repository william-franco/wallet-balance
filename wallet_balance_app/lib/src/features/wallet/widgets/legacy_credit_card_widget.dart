import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallet_balance_app/src/features/wallet/models/card_summary_model.dart';

class LegacyCreditCardWidget extends StatelessWidget {
  final CardSummaryModel card;

  const LegacyCreditCardWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Center(
      child: Card(
        elevation: 1,
        color: const Color(0xFF240D4E),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: SizedBox(
          width: size.height * 0.42,
          height: size.width * 0.62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                height: 80,
                width: 80,
                image: AssetImage('assets/logo/mastercard-logo.png'),
              ),
              Text(
                card.brand.toLowerCase(),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                card.holderName,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'XXXX XXXX XXXX ${card.lastFour}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Gasto', style: TextStyle(color: Colors.white)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currency.format(card.currentBalance),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Disponível',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currency.format(card.available),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
