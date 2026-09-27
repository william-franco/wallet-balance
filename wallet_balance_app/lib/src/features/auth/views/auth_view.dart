import 'package:wallet_balance_app/src/features/auth/routes/auth_routes.dart';
import 'package:wallet_balance_app/src/features/auth/view_models/auth_session_view_model.dart';
import 'package:wallet_balance_app/src/features/wallet/routes/wallet_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthView extends StatefulWidget {
  final AuthSessionViewModel authSessionViewModel;

  const AuthView({super.key, required this.authSessionViewModel});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.authSessionViewModel.checkSession();
      if (!mounted) return;
      _navigate(widget.authSessionViewModel.state.hasSession);
    });
  }

  void _navigate(bool hasSession) {
    if (hasSession) {
      context.go(WalletRoutes.dashboard);
    } else {
      context.go(AuthRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: FlutterLogo()));
  }
}
