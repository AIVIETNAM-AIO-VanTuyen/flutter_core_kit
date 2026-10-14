import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_core_kit/services/base_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success: có data, không có lỗi', () {
    const BaseServices<int, String> response = BaseServices<int, String>.success(1);
    expect(response.isSuccess, isTrue);
    expect(response.data, 1);
    expect(response.failure, isNull);
    expect(response.error, isNull);
    expect(response.message, isNull);
  });

  test('failure: giữ loại lỗi, câu lỗi và form 422', () {
    const BaseServices<int, String> response = BaseServices<int, String>.failure(
      ValidationFailure(message: 'Invalid data transmission'),
      error: 'form',
    );
    expect(response.isSuccess, isFalse);
    expect(response.isUnprocessableEntity, isTrue);
    expect(response.data, isNull);
    expect(response.error, 'form');
    expect(response.message, 'Invalid data transmission');
  });

  test('mỗi loại lỗi bật đúng một cờ', () {
    expect(const BaseServices<void, void>.failure(ApiFailure(message: 'x')).isFailSuccess, isTrue);
    expect(const BaseServices<void, void>.failure(UnauthorizedFailure()).isUnauthorized, isTrue);
    expect(const BaseServices<void, void>.failure(NetworkFailure()).isNetworkError, isTrue);
    expect(const BaseServices<void, void>.failure(ServerFailure()).isServerError, isTrue);
    expect(const BaseServices<void, void>.failure(ServerFailure()).isNetworkError, isFalse);
  });

  group('BaseServices.from', () {
    String token(Map<String, dynamic> body) => (body['token'] as Map<String, dynamic>)['access_token'] as String;
    String emailError(Map<String, dynamic> errors) => errors['email'] as String;

    test('thành công: parser đọc body', () {
      final BaseServices<String, String> res = BaseServices.from(
        const BaseResponse(
          body: {
            'token': {'access_token': 'eyJ'},
            'success': 1,
          },
        ),
        parser: token,
        errorParser: emailError,
      );
      expect(res.isSuccess, isTrue);
      expect(res.data, 'eyJ');
    });

    test('JSON sai hình dạng hoặc không có body → ParseFailure', () {
      expect(BaseServices.from(const BaseResponse(body: {'success': 1}), parser: token).failure, isA<ParseFailure>());
      expect(BaseServices.from(const BaseResponse(), parser: token).isParseError, isTrue);
    });

    test('422: errorParser đọc lỗi từng ô; form hỏng thì error null, failure vẫn giữ', () {
      final BaseServices<String, String> res = BaseServices.from(
        const BaseResponse(
          failure: ValidationFailure(message: 'Invalid data transmission'),
          errors: {'email': 'That email address is not valid.'},
        ),
        parser: token,
        errorParser: emailError,
      );
      expect(res.isUnprocessableEntity, isTrue);
      expect(res.error, 'That email address is not valid.');

      final BaseServices<String, String> broken = BaseServices.from(
        const BaseResponse(failure: ValidationFailure(), errors: {'password': 'x'}),
        parser: token,
        errorParser: emailError,
      );
      expect(broken.error, isNull);
      expect(broken.failure, isA<ValidationFailure>());
    });

    test('lỗi khác: giữ nguyên failure, không chạy parser', () {
      final BaseServices<String, String> res = BaseServices.from(
        const BaseResponse(failure: ApiFailure(message: 'Wrong email or password.')),
        parser: (_) => throw StateError('không được gọi'),
      );
      expect(res.message, 'Wrong email or password.');
    });
  });

  test('map: đổi data khi thành công, giữ lỗi và error khi thất bại', () {
    expect(const BaseServices<int, String>.success(2).map((int v) => '$v').data, '2');

    final BaseServices<String, String> failed = const BaseServices<int, String>.failure(
      ValidationFailure(),
      error: 'form',
    ).map((int v) => '$v');
    expect(failed.isUnprocessableEntity, isTrue);
    expect(failed.error, 'form');
  });
}
