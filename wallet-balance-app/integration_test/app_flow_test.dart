import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wallet_balance_app/main.dart' as app;
import 'package:wallet_balance_app/src/common/constants/api_constant.dart';

const _password = 'Pass123!';

Future<void> seedUser(String email) async {
  final client = HttpClient();
  final request = await client.postUrl(
    Uri.parse('${ApiConstant.baseUrl}${ApiConstant.authRegister}'),
  );
  request.headers.contentType = ContentType.json;
  request.write(
    jsonEncode({'name': 'E2E User', 'email': email, 'password': _password}),
  );
  final response = await request.close();
  await response.drain();
  client.close(force: true);
}

Future<void> enterLastEditable(
  WidgetTester tester,
  int fromEnd,
  String value,
) async {
  final fields = find.byType(EditableText);
  final total = fields.evaluate().length;
  final field = fields.at(total - fromEnd);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
}

Future<void> loginOnScreen(WidgetTester tester, String email) async {
  for (var i = 0; i < 30; i++) {
    if (find.text('Login').evaluate().isNotEmpty) break;
    await tester.pump(const Duration(seconds: 1));
  }
  await enterLastEditable(tester, 2, email);
  await enterLastEditable(tester, 1, _password);
  final list = find.byType(ListView);
  if (list.evaluate().isNotEmpty) {
    await tester.drag(list.first, const Offset(0, -320));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle(const Duration(seconds: 25));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register and open dashboard with live API', (tester) async {
    final email = 'e2e-${DateTime.now().millisecondsSinceEpoch}@test.local';
    await seedUser(email);

    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 8));

    if (find.text('Wallet Balance').evaluate().isEmpty) {
      expect(find.text('Login'), findsOneWidget);
      await loginOnScreen(tester, email);
    }

    expect(find.text('Wallet Balance'), findsOneWidget);
  });
}