import 'package:flutter_core_kit/constants/app_constants.dart';
import 'package:flutter_core_kit/enums/permission_enum.dart';
import 'package:flutter_core_kit/routes/app_routes.dart';
import 'package:flutter_core_kit/routes/permission_middleware.dart';
import 'package:flutter_core_kit/singletons/account_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const String _example = '/example';

Future<GoRouter> _pump(WidgetTester tester) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: _example,
        redirect: (_, _) => permissionMiddleware(PermissionEnum.example),
        builder: (_, _) => const Text('example'),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router, scaffoldMessengerKey: messengerKey));
  return router;
}

void main() {
  setUp(accountStore.clear);

  testWidgets('có quyền: mở được route', (WidgetTester tester) async {
    accountStore.setPermissions(['EXAMPLE']);
    final GoRouter router = await _pump(tester);

    router.go(_example);
    await tester.pumpAndSettle();

    expect(find.text('example'), findsOneWidget);
  });

  testWidgets('thiếu quyền: về Home, báo snackbar', (WidgetTester tester) async {
    accountStore.setPermissions(['OTHER']);
    final GoRouter router = await _pump(tester);

    router.go(_example);
    // Một nhịp cho router chuyển hướng, một nhịp cho post-frame callback, rồi đợi snackbar trượt vào
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('home'), findsOneWidget);
    expect(find.text('example'), findsNothing);
    expect(find.text('You do not have permission to access this feature'), findsWidgets);
  });
}
