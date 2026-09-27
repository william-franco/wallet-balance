import 'package:wallet_balance_app/src/common/constants/value_constant.dart';
import 'package:wallet_balance_app/src/common/services/storage_service.dart';
import 'package:wallet_balance_app/src/features/settings/models/setting_model.dart';

abstract interface class SettingRepository {
  Future<SettingModel> readSettings();
  Future<void> updateTheme({required bool isDarkTheme});
  Future<void> updateCardStyle({required CardStyle cardStyle});
}

class SettingRepositoryImpl implements SettingRepository {
  final StorageService storageService;

  SettingRepositoryImpl({required this.storageService});

  @override
  Future<SettingModel> readSettings() async {
    try {
      final isDarkMode = await storageService.getBoolValue(
        key: ValueConstant.darkMode,
      );
      final styleRaw = await storageService.getStringValue(
        key: ValueConstant.cardStyle,
      );
      final cardStyle = styleRaw == 'modern' ? CardStyle.modern : CardStyle.legacy;
      return SettingModel(
        isDarkTheme: isDarkMode ?? false,
        cardStyle: cardStyle,
      );
    } catch (error) {
      throw Exception('SettingRepository: $error');
    }
  }

  @override
  Future<void> updateTheme({required bool isDarkTheme}) async {
    await storageService.setBoolValue(
      key: ValueConstant.darkMode,
      value: isDarkTheme,
    );
  }

  @override
  Future<void> updateCardStyle({required CardStyle cardStyle}) async {
    await storageService.setStringValue(
      key: ValueConstant.cardStyle,
      value: cardStyle == CardStyle.modern ? 'modern' : 'legacy',
    );
  }
}
