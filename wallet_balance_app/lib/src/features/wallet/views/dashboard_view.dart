import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wallet_balance_app/src/common/dependency_injectors/dependency_injector.dart';
import 'package:wallet_balance_app/src/common/patterns/state_pattern.dart';
import 'package:wallet_balance_app/src/common/state_management/state_management.dart';
import 'package:wallet_balance_app/src/features/settings/models/setting_model.dart';
import 'package:wallet_balance_app/src/features/settings/routes/setting_routes.dart';
import 'package:wallet_balance_app/src/features/settings/view_models/setting_view_model.dart';
import 'package:wallet_balance_app/src/features/wallet/exceptions/wallet_exception.dart';
import 'package:wallet_balance_app/src/features/wallet/models/card_summary_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/dashboard_screen_state.dart';
import 'package:wallet_balance_app/src/features/wallet/models/invoice_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/merchant_spending_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/transaction_model.dart';
import 'package:wallet_balance_app/src/features/wallet/view_models/dashboard_view_model.dart';
import 'package:wallet_balance_app/src/features/wallet/widgets/legacy_credit_card_widget.dart';
import 'package:wallet_balance_app/src/features/wallet/widgets/modern_credit_card_widget.dart';
import 'package:wallet_balance_app/src/features/wallet/widgets/spending_chart_widget.dart';

class DashboardView extends StatefulWidget {
  final DashboardViewModel dashboardViewModel;

  const DashboardView({super.key, required this.dashboardViewModel});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.dashboardViewModel.loadDashboard();
    });
  }

  Future<void> _refresh() => widget.dashboardViewModel.loadDashboard();

  Future<void> _showPurchaseDialog() async {
    final amountCtrl = TextEditingController();
    final merchantCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova compra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: merchantCtrl,
              decoration: const InputDecoration(labelText: 'Estabelecimento'),
            ),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0 || merchantCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe valor e estabelecimento válidos.')),
      );
      return;
    }

    final success = await widget.dashboardViewModel.addPurchase(
      amount: amount,
      merchant: merchantCtrl.text.trim(),
      description: descCtrl.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Compra registrada.' : 'Erro ao registrar compra.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Balance'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(SettingRoutes.setting),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPurchaseDialog,
        icon: const Icon(Icons.add_outlined),
        label: const Text('Nova compra'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StateBuilderWidget<DashboardViewModel, DashboardScreenState>(
          viewModel: widget.dashboardViewModel,
          builder: (context, screenState) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                const SizedBox(height: 8),
                _buildCardSection(screenState.card),
                const SizedBox(height: 16),
                _buildInvoiceSection(screenState.invoice, currency, dateFmt),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('Gastos por estabelecimento', style: Theme.of(context).textTheme.titleMedium),
                ),
                _buildChartSection(screenState.spending),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('Extrato', style: Theme.of(context).textTheme.titleMedium),
                ),
                _buildTransactionsSection(screenState.transactions, currency, dateFmt),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardSection(StatePattern<CardSummaryModel, WalletException> cardState) {
    return switch (cardState) {
      InitialState() || LoadingState() => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      ErrorState(:final error) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error.message),
      ),
      SuccessState(:final data) => StateBuilderWidget<SettingViewModel, SettingModel>(
        viewModel: locator<SettingViewModel>(),
        builder: (context, settings) {
          return settings.cardStyle == CardStyle.modern
              ? ModernCreditCardWidget(card: data)
              : LegacyCreditCardWidget(card: data);
        },
      ),
    };
  }

  Widget _buildInvoiceSection(
    StatePattern<InvoiceModel, WalletException> state,
    NumberFormat currency,
    DateFormat dateFmt,
  ) {
    return switch (state) {
      InitialState() || LoadingState() => const SizedBox.shrink(),
      ErrorState(:final error) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Fatura: ${error.message}'),
      ),
      SuccessState(:final data) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fatura atual', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Total: ${currency.format(data.totalAmount)}'),
              Text('Vencimento: ${dateFmt.format(data.dueDate)}'),
              Text('Status: ${data.status}'),
            ],
          ),
        ),
      ),
    };
  }

  Widget _buildChartSection(StatePattern<List<MerchantSpendingModel>, WalletException> state) {
    return switch (state) {
      InitialState() || LoadingState() => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      ErrorState(:final error) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error.message),
      ),
      SuccessState(:final data) => SpendingChartWidget(data: data),
    };
  }

  Widget _buildTransactionsSection(
    StatePattern<List<TransactionModel>, WalletException> state,
    NumberFormat currency,
    DateFormat dateFmt,
  ) {
    return switch (state) {
      InitialState() || LoadingState() => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      ErrorState(:final error) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error.message),
      ),
      SuccessState(:final data) when data.isEmpty => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nenhuma transação.'),
      ),
      SuccessState(:final data) => Column(
        children: [
          for (final tx in data)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(tx.merchant),
              subtitle: Text('${dateFmt.format(tx.occurredAt)} · ${tx.description}'),
              trailing: Text(currency.format(tx.amount)),
            ),
        ],
      ),
    };
  }
}
