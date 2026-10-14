import 'package:flutter_core_kit/constants/app_constants.dart';
import 'package:flutter_core_kit/constants/storage_keys.dart';
import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/modules/splash/splash_page.dart';
import 'package:flutter_core_kit/routes/app_routes.dart';
import 'package:flutter_core_kit/singletons/storage_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Router giống app nhưng màn đích là chữ, để không phải dựng màn thật.
Future<GoRouter> _pumpSplash(WidgetTester tester) async {
  final GoRouter router = GoRouter(
    // Như app: AppNavigator tìm router qua navigatorKey
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      for (final String path in [AppRoutes.home, AppRoutes.login])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('PAGE $path')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  return router;
}

/// Splash chờ Firebase (lỗi rồi bỏ qua khi chạy test) và .env rồi mới chuyển màn. Vòng quay chạy lặp nên không
/// pumpAndSettle được.
Future<void> _waitLeaveSplash(WidgetTester tester) async {
  for (int i = 0; i < 50 && find.byType(SplashPage).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // Kho của StorageHandler (Future chuẩn bị kho) và cache chuỗi của rootBundle (.env) là static: tạo lần đầu trong
  // zone giả của testWidgets thì các test sau await lại chúng sẽ treo. Nạp sẵn ở zone thật, rồi mỗi test chỉ xoá khoá.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
    await StorageHandler.read(AppStorageKeys.language);
    await rootBundle.loadString('.env');
  });

  setUp(TokenStorage.clear);

  testWidgets('hiện vòng quay trong lúc khởi động', (WidgetTester tester) async {
    await _pumpSplash(tester);
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _waitLeaveSplash(tester);
  });

  testWidgets('chưa đăng nhập → Đăng nhập', (WidgetTester tester) async {
    final GoRouter router = await _pumpSplash(tester);
    await _waitLeaveSplash(tester);
    expect(find.text('PAGE ${AppRoutes.login}'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.login);
  });

  testWidgets('token còn hạn → màn chính', (WidgetTester tester) async {
    await tester.runAsync(() => TokenStorage.save('abc', expiresAt: DateTime.now().add(const Duration(days: 1))));
    await _pumpSplash(tester);
    await _waitLeaveSplash(tester);
    expect(find.text('PAGE ${AppRoutes.home}'), findsOneWidget);
  });

  testWidgets('token hết hạn coi như chưa đăng nhập, và bị xoá khỏi kho', (WidgetTester tester) async {
    await tester.runAsync(
      () => TokenStorage.save('abc', expiresAt: DateTime.now().subtract(const Duration(minutes: 1))),
    );
    await _pumpSplash(tester);
    await _waitLeaveSplash(tester);
    expect(find.text('PAGE ${AppRoutes.login}'), findsOneWidget);
    expect(await tester.runAsync(TokenStorage.readRaw), isNull);
  });

  testWidgets('go() thay cả stack: không Back về Splash được', (WidgetTester tester) async {
    final GoRouter router = await _pumpSplash(tester);
    await _waitLeaveSplash(tester);
    expect(router.canPop(), isFalse);
  });
}
