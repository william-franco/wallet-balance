import 'package:wallet_balance_app/src/common/dependency_injectors/dependency_injector.dart';
import 'package:wallet_balance_app/src/features/wallet/view_models/dashboard_view_model.dart';
import 'package:wallet_balance_app/src/features/wallet/views/dashboard_view.dart';
import 'package:go_router/go_router.dart';

class WalletRoutes {
  static const dashboard = '/dashboard';

  List<RouteBase> get routes => [
    GoRoute(
      path: dashboard,
      builder: (context, state) => DashboardView(
        dashboardViewModel: locator<DashboardViewModel>(),
      ),
    ),
  ];
}
