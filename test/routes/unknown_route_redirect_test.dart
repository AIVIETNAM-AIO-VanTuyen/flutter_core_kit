import 'package:flutter_core_kit/routes/app_routes.dart';
import 'package:flutter_core_kit/routes/unknown_route_redirect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Màn có state riêng: đổi page/dựng lại là mất số đếm, để kiểm tra link lạ không làm mất màn đang mở.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => _count++), child: Text('home $_count'));
}

Future<GoRouter> _pump(WidgetTester tester, {required String initialLocation}) async {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    redirect: UnknownRouteRedirect().call,
    errorBuilder: (_, _) => const Text('not found'),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const Text('splash')),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const Text('login')),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: _Counter()),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) => router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('mở nguội bằng path lạ → về Splash, không hiện màn lỗi', (tester) async {
    final GoRouter router = await _pump(tester, initialLocation: '/khoa-hoc/123?ref=mail');

    expect(_location(router), AppRoutes.splash);
    expect(find.text('splash'), findsOneWidget);
    expect(find.text('not found'), findsNothing);
  });

  testWidgets('path hợp lệ đi thẳng, không bị đổi hướng', (tester) async {
    final GoRouter router = await _pump(tester, initialLocation: AppRoutes.home);

    expect(_location(router), AppRoutes.home);
    expect(find.text('home 0'), findsOneWidget);
  });

  testWidgets('link lạ tới lúc Splash đang chạy → ở lại Splash, chưa vào Home khi chưa khởi tạo xong', (tester) async {
    final GoRouter router = await _pump(tester, initialLocation: AppRoutes.splash);

    router.go('/link-la');
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.splash);
    expect(find.text('splash'), findsOneWidget);
  });

  testWidgets('link lạ khi đang ở màn khác (Login) → về Home', (tester) async {
    final GoRouter router = await _pump(tester, initialLocation: AppRoutes.login);

    router.go('/link-la');
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.home);
    expect(find.text('home 0'), findsOneWidget);
  });

  testWidgets('link lạ khi đang ở Home → ở yên Home, giữ nguyên state màn', (tester) async {
    final GoRouter router = await _pump(tester, initialLocation: AppRoutes.home);
    await tester.tap(find.text('home 0'));
    await tester.pump();

    router.go('/link-la');
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.home);
    expect(find.text('home 1'), findsOneWidget);
    expect(find.text('not found'), findsNothing);
  });

  testWidgets('link lạ từ hệ điều hành (deep link) cũng được chặn', (tester) async {
    final GoRouter router = await _pump(tester, initialLocation: AppRoutes.home);

    // Đường Flutter đẩy link của Android intent / iOS URL vào router
    await tester.binding.handlePushRoute('/abc/def');
    await tester.pumpAndSettle();

    expect(_location(router), AppRoutes.home);
    expect(find.text('not found'), findsNothing);
  });
}
