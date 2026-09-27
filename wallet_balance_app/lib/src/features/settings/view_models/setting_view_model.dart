import 'package:wallet_balance_app/src/common/state_management/state_management.dart';
import 'package:wallet_balance_app/src/features/settings/models/setting_model.dart';
import 'package:wallet_balance_app/src/features/settings/repositories/setting_repository.dart';
import 'package:flutter/foundation.dart';

typedef _ViewModel = StateManagement<SettingModel>;

abstract interface class SettingViewModel extends _ViewModel {
  Future<void> loadSettings();
  Future<void> changeTheme({required bool isDarkTheme});
  Future<void> changeCardStyle({required CardStyle cardStyle});
}

class SettingViewModelImpl extends _ViewModel implements SettingViewModel {
  final SettingRepository settingRepository;

  SettingViewModelImpl({required this.settingRepository});

  @override
  SettingModel build() => SettingModel();

  @override
  Future<void> loadSettings() async {
    final model = await settingRepository.readSettings();
    _emit(model);
  }

  @override
  Future<void> changeTheme({required bool isDarkTheme}) async {
    final model = state.copyWith(isDarkTheme: isDarkTheme);
    await settingRepository.updateTheme(isDarkTheme: isDarkTheme);
    _emit(model);
  }

  @override
  Future<void> changeCardStyle({required CardStyle cardStyle}) async {
    final model = state.copyWith(cardStyle: cardStyle);
    await settingRepository.updateCardStyle(cardStyle: cardStyle);
    _emit(model);
  }

  void _emit(SettingModel newState) {
    emitState(newState);
    debugPrint('SettingViewModel: ${state.cardStyle}');
  }
}
