import 'package:wallet_balance_app/src/common/constants/api_constant.dart';
import 'package:wallet_balance_app/src/common/patterns/result_pattern.dart';
import 'package:wallet_balance_app/src/common/services/connection_service.dart';
import 'package:wallet_balance_app/src/common/services/http_service.dart';
import 'package:wallet_balance_app/src/features/wallet/exceptions/wallet_exception.dart';
import 'package:wallet_balance_app/src/features/wallet/models/card_summary_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/invoice_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/merchant_spending_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/transaction_model.dart';

typedef CardResult = ResultPattern<CardSummaryModel, WalletException>;
typedef InvoiceResult = ResultPattern<InvoiceModel, WalletException>;
typedef TransactionsResult = ResultPattern<List<TransactionModel>, WalletException>;
typedef SpendingResult = ResultPattern<List<MerchantSpendingModel>, WalletException>;
typedef TransactionResult = ResultPattern<TransactionModel, WalletException>;

abstract interface class WalletRepository {
  Future<CardResult> getCardSummary();
  Future<InvoiceResult> getCurrentInvoice();
  Future<TransactionsResult> getTransactions({String? month});
  Future<SpendingResult> getSpendingByMerchant({String? month});
  Future<TransactionResult> createTransaction({
    required double amount,
    required String merchant,
    required String description,
  });
}

class WalletRepositoryImpl implements WalletRepository {
  final ConnectionService connectionService;
  final HttpService httpService;

  WalletRepositoryImpl({
    required this.connectionService,
    required this.httpService,
  });

  Future<void> _ensureConnected() async {
    await connectionService.checkConnection();
    if (!connectionService.isConnected) {
      throw WalletException('Dispositivo sem conexão.');
    }
  }

  @override
  Future<CardResult> getCardSummary() async {
    try {
      await _ensureConnected();
      final result = await httpService.getData(path: ApiConstant.cardsMe);
      if (result.statusCode == 200 && result.data != null) {
        return SuccessResult(
          value: CardSummaryModel.fromJson(result.data as Map<String, dynamic>),
        );
      }
      return ErrorResult(
        error: WalletException('Falha ao carregar cartão: ${result.statusCode}'),
      );
    } on WalletException catch (e) {
      return ErrorResult(error: e);
    } catch (e) {
      return ErrorResult(error: WalletException('Erro inesperado: $e'));
    }
  }

  @override
  Future<InvoiceResult> getCurrentInvoice() async {
    try {
      await _ensureConnected();
      final result = await httpService.getData(path: ApiConstant.invoicesCurrent);
      if (result.statusCode == 200 && result.data != null) {
        return SuccessResult(
          value: InvoiceModel.fromJson(result.data as Map<String, dynamic>),
        );
      }
      return ErrorResult(
        error: WalletException('Falha ao carregar fatura: ${result.statusCode}'),
      );
    } on WalletException catch (e) {
      return ErrorResult(error: e);
    } catch (e) {
      return ErrorResult(error: WalletException('Erro inesperado: $e'));
    }
  }

  @override
  Future<TransactionsResult> getTransactions({String? month}) async {
    try {
      await _ensureConnected();
      final path = month == null
          ? ApiConstant.transactions
          : '${ApiConstant.transactions}?month=$month';
      final result = await httpService.getData(path: path);
      if (result.statusCode == 200 && result.data != null) {
        final list = (result.data as List)
            .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return SuccessResult(value: list);
      }
      return ErrorResult(
        error: WalletException('Falha ao carregar extrato: ${result.statusCode}'),
      );
    } on WalletException catch (e) {
      return ErrorResult(error: e);
    } catch (e) {
      return ErrorResult(error: WalletException('Erro inesperado: $e'));
    }
  }

  @override
  Future<SpendingResult> getSpendingByMerchant({String? month}) async {
    try {
      await _ensureConnected();
      final path = month == null
          ? ApiConstant.analyticsSpendingByMerchant
          : '${ApiConstant.analyticsSpendingByMerchant}?month=$month';
      final result = await httpService.getData(path: path);
      if (result.statusCode == 200 && result.data != null) {
        final list = (result.data as List)
            .map((e) => MerchantSpendingModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return SuccessResult(value: list);
      }
      return ErrorResult(
        error: WalletException('Falha ao carregar gráfico: ${result.statusCode}'),
      );
    } on WalletException catch (e) {
      return ErrorResult(error: e);
    } catch (e) {
      return ErrorResult(error: WalletException('Erro inesperado: $e'));
    }
  }

  @override
  Future<TransactionResult> createTransaction({
    required double amount,
    required String merchant,
    required String description,
  }) async {
    try {
      await _ensureConnected();
      final result = await httpService.postData(
        path: ApiConstant.transactions,
        body: {
          'amount': amount,
          'merchant': merchant,
          'description': description,
        },
      );
      if ((result.statusCode == 201 || result.statusCode == 200) &&
          result.data != null) {
        return SuccessResult(
          value: TransactionModel.fromJson(result.data as Map<String, dynamic>),
        );
      }
      return ErrorResult(
        error: WalletException('Falha ao registrar compra: ${result.statusCode}'),
      );
    } on WalletException catch (e) {
      return ErrorResult(error: e);
    } catch (e) {
      return ErrorResult(error: WalletException('Erro inesperado: $e'));
    }
  }
}
