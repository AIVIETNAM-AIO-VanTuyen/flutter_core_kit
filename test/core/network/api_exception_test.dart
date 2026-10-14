import 'dart:io';

import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_core_kit/helpers/network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final RequestOptions _options = RequestOptions(path: 'v1/x');

DioException _dio(DioExceptionType type, {int? status, Object? body}) {
  return DioException(
    requestOptions: _options,
    type: type,
    response: status == null ? null : Response<Object?>(requestOptions: _options, statusCode: status, data: body),
    error: 'gốc',
  );
}

Map<String, Object?> _envelope(Object? data, {String? message}) {
  return {
    'data': {'success': 0, 'message': message, 'data': data},
  };
}

void main() {
  setUp(() => globalInternetNotifier.value = true);
  tearDown(() => globalInternetNotifier.value = true);

  group('ApiException.fromDio', () {
    test('mọi loại timeout → timeout, cho thử lại', () {
      for (final DioExceptionType type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        final ApiException e = ApiException.fromDio(_dio(type));
        expect(e.type, ApiErrorType.timeout, reason: '$type');
        expect(e.isRetryable, isTrue);
      }
    });

    test('cancel → cancelled, không cho thử lại', () {
      final ApiException e = ApiException.fromDio(_dio(DioExceptionType.cancel));
      expect(e.isCancelled, isTrue);
      expect(e.isRetryable, isFalse);
    });

    test('badResponse → theo mã HTTP', () {
      final ApiException e = ApiException.fromDio(_dio(DioExceptionType.badResponse, status: 404, body: null));
      expect(e.type, ApiErrorType.notFound);
      expect(e.statusCode, 404);
    });

    test('unknown: còn mạng → unknown giữ lỗi gốc, mất mạng → noInternet', () {
      final ApiException online = ApiException.fromDio(_dio(DioExceptionType.unknown));
      expect(online.type, ApiErrorType.unknown);
      expect(online.data, 'gốc');
      expect(online.isRetryable, isFalse);

      globalInternetNotifier.value = false;
      expect(ApiException.fromDio(_dio(DioExceptionType.unknown)).type, ApiErrorType.noInternet);
    });

    test('lỗi mạng sau khi đã kết nối (đứt giữa chừng, TLS, chứng chỉ) → connection, cho thử lại', () {
      final List<DioException> errors = [
        for (final Object cause in [
          const SocketException('Connection reset by peer'),
          const HttpException('Connection closed while receiving data'),
          const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
          const TlsException('bad record'),
        ])
          DioException(requestOptions: _options, error: cause),
        DioException.badCertificate(requestOptions: _options),
      ];
      for (final DioException error in errors) {
        final ApiException e = ApiException.fromDio(error);
        expect(e.type, ApiErrorType.connection, reason: '${error.type} ${error.error}');
        expect(e.toFailure(), isA<NetworkFailure>());
        expect(e.isRetryable, isTrue);
      }

      globalInternetNotifier.value = false;
      expect(ApiException.fromDio(DioException.badCertificate(requestOptions: _options)).type, ApiErrorType.noInternet);
    });
  });

  group('ApiException.fromStatus', () {
    test('401 / 403 / 404 lấy message server, thiếu thì câu mặc định', () {
      expect(ApiException.fromStatus(401, null).type, ApiErrorType.unauthorized);
      expect(ApiException.fromStatus(401, null).message, 'Login session has expired');
      expect(ApiException.fromStatus(403, _envelope(null, message: 'Không có quyền')).message, 'Không có quyền');
      expect(ApiException.fromStatus(403, null).type, ApiErrorType.forbidden);
      expect(ApiException.fromStatus(404, {'message': 'Không thấy'}).message, 'Không thấy');
    });

    test('401 ngoài phiên (session: false): thiếu câu thì câu chung, có câu BE thì giữ', () {
      final ApiException e = ApiException.fromStatus(401, null, session: false);
      expect(e.type, ApiErrorType.unauthorized);
      expect(e.message, 'Something went wrong, please try again');
      expect(
        ApiException.fromStatus(401, _envelope(null, message: 'Your account is locked'), session: false).message,
        'Your account is locked',
      );
    });

    test('message rỗng coi như không có', () {
      expect(ApiException.fromStatus(404, _envelope(null, message: '')).message, 'Data not found');
    });

    test('mã lạ hoặc null → unknown', () {
      expect(ApiException.fromStatus(418, null).type, ApiErrorType.unknown);
      expect(ApiException.fromStatus(null, null).type, ApiErrorType.unknown);
    });

    test('mọi mã 5xx → server, giấu message kỹ thuật', () {
      final ApiException e = ApiException.fromStatus(503, _envelope(null, message: 'Redis down'));
      expect(e.type, ApiErrorType.server);
      expect(e.message, isNot(contains('Redis')));
    });

    test('lỗi từng trường chỉ đọc ở 422, bỏ giá trị null', () {
      final ApiException e = ApiException.fromStatus(
        422,
        _envelope({
          'email': ['Sai định dạng', 'Đã tồn tại'],
          'age': 18,
          'note': null,
        }),
      );
      expect(e.fieldErrors, {
        'email': ['Sai định dạng', 'Đã tồn tại'],
        'age': ['18'],
      });
      expect(e.fieldError('email'), 'Sai định dạng');
      expect(e.fieldError('note'), isNull);

      final ApiException notValidation = ApiException.fromStatus(400, _envelope({'email': 'x'}));
      expect(notValidation.fieldErrors, isEmpty);
    });

    test('422 của api v2 không có `success` (BaseFormDataRequest) vẫn đọc được message và lỗi từng trường', () {
      final ApiException e = ApiException.fromStatus(422, {
        'data': {
          'status': 422,
          'message': 'Invalid data transmission',
          'data': {'email': 'That email address is not valid.'},
        },
      });
      expect(e.type, ApiErrorType.validation);
      expect(e.message, 'Invalid data transmission');
      expect(e.fieldError('email'), 'That email address is not valid.');
    });

    test('422 mà data không phải map thì không có lỗi trường', () {
      expect(ApiException.fromStatus(422, _envelope('chuỗi')).fieldErrors, isEmpty);
    });
  });

  group('BaseResponse.envelopeOf', () {
    test('chỉ nhận lớp data có khoá success', () {
      expect(BaseResponse.envelopeOf(_envelope(1)), containsPair('success', 0));
      expect(
        BaseResponse.envelopeOf({
          'data': {'id': 1},
        }),
        isNull,
      );
      expect(BaseResponse.envelopeOf([1, 2]), isNull);
      expect(BaseResponse.envelopeOf(null), isNull);
    });
  });

  group('ApiPage', () {
    test('trang cuối thì hết, thiếu số thì mặc định 1', () {
      final ApiPage<int> page = ApiPage.fromJson({'data': null}, (Map<String, dynamic> m) => m['id'] as int);
      expect(page.items, isEmpty);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.hasMore, isFalse);
      expect(page.perPage, isNull);
    });

    test('đọc số dạng chuỗi của Laravel', () {
      final ApiPage<int> page = ApiPage.fromJson({
        'data': const [],
        'current_page': '2',
        'last_page': 2,
        'per_page': '15',
      }, (Map<String, dynamic> m) => 0);
      expect(page.currentPage, 2);
      expect(page.perPage, 15);
      expect(page.hasMore, isFalse);
    });
  });

  test('toString có loại, mã và câu báo', () {
    expect(ApiException.fromStatus(404, null).toString(), 'ApiException(ApiErrorType.notFound, 404): Data not found');
  });
}
