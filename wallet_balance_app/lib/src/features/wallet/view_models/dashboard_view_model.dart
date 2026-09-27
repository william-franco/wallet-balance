import 'package:wallet_balance_app/src/common/patterns/result_pattern.dart';
import 'package:wallet_balance_app/src/common/patterns/state_pattern.dart';
import 'package:wallet_balance_app/src/common/state_management/state_management.dart';
import 'package:wallet_balance_app/src/features/wallet/models/dashboard_screen_state.dart';
import 'package:wallet_balance_app/src/features/wallet/repositories/wallet_repository.dart';

typedef _DashboardVm = StateManagement<DashboardScreenState>;

abstract interface class DashboardViewModel extends _DashboardVm {
  Future<void> loadDashboard();
  Future<bool> addPurchase({
    required double amount,
    required String merchant,
    required String description,
  });
}

class DashboardViewModelImpl extends StateManagement<DashboardScreenState>
    implements DashboardViewModel {
  final WalletRepository walletRepository;

  DashboardViewModelImpl({required this.walletRepository});

  @override
  DashboardScreenState build() => const DashboardScreenState();

  void _emit(DashboardScreenState next) => emitState(next);

  @override
  Future<void> loadDashboard() async {
    _emit(state.copyWith(
      card: const LoadingState(),
      invoice: const LoadingState(),
      transactions: const LoadingState(),
      spending: const LoadingState(),
    ));

    final cardResult = await walletRepository.getCardSummary();
    final invoiceResult = await walletRepository.getCurrentInvoice();
    final txResult = await walletRepository.getTransactions();
    final spendingResult = await walletRepository.getSpendingByMerchant();

    _emit(state.copyWith(
      card: _map(cardResult),
      invoice: _map(invoiceResult),
      transactions: _mapList(txResult),
      spending: _mapList(spendingResult),
    ));
  }

  StatePattern<T, E> _map<T, E extends Exception>(
    ResultPattern<T, E> result,
  ) {
    return switch (result) {
      SuccessResult(:final value) => SuccessState(data: value),
      ErrorResult(:final error) => ErrorState(error: error),
    };
  }

  StatePattern<List<T>, E> _mapList<T, E extends Exception>(
    ResultPattern<List<T>, E> result,
  ) {
    return switch (result) {
      SuccessResult(:final value) => SuccessState(data: value),
      ErrorResult(:final error) => ErrorState(error: error),
    };
  }

  @override
  Future<bool> addPurchase({
    required double amount,
    required String merchant,
    required String description,
  }) async {
    final result = await walletRepository.createTransaction(
      amount: amount,
      merchant: merchant,
      description: description,
    );
    if (result is SuccessResult) {
      await loadDashboard();
      return true;
    }
    return false;
  }
}
