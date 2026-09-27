import 'package:wallet_balance_app/src/common/patterns/state_pattern.dart';
import 'package:wallet_balance_app/src/features/wallet/exceptions/wallet_exception.dart';
import 'package:wallet_balance_app/src/features/wallet/models/card_summary_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/invoice_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/merchant_spending_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/transaction_model.dart';

class DashboardScreenState {
  final StatePattern<CardSummaryModel, WalletException> card;
  final StatePattern<InvoiceModel, WalletException> invoice;
  final StatePattern<List<TransactionModel>, WalletException> transactions;
  final StatePattern<List<MerchantSpendingModel>, WalletException> spending;

  const DashboardScreenState({
    this.card = const InitialState(),
    this.invoice = const InitialState(),
    this.transactions = const InitialState(),
    this.spending = const InitialState(),
  });

  DashboardScreenState copyWith({
    StatePattern<CardSummaryModel, WalletException>? card,
    StatePattern<InvoiceModel, WalletException>? invoice,
    StatePattern<List<TransactionModel>, WalletException>? transactions,
    StatePattern<List<MerchantSpendingModel>, WalletException>? spending,
  }) {
    return DashboardScreenState(
      card: card ?? this.card,
      invoice: invoice ?? this.invoice,
      transactions: transactions ?? this.transactions,
      spending: spending ?? this.spending,
    );
  }
}
