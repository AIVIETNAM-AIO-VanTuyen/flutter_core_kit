/// Phân loại lỗi của tầng data.
///
/// Sealed để `switch` trên nó phải đủ nhánh: quên một trường hợp là compiler báo ngay. Repository chỉ trả lỗi,
/// không tự hiện toast / dialog — màn hình đọc lỗi rồi tự chọn cách hiện.
sealed class AppFailure {
  const AppFailure({this.message});

  /// Câu server gửi (hoặc câu chung của `ApiClient`), đã sẵn để hiện. UI tự quyết có hiện hay không.
  final String? message;

  @override
  String toString() => '$runtimeType(message: $message)';
}

/// Không tới được server: máy mất mạng, quá thời gian chờ, hoặc có mạng mà server không phản hồi.
/// Lỗi tạm thời, nên cho người dùng "Thử lại".
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.message});
}

/// Lỗi phía server (5xx).
final class ServerFailure extends AppFailure {
  const ServerFailure({super.message, this.statusCode});

  final int? statusCode;
}

/// 401 — phiên hết hạn / bị thu hồi / tài khoản bị khoá. [message] là câu BE gửi.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({super.message});
}

/// 403 — đã đăng nhập nhưng không đủ quyền.
final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({super.message});
}

/// 404 — không tìm thấy tài nguyên.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.message});
}

/// 422 — dữ liệu gửi lên sai. [errors] theo tên field của Laravel.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({super.message, this.errors = const {}});

  final Map<String, List<String>> errors;

  /// Lỗi đầu tiên của một field, tiện gán `errorText`.
  String? firstErrorOf(String field) => errors[field]?.firstOrNull;
}

/// HTTP 2xx nhưng envelope báo `success != 1`: lỗi nghiệp vụ, [message] là câu BE gửi.
final class ApiFailure extends AppFailure {
  const ApiFailure({super.message});
}

/// JSON không đúng hình dạng mong đợi (thiếu khoá, sai kiểu).
final class ParseFailure extends AppFailure {
  const ParseFailure({super.message, this.cause});

  final Object? cause;
}

/// Request bị huỷ qua `CancelToken` — thường bỏ qua, không báo người dùng.
final class CancelledFailure extends AppFailure {
  const CancelledFailure({super.message});
}

/// Chưa phân loại được. Luôn kèm [cause] để còn debug.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.message, this.cause});

  final Object? cause;
}
