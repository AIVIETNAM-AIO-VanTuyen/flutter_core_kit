import 'package:flutter_core_kit/repositories/interfaces/login_response_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đọc token (kèm hạn) và user nằm cạnh success', () {
    final LoginResponseInterface data = LoginResponseInterface.fromJson({
      'token': {'access_token': 'eyJ0eXAi', 'access_expire': 1793836800, 'token_type': 'Bearer'},
      'user': {'id': 12, 'name': 'Lan Nguyen'},
      'message': 'Logged in successfully',
      'success': 1,
    });

    expect(data.token.accessToken, 'eyJ0eXAi');
    expect(data.token.expiresAt, DateTime.fromMillisecondsSinceEpoch(1793836800 * 1000));
    expect(data.user.id, 12);
    expect(data.toJson()['token'], {'access_token': 'eyJ0eXAi', 'access_expire': 1793836800});
  });

  test('access_expire dạng chuỗi vẫn đọc được', () {
    final LoginResponseInterface data = LoginResponseInterface.fromJson({
      'token': {'access_token': 'eyJ', 'access_expire': '1793836800'},
      'user': {'id': '12'},
    });
    expect(data.token.accessExpire, 1793836800);
    expect(data.user.id, 12);
  });

  test('thiếu token / user → TypeError; token rỗng / thiếu hạn → FormatException', () {
    expect(
      () => LoginResponseInterface.fromJson({
        'user': {'id': 1},
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => LoginResponseInterface.fromJson({
        'token': {'access_token': 'x', 'access_expire': 1},
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => LoginResponseInterface.fromJson({
        'token': {'access_token': '', 'access_expire': 1},
        'user': {'id': 1},
      }),
      throwsFormatException,
    );
    expect(
      () => LoginResponseInterface.fromJson({
        'token': {'access_token': 'x'},
        'user': {'id': 1},
      }),
      throwsFormatException,
    );
  });

  group('LoginErrorForm', () {
    test('BE gửi mỗi ô một câu; Laravel gốc gửi mảng thì lấy câu đầu', () {
      final LoginErrorForm form = LoginErrorForm.fromJson({
        'email': 'That email address is not valid.',
        'password': ['Password must be at least 6 characters long', 'x'],
      });
      expect(form.emailError, 'That email address is not valid.');
      expect(form.passwordError, 'Password must be at least 6 characters long');
      expect(form.isEmpty, isFalse);
    });

    test('ô khác hoặc thiếu ô → null, isEmpty', () {
      final LoginErrorForm form = LoginErrorForm.fromJson({'device_token': 'x'});
      expect(form.emailError, isNull);
      expect(form.isEmpty, isTrue);
    });
  });
}
