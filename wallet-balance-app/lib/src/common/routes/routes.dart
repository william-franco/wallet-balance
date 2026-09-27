import 'package:wallet_balance_app/src/features/auth/routes/auth_routes.dart';
import 'package:wallet_balance_app/src/features/settings/routes/setting_routes.dart';
import 'package:wallet_balance_app/src/features/wallet/routes/wallet_routes.dart';
import 'package:go_router/go_router.dart';

class Routes {
  static String get home => AuthRoutes.auth;

  final routes = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: home,
    routes: [
      ...AuthRoutes().routes,
      ...WalletRoutes().routes,
      ...SettingRoutes().routes,
    ],
  );
}
