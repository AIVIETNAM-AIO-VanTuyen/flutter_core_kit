import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiException.toFailure', () {
    test('mất mạng / quá giờ / server không phản hồi → NetworkFailure', () {
      for (final ApiErrorType type in [ApiErrorType.noInternet, ApiErrorType.timeout, ApiErrorType.connection]) {
        expect(ApiException(type, 'x').toFailure(), isA<NetworkFailure>(), reason: '$type');
      }
    });

    test('mỗi loại lỗi HTTP ra đúng một AppFailure, giữ message', () {
      expect(
        const ApiException(ApiErrorType.unauthorized, 'Login session has expired').toFailure(),
        isA<UnauthorizedFailure>().having((AppFailure f) => f.message, 'message', 'Login session has expired'),
      );
      expect(const ApiException(ApiErrorType.forbidden, 'x').toFailure(), isA<ForbiddenFailure>());
      expect(const ApiException(ApiErrorType.notFound, 'x').toFailure(), isA<NotFoundFailure>());
      expect(const ApiException(ApiErrorType.business, 'x').toFailure(), isA<ApiFailure>());
      expect(const ApiException(ApiErrorType.cancelled, 'x').toFailure(), isA<CancelledFailure>());
      expect(const ApiException(ApiErrorType.unknown, 'x').toFailure(), isA<UnknownFailure>());
    });

    test('422 mang theo lỗi từng ô; 5xx mang theo mã', () {
      final AppFailure invalid = const ApiException(
        ApiErrorType.validation,
        'x',
        fieldErrors: {
          'password': ['Password must be at least 6 characters long'],
        },
      ).toFailure();
      expect((invalid as ValidationFailure).firstErrorOf('password'), 'Password must be at least 6 characters long');
      expect(
        const ApiException(ApiErrorType.server, 'x', statusCode: 503).toFailure(),
        isA<ServerFailure>().having((ServerFailure f) => f.statusCode, 'status', 503),
      );
    });
  });
}
