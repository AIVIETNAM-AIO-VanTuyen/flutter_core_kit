import 'package:flutter_core_kit/constants/app_constants.dart';
import 'package:flutter_core_kit/routes/app_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _pump(WidgetTester tester) async {
  final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/a',
    routes: [
      for (final String name in ['a', 'b', 'c'])
        GoRoute(
          path: '/$name',
          builder: (_, GoRouterState state) => Scaffold(body: Text('PAGE $name ${state.uri.query}')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) => router.state.uri.toString();

void main() {
  testWidgets('push chồng màn, back lùi lại và trả kết quả cho push', (tester) async {
    final GoRouter router = await _pump(tester);

    final Future<bool?> result = AppNavigator.push<bool>('/b');
    await tester.pumpAndSettle();
    expect(_location(router), '/b');
    expect(AppNavigator.canBack, isTrue);

    expect(AppNavigator.back(true), isTrue);
    await tester.pumpAndSettle();
    expect(_location(router), '/a');
    expect(await result, isTrue);
  });

  testWidgets('back ở màn đầu bỏ qua, không pop mất màn gốc', (tester) async {
    final GoRouter router = await _pump(tester);

    expect(AppNavigator.canBack, isFalse);
    expect(AppNavigator.back(), isFalse);
    await tester.pumpAndSettle();
    expect(_location(router), '/a');
    expect(find.text('PAGE a '), findsOneWidget);
  });

  testWidgets('go thay cả stack: không còn màn để lùi', (tester) async {
    final GoRouter router = await _pump(tester);
    AppNavigator.push<void>('/b');
    await tester.pumpAndSettle();

    AppNavigator.go('/c');
    await tester.pumpAndSettle();

    expect(_location(router), '/c');
    expect(AppNavigator.canBack, isFalse);
  });

  testWidgets('pushReplacement / replace thay màn trên cùng, Back về màn bên dưới', (tester) async {
    final GoRouter router = await _pump(tester);
    AppNavigator.push<void>('/b');
    await tester.pumpAndSettle();

    AppNavigator.pushReplacement<void>('/c');
    await tester.pumpAndSettle();
    expect(_location(router), '/c');

    AppNavigator.replace<void>('/b');
    await tester.pumpAndSettle();
    expect(_location(router), '/b');

    AppNavigator.back();
    await tester.pumpAndSettle();
    expect(_location(router), '/a');
  });

  testWidgets('backToFirst lùi về màn đầu stack', (tester) async {
    final GoRouter router = await _pump(tester);
    AppNavigator.push<void>('/b');
    await tester.pumpAndSettle();
    AppNavigator.push<void>('/c');
    await tester.pumpAndSettle();

    AppNavigator.backToFirst();
    await tester.pumpAndSettle();

    expect(_location(router), '/a');
    expect(AppNavigator.canBack, isFalse);
  });

  testWidgets('query: số / danh sách đổi sang chuỗi, null bị bỏ', (tester) async {
    final GoRouter router = await _pump(tester);

    AppNavigator.go(
      '/b',
      query: {
        'id': 12,
        'tags': ['x', 1],
        'q': 'a b',
        'empty': null,
      },
    );
    await tester.pumpAndSettle();

    final Uri uri = router.state.uri;
    expect(uri.path, '/b');
    expect(uri.queryParametersAll, {
      'id': ['12'],
      'tags': ['x', '1'],
      'q': ['a b'],
    });
  });

  test('chưa có router gắn navigatorKey → báo lỗi rõ ràng', () {
    expect(() => AppNavigator.go('/a'), throwsStateError);
  });
}
