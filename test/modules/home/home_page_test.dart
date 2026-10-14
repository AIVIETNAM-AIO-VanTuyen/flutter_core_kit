import 'dart:async';

import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_core_kit/models/account_model.dart';
import 'package:flutter_core_kit/models/interfaces/account_model_interface.dart';
import 'package:flutter_core_kit/modules/home/home_page.dart';
import 'package:flutter_core_kit/services/base_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final BaseServices<AccountModel, void> _profile = BaseServices<AccountModel, void>.success(
  AccountModel(
    data: const AccountModelInterface(id: 52, name: 'Amélie Legrand', email: 'user01@example.com'),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  Future<BaseServices<AccountModel, void>> Function()? getProfile,
  Future<BaseServices<void, void>> Function()? logout,
  void Function()? onLoggedOut,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        getProfile: getProfile ?? () async => _profile,
        logout: logout ?? () async => const BaseServices<void, void>.success(null),
        onLoggedOut: onLoggedOut ?? () {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('hồ sơ', () {
    testWidgets('đang tải thì quay, xong thì hiện tên, email', (WidgetTester tester) async {
      final Completer<BaseServices<AccountModel, void>> server = Completer<BaseServices<AccountModel, void>>();
      await _pump(tester, getProfile: () => server.future);
      expect(find.text('Amélie Legrand'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      server.complete(_profile);
      await tester.pump();

      expect(find.text('Amélie Legrand'), findsOneWidget);
      expect(find.text('user01@example.com'), findsOneWidget);
    });

    testWidgets('chưa đăng nhập / phiên hết → rời Home về Đăng nhập', (WidgetTester tester) async {
      int left = 0;
      await _pump(
        tester,
        getProfile: () async => const BaseServices<AccountModel, void>.failure(UnauthorizedFailure()),
        onLoggedOut: () => left++,
      );
      expect(left, 1);
    });

    testWidgets('lỗi khác: hiện câu lỗi, Try again tải lại', (WidgetTester tester) async {
      int calls = 0;
      await _pump(
        tester,
        getProfile: () async => ++calls == 1
            ? const BaseServices<AccountModel, void>.failure(NetworkFailure(message: 'Access the Internet to continue'))
            : _profile,
      );
      expect(find.text('Access the Internet to continue'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(calls, 2);
      expect(find.text('Amélie Legrand'), findsOneWidget);
    });
  });

  testWidgets('bấm Log out: đợi API xong rồi mới rời Home', (WidgetTester tester) async {
    final Completer<BaseServices<void, void>> server = Completer<BaseServices<void, void>>();
    int left = 0;
    await _pump(tester, logout: () => server.future, onLoggedOut: () => left++);

    await tester.tap(find.text('Log out'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(left, 0);
    // Đang chờ API: bấm lại không gọi thêm
    await tester.tap(find.text('Log out'));
    await tester.pump();

    server.complete(const BaseServices<void, void>.success(null));
    await tester.pump(const Duration(milliseconds: 500));
    expect(left, 1);
  });

  testWidgets('Log out lỗi (mất mạng) vẫn rời Home về Đăng nhập', (WidgetTester tester) async {
    int left = 0;
    await _pump(
      tester,
      logout: () async =>
          const BaseServices<void, void>.failure(NetworkFailure(message: 'Access the Internet to continue')),
      onLoggedOut: () => left++,
    );

    await tester.tap(find.text('Log out'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(left, 1);
  });
}
