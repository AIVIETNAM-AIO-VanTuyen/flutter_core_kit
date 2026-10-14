part of '../api_client.dart';

enum ApiErrorType {
  /// Máy không có mạng
  noInternet,

  /// Có mạng nhưng không tới được server / quá thời gian chờ
  timeout,
  connection,

  /// Request bị huỷ qua `CancelToken` — thường bỏ qua, không báo người dùng
  cancelled,

  unauthorized,
  forbidden,
  notFound,

  /// 422: dữ liệu gửi lên sai, xem [ApiException.fieldErrors]
  validation,

  /// 5xx
  server,

  /// HTTP 2xx nhưng envelope báo `success != 1`
  business,

  unknown,
}

/// Lỗi mạng / HTTP đã phân loại. [ApiClient] không ném nó ra ngoài mà đổi thành [BaseResponse.failure]
/// ([ApiFailureX.toFailure]). [message] đã sẵn để hiện cho người dùng.
class ApiException implements Exception {
  const ApiException(this.type, this.message, {this.statusCode, this.fieldErrors = const {}, this.data});

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorType.cancelled, 'Cancelled');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(ApiErrorType.timeout, 'Connection timed out, please try again');
      case DioExceptionType.connectionError:
        // Phân biệt mất mạng với có mạng mà server không phản hồi
        return isHasNetwork
            ? const ApiException(ApiErrorType.connection, 'System under maintenance, please try again later')
            : const ApiException(ApiErrorType.noInternet, 'Access the Internet to continue');
      case DioExceptionType.badResponse:
        final Response<dynamic>? response = e.response;
        return ApiException.fromStatus(
          response?.statusCode,
          response?.data,
          session: e.requestOptions.extra[ApiClient.skipUnauthorized] != true,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (!isHasNetwork) return const ApiException(ApiErrorType.noInternet, 'Access the Internet to continue');
        // Lỗi mạng sau khi đã mở kết nối (đứt lúc đang nhận, bắt tay TLS hỏng, wifi công cộng chèn chứng chỉ) Dio
        // không xếp vào connectionError, mà máy vẫn báo có mạng: phải xem lỗi gốc để màn hiện đúng lỗi kết nối
        final Object? cause = e.error;
        if (e.type == DioExceptionType.badCertificate ||
            cause is SocketException ||
            cause is HttpException ||
            cause is TlsException) {
          return const ApiException(ApiErrorType.connection, 'System under maintenance, please try again later');
        }
        return ApiException(ApiErrorType.unknown, 'Something went wrong, please try again', data: cause);
    }
  }

  /// Lỗi theo mã HTTP; lấy `message` / lỗi từng trường trong envelope nếu server gửi.
  ///
  /// [session] `false` khi request không thuộc phiên đăng nhập ([ApiClient.skipUnauthorized], vd đăng nhập): 401
  /// không kèm câu thì không nói "hết phiên" với người chưa có phiên.
  factory ApiException.fromStatus(int? status, Object? body, {bool session = true}) {
    // Lỗi 422 có thể bọc `{data: {status, message, data}}`, không có `success` nên envelopeOf() bỏ qua; vẫn phải
    // đọc lớp đó để lấy lỗi từng ô
    final Map<String, dynamic>? envelope =
        BaseResponse.envelopeOf(body) ?? (body is Map && body['data'] is Map<String, dynamic> ? body['data'] : null);
    final Object? rawMessage = envelope?['message'] ?? (body is Map ? body['message'] : null);
    final String? serverMessage = rawMessage is String && rawMessage.isNotEmpty ? rawMessage : null;
    final Object? data = envelope?['data'];

    final (ApiErrorType type, String fallback) = switch (status) {
      // BE quên gửi message thì vẫn hiện đúng câu hết phiên
      401 when session => (ApiErrorType.unauthorized, 'Login session has expired'),
      401 => (ApiErrorType.unauthorized, 'Something went wrong, please try again'),
      403 => (ApiErrorType.forbidden, 'You have no permission'),
      404 => (ApiErrorType.notFound, 'Data not found'),
      422 => (ApiErrorType.validation, 'Please check your input'),
      final int s when s >= 500 => (ApiErrorType.server, 'System under maintenance, please try again later'),
      _ => (ApiErrorType.unknown, 'Something went wrong, please try again'),
    };
    // 5xx: không đưa thông báo kỹ thuật của server ra người dùng
    final String message = type == ApiErrorType.server ? fallback : serverMessage ?? fallback;
    return ApiException(
      type,
      message,
      statusCode: status,
      fieldErrors: type == ApiErrorType.validation ? _fieldErrors(data) : const {},
      data: data,
    );
  }

  final ApiErrorType type;
  final String message;
  final int? statusCode;

  /// Lỗi 422 theo trường: `{'email': ['Email không hợp lệ']}` (Laravel). Gán vào `errorText` của field.
  final Map<String, List<String>> fieldErrors;

  /// `data` thô trong envelope lỗi (hoặc lỗi gốc), khi cần đọc thêm.
  final Object? data;

  bool get isCancelled => type == ApiErrorType.cancelled;

  /// Lỗi tạm thời, nên cho người dùng nút "Thử lại"
  bool get isRetryable =>
      type == ApiErrorType.noInternet ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.connection ||
      type == ApiErrorType.server;

  /// Lỗi đầu tiên của một trường, tiện gán `errorText`.
  String? fieldError(String field) => fieldErrors[field]?.firstOrNull;

  static Map<String, List<String>> _fieldErrors(Object? data) {
    if (data is! Map) return const {};
    final Map<String, List<String>> result = {};
    for (final MapEntry<dynamic, dynamic> entry in data.entries) {
      final Object? value = entry.value;
      if (value is List) {
        result['${entry.key}'] = [for (final Object? v in value) '$v'];
      } else if (value != null) {
        result['${entry.key}'] = ['$value'];
      }
    }
    return result;
  }

  @override
  String toString() => 'ApiException($type, $statusCode): $message';
}
