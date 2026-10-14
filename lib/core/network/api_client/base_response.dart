part of '../api_client.dart';

/// Phản hồi một lần gọi API, [ApiClient] trả cho repository: không ném lỗi, chỉ giữ JSON thô; service đọc [body] /
/// [errors] thành interface bằng `BaseServices.from`.
///
/// Envelope mặc định: `{"data": {"success": 1, "message": "…", "data": <payload>}}`. Endpoint không bọc envelope thì
/// [body] là nguyên JSON object. Backend dùng dạng khác thì sửa [fromHttp] và [envelopeOf].
class BaseResponse {
  const BaseResponse({this.statusCode, this.body, this.raw, this.message, this.failure, this.errors});

  /// HTTP 2xx. Envelope báo `success != 1` thì vẫn là lỗi ([isFailSuccess]), giữ nguyên [body].
  factory BaseResponse.fromHttp(int? statusCode, Object? raw) {
    // 2xx mà body không phải JSON object: trang HTML của wifi có cổng đăng nhập / proxy / trang bảo trì, hoặc body
    // rỗng do BE cấu hình sai. Không chặn thì API không đọc body (đăng xuất…) tưởng BE đã nhận.
    // 204 No Content thì đúng là không có body
    if (raw is! Map && statusCode != 204) {
      return BaseResponse(
        statusCode: statusCode,
        raw: raw,
        message: 'Something went wrong, please try again',
        failure: const UnknownFailure(message: 'Something went wrong, please try again'),
      );
    }
    final Map<String, dynamic>? envelope = envelopeOf(raw);
    final Object? rawMessage = envelope?['message'];
    final String? message = rawMessage is String && rawMessage.isNotEmpty ? rawMessage : null;
    final bool failed = envelope != null && _successOf(envelope['success']) != ApiConfig.statusSuccess;
    return BaseResponse(
      statusCode: statusCode,
      // Endpoint không theo envelope thì body là nguyên JSON object; 204 thì null
      body: envelope ?? (raw is Map<String, dynamic> ? raw : null),
      raw: raw,
      message: failed ? message ?? 'Something went wrong, please try again' : message,
      failure: failed ? ApiFailure(message: message ?? 'Something went wrong, please try again') : null,
    );
  }

  /// Không có response 2xx: mất mạng, quá giờ, HTTP lỗi. [message] đã sẵn để hiện.
  factory BaseResponse.fromException(ApiException e) {
    final Object? data = e.data;
    return BaseResponse(
      statusCode: e.statusCode,
      message: e.message,
      failure: e.toFailure(),
      errors: e.type == ApiErrorType.validation && data is Map<String, dynamic> ? data : null,
    );
  }

  /// `null` khi không tới được server (mất mạng, quá giờ).
  final int? statusCode;

  /// Lớp chứa `success` (`{"success", "message", "data", …}`). `null` khi lỗi HTTP.
  final Map<String, dynamic>? body;

  /// Nguyên body server gửi, khi cần đọc thứ ngoài [body].
  final Object? raw;

  /// Câu server gửi (hoặc câu mặc định theo loại lỗi), đã sẵn để hiện.
  final String? message;

  /// Loại lỗi; `null` khi thành công.
  final AppFailure? failure;

  /// Lỗi 422 thô theo từng ô: `{"email": "That email address is not valid."}`. `null` với mọi trường hợp khác.
  final Map<String, dynamic>? errors;

  int? get success => _successOf(body?['success']);

  /// BE thường trả số; vài endpoint có thể trả `true` / `"1"`, đọc cả hai thay vì coi là lỗi hay ném khi ép kiểu
  static int? _successOf(Object? value) => switch (value) {
    final int v => v,
    true => 1,
    false => 0,
    final String v => int.tryParse(v),
    _ => null,
  };

  /// Phần `data` trong envelope.
  Object? get data => body?['data'];

  bool get isSuccessApi => failure == null;

  /// HTTP 200 nhưng `success != 1` (vd "Wrong email or password.").
  bool get isFailSuccess => failure is ApiFailure;
  bool get isUnprocessableEntity => failure is ValidationFailure;
  bool get isUnauthorized => failure is UnauthorizedFailure;
  bool get isCodeForbidden => failure is ForbiddenFailure;
  bool get isNotFound => failure is NotFoundFailure;
  bool get isServerError => failure is ServerFailure;
  bool get isNetworkError => failure is NetworkFailure;
  bool get isCancelled => failure is CancelledFailure;

  /// Lớp `data` có khoá `success` bên trong body, nếu body theo envelope.
  static Map<String, dynamic>? envelopeOf(Object? body) {
    if (body is! Map) return null;
    final Object? inner = body['data'];
    if (inner is Map<String, dynamic> && inner.containsKey('success')) return inner;
    return null;
  }

  /// Chỉ để debug. Token / mật khẩu trong [body] đã bị che.
  @override
  String toString() {
    final String json = const JsonEncoder.withIndent('  ').convert(_maskSecrets(body ?? raw)).replaceAll('\n', '\n  ');
    return 'BaseResponse(\n'
        '  statusCode: $statusCode,\n'
        '  success: $success,\n'
        '  message: $message,\n'
        '  failure: ${failure?.runtimeType},\n'
        '  errors: $errors,\n'
        '  body: $json,\n'
        ')';
  }
}
