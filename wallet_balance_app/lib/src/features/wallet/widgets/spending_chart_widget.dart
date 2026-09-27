import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:wallet_balance_app/src/features/wallet/models/merchant_spending_model.dart';

class SpendingChartWidget extends StatelessWidget {
  final List<MerchantSpendingModel> data;

  const SpendingChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Sem dados para o gráfico.')),
      );
    }

    final maxY = data.map((e) => e.total).reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, right: 16),
        child: BarChart(
          BarChartData(
            maxY: maxY <= 0 ? 100 : maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    final label = data[i].merchant;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        label.length > 8 ? '${label.substring(0, 8)}…' : label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].total,
                      color: Theme.of(context).colorScheme.primary,
                      width: 18,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
