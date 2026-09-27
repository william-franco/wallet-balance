import 'package:wallet_balance_app/src/common/state_management/state_management.dart';
import 'package:wallet_balance_app/src/features/settings/models/setting_model.dart';
import 'package:wallet_balance_app/src/features/settings/view_models/setting_view_model.dart';
import 'package:wallet_balance_app/src/features/wallet/models/card_summary_model.dart';
import 'package:wallet_balance_app/src/features/wallet/widgets/legacy_credit_card_widget.dart';
import 'package:wallet_balance_app/src/features/wallet/widgets/modern_credit_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingView extends StatelessWidget {
  final SettingViewModel settingViewModel;

  const SettingView({super.key, required this.settingViewModel});

  static const _previewCard = CardSummaryModel(
    creditLimit: 5000,
    currentBalance: 1500,
    available: 3500,
    holderName: 'Preview User',
    lastFour: '4242',
    brand: 'Mastercard',
    expiry: '12/28',
  );

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationIcon: const FlutterLogo(),
      applicationName: 'Wallet Balance',
      applicationVersion: 'Version 1.0.0',
      applicationLegalese: '\u{a9} 2026 William Franco',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_outlined),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Tema escuro'),
            trailing: StateBuilderWidget<SettingViewModel, SettingModel>(
              viewModel: settingViewModel,
              builder: (context, settingModel) {
                return Switch(
                  value: settingModel.isDarkTheme,
                  onChanged: (value) {
                    settingViewModel.changeTheme(isDarkTheme: value);
                  },
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Estilo do cartão'),
          ),
          StateBuilderWidget<SettingViewModel, SettingModel>(
            viewModel: settingViewModel,
            builder: (context, settingModel) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<CardStyle>(
                  segments: const [
                    ButtonSegment(
                      value: CardStyle.legacy,
                      label: Text('Clássico'),
                      icon: Icon(Icons.credit_card_outlined),
                    ),
                    ButtonSegment(
                      value: CardStyle.modern,
                      label: Text('Moderno'),
                      icon: Icon(Icons.style_outlined),
                    ),
                  ],
                  selected: {settingModel.cardStyle},
                  onSelectionChanged: (set) {
                    settingViewModel.changeCardStyle(cardStyle: set.first);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          StateBuilderWidget<SettingViewModel, SettingModel>(
            viewModel: settingViewModel,
            builder: (context, settingModel) {
              return settingModel.cardStyle == CardStyle.modern
                  ? const ModernCreditCardWidget(card: _previewCard)
                  : const LegacyCreditCardWidget(card: _previewCard);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }
}
