import 'package:flutter_core_kit/constants/app_constants.dart';
import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/modules/login/login_page.dart';
import 'package:flutter_core_kit/routes/app_routes.dart';
import 'package:flutter_core_kit/services/auth_service.dart';
import 'package:flutter_core_kit/singletons/account_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    // StorageHandler bám kho giả của lần tạo đầu: đặt một lần cho cả file
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    accountStore.clear();
    accountStore.takeSessionNotice();
    await TokenStorage.save('eyJ0eXAi');
  });

  testWidgets('phiên hết hạn → xoá phiên, về Đăng nhập, hiện câu BE', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.runAsync(() => expireSession('Login session has expired'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Login session has expired'), findsOneWidget);
    expect(await tester.runAsync(TokenStorage.read), isNull);
  });

  testWidgets('câu đến khi màn Đăng nhập đang mở vẫn hiện; gõ vào ô thì mất', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.text('Your account has been locked'), findsNothing);

    accountStore.setSessionNotice('Your account has been locked');
    await tester.pump();
    expect(find.text('Your account has been locked'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'a');
    await tester.pump();
    expect(find.text('Your account has been locked'), findsNothing);
  });
}
