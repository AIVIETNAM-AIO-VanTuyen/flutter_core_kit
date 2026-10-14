import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BaseResponse.fromHttp', () {
    test('envelope success 1: body là lớp chứa success, không lỗi', () {
      final BaseResponse res = BaseResponse.fromHttp(200, {
        'data': {
          'token': {'access_token': 'eyJ'},
          'message': 'Logged in successfully',
          'success': 1,
        },
      });
      expect(res.isSuccessApi, isTrue);
      expect(res.body?['token'], {'access_token': 'eyJ'});
      expect(res.message, 'Logged in successfully');
      expect(res.failure, isNull);
    });

    test('envelope success 0: ApiFailure mang câu BE, vẫn giữ body', () {
      final BaseResponse res = BaseResponse.fromHttp(200, {
        'data': {'message': 'Wrong email or password.', 'success': 0, 'data': []},
      });
      expect(res.isFailSuccess, isTrue);
      expect(res.message, 'Wrong email or password.');
      expect(res.success, 0);
      expect(res.data, isEmpty);
    });

    test('success 0 mà không có message → câu mặc định', () {
      final BaseResponse res = BaseResponse.fromHttp(200, {
        'data': {'success': 0},
      });
      expect(res.failure?.message, 'Something went wrong, please try again');
    });

    test('2xx mà body không phải JSON object (HTML wifi cổng đăng nhập, rỗng) → lỗi, giữ raw', () {
      for (final Object? raw in ['<html>Hotel Wi-Fi login</html>', '', null, [1, 2]]) {
        final BaseResponse res = BaseResponse.fromHttp(200, raw);
        expect(res.isSuccessApi, isFalse, reason: '$raw');
        expect(res.failure, isA<UnknownFailure>(), reason: '$raw');
        expect(res.message, 'Something went wrong, please try again');
        expect(res.raw, raw);
        expect(res.body, isNull);
      }
    });

    test('204 No Content vẫn là thành công', () {
      for (final Object? raw in [null, '']) {
        final BaseResponse res = BaseResponse.fromHttp(204, raw);
        expect(res.isSuccessApi, isTrue, reason: '$raw');
        expect(res.body, isNull);
      }
    });

    test('JSON object không theo envelope vẫn là thành công', () {
      expect(BaseResponse.fromHttp(200, {'ok': true}).isSuccessApi, isTrue);
    });
  });

  group('BaseResponse.fromException', () {
    test('422: errors là lỗi từng ô thô của BE', () {
      final BaseResponse res = BaseResponse.fromException(
        const ApiException(
          ApiErrorType.validation,
          'Invalid data transmission',
          statusCode: 422,
          data: {'email': 'That email address is not valid.'},
        ),
      );
      expect(res.isUnprocessableEntity, isTrue);
      expect(res.statusCode, 422);
      expect(res.errors, {'email': 'That email address is not valid.'});
      expect(res.body, isNull);
    });

    test('lỗi khác 422 không có errors', () {
      final BaseResponse res = BaseResponse.fromException(
        const ApiException(ApiErrorType.business, 'x', data: {'email': 'y'}),
      );
      expect(res.errors, isNull);
    });

    test('mỗi loại lỗi bật đúng một cờ', () {
      BaseResponse of(ApiErrorType type) => BaseResponse.fromException(ApiException(type, 'x'));

      expect(of(ApiErrorType.unauthorized).isUnauthorized, isTrue);
      expect(of(ApiErrorType.forbidden).isCodeForbidden, isTrue);
      expect(of(ApiErrorType.notFound).isNotFound, isTrue);
      expect(of(ApiErrorType.server).isServerError, isTrue);
      expect(of(ApiErrorType.timeout).isNetworkError, isTrue);
      expect(of(ApiErrorType.cancelled).isCancelled, isTrue);
      expect(of(ApiErrorType.server).isUnauthorized, isFalse);
      expect(of(ApiErrorType.unknown).failure, isA<UnknownFailure>());
    });
  });

  test('toString che token / mật khẩu ở mọi tầng', () {
    final String text = BaseResponse.fromHttp(200, {
      'data': {
        'token': {'access_token': 'eyJ0eXAiSECRET', 'access_expire': 1},
        'user': {'id': 52, 'email': 'user01@example.com'},
        'success': 1,
      },
    }).toString();

    expect(text, isNot(contains('eyJ0eXAiSECRET')));
    expect(text, contains('"access_token": "***"'));
    expect(text, contains('user01@example.com'));
    // token là object thì che từng khoá bên trong, vẫn thấy hạn
    expect(text, contains('"access_expire": 1'));
  });

  test('che cả token dạng chuỗi và khoá viết hoa', () {
    final String text = BaseResponse.fromHttp(200, {
      'data': {
        'token': 'eyJSTRING',
        'Authorization': 'eyJHEADER',
        'FCM_TOKEN': 'fcmSECRET',
        'api_token': 'apiSECRET',
        'success': 1,
      },
    }).toString();

    expect(text, isNot(contains('SECRET')));
    expect(text, isNot(contains('eyJ')));
    expect(text, contains('"token": "***"'));
    expect(text, contains('"Authorization": "***"'));
  });
}
