import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_core_kit/models/account_model.dart';
import 'package:flutter_core_kit/models/interfaces/account_model_interface.dart';
import 'package:flutter_core_kit/modules/login/login_page.dart';
import 'package:flutter_core_kit/repositories/interfaces/login_response_interface.dart';
import 'package:flutter_core_kit/services/base_services.dart';
import 'package:flutter_core_kit/singletons/account_store.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Result = BaseServices<AccountModel, LoginErrorForm>;

final _Result _ok = _Result.success(AccountModel(data: const AccountModelInterface(id: 1)));

Future<void> _pump(
  WidgetTester tester, {
  required Future<_Result> Function({required String email, required String password}) login,
  void Function()? onLoggedIn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoginPage(login: login, onLoggedIn: onLoggedIn ?? () {}),
    ),
  );
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), ' lan@example.com ');
  await tester.enterText(find.byType(TextField).at(1), 'secret');
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
}

void main() {
  setUp(() {
    accountStore.clear();
    accountStore.takeSessionNotice();
  });

  testWidgets('thành công: gửi email đã trim, gọi onLoggedIn', (WidgetTester tester) async {
    final List<String> sent = [];
    int loggedIn = 0;
    await _pump(
      tester,
      login: ({required String email, required String password}) async {
        sent.addAll([email, password]);
        return _ok;
      },
      onLoggedIn: () => loggedIn++,
    );

    await _fillAndSubmit(tester);

    expect(sent, ['lan@example.com', 'secret']);
    expect(loggedIn, 1);
  });

  testWidgets('đang gửi: hiện vòng quay, bấm lại không gửi thêm', (WidgetTester tester) async {
    final Completer<_Result> server = Completer<_Result>();
    int calls = 0;
    await _pump(
      tester,
      login: ({required String email, required String password}) {
        calls++;
        return server.future;
      },
    );

    await _fillAndSubmit(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    server.complete(_ok);
    await tester.pump();
  });

  testWidgets('422: lỗi hiện dưới từng ô; gõ lại thì mất', (WidgetTester tester) async {
    await _pump(
      tester,
      login: ({required String email, required String password}) async => const _Result.failure(
        ValidationFailure(message: 'Please check your input'),
        error: LoginErrorForm(emailError: 'That email address is not valid.'),
      ),
    );

    await _fillAndSubmit(tester);
    expect(find.text('That email address is not valid.'), findsOneWidget);
    expect(find.text('Please check your input'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'lan@example.co');
    await tester.pump();
    expect(find.text('That email address is not valid.'), findsNothing);
  });

  testWidgets('lỗi nghiệp vụ / mất mạng: hiện câu lỗi chung, cho gửi lại', (WidgetTester tester) async {
    await _pump(
      tester,
      login: ({required String email, required String password}) async =>
          const _Result.failure(ApiFailure(message: 'Wrong email or password.')),
    );

    await _fillAndSubmit(tester);

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('mở màn khi có câu báo phiên hết hạn: hiện một lần', (WidgetTester tester) async {
    accountStore.setSessionNotice('Login session has expired');
    await _pump(tester, login: ({required String email, required String password}) async => _ok);

    expect(find.text('Login session has expired'), findsOneWidget);
    expect(accountStore.sessionNotice, isNull);
  });
}
