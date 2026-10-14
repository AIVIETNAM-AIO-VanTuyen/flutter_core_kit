import '../core/network/api_client.dart';
import '../core/result/result.dart';

/// Kết quả service trả lên UI.
///
/// - [T]: [data] là model khi thành công.
/// - [E]: [error] là form lỗi 422 theo từng ô (vd `LoginErrorForm`); `void` nếu API không có lỗi theo ô.
///
/// Khác [BaseResponse] (repository → service, JSON thô): ở đây đã đọc xong, chỉ còn thứ UI cần.
///
/// ```dart
/// // service
/// final BaseServices<LoginResponseInterface, LoginErrorForm> login = BaseServices.from(
///   await loginApi(...),
///   parser: LoginResponseInterface.fromJson,
///   errorParser: LoginErrorForm.fromJson,
/// );
/// return login.map((LoginResponseInterface data) => AccountModel(data: data.user));
///
/// // UI
/// if (response.isSuccess) return goHome(response.data!);
/// if (response.error case final LoginErrorForm form) _emailError = form.emailError;
/// ```
class BaseServices<T, E> {
  const BaseServices.success(T this.data) : failure = null, error = null;

  const BaseServices.failure(AppFailure this.failure, {this.error}) : data = null;

  /// Đọc [response] (JSON thô từ repository):
  /// - thành công: [parser] đọc `body` thành [T]; JSON sai hình dạng → [ParseFailure].
  /// - 422: [errorParser] đọc lỗi từng ô thành [E]; form hỏng thì bỏ qua, [failure] vẫn là [ValidationFailure].
  /// - lỗi khác: giữ nguyên [BaseResponse.failure].
  factory BaseServices.from(
    BaseResponse response, {
    required T Function(Map<String, dynamic> body) parser,
    E Function(Map<String, dynamic> errors)? errorParser,
  }) {
    if (response.failure case final AppFailure failure) {
      final Map<String, dynamic>? errors = response.errors;
      return BaseServices<T, E>.failure(
        failure,
        error: errors != null && errorParser != null ? Result.guard<E>(() => errorParser(errors)).valueOrNull : null,
      );
    }
    // `body` null (endpoint không trả object) cũng là JSON sai hình dạng: `!` ném TypeError, guard bắt
    return switch (Result.guard<T>(() => parser(response.body!))) {
      Ok<T>(:final T value) => BaseServices<T, E>.success(value),
      Err<T>(:final AppFailure failure) => BaseServices<T, E>.failure(failure),
    };
  }

  /// Model; `null` khi lỗi.
  final T? data;

  /// Loại lỗi; `null` khi thành công.
  final AppFailure? failure;

  /// Form lỗi 422; `null` với mọi trường hợp khác.
  final E? error;

  bool get isSuccess => failure == null;

  /// Câu lỗi đã sẵn để hiện (câu BE gửi, hoặc câu mặc định theo loại lỗi).
  String? get message => failure?.message;

  /// HTTP 200 nhưng `success != 1` (vd "Wrong email or password.").
  bool get isFailSuccess => failure is ApiFailure;
  bool get isUnprocessableEntity => failure is ValidationFailure;
  bool get isUnauthorized => failure is UnauthorizedFailure;
  bool get isNetworkError => failure is NetworkFailure;
  bool get isServerError => failure is ServerFailure;
  bool get isParseError => failure is ParseFailure;

  /// Đổi [data] (vd interface → model), giữ nguyên lỗi và [error].
  BaseServices<R, E> map<R>(R Function(T data) transform) {
    if (failure case final AppFailure failure) return BaseServices<R, E>.failure(failure, error: error);
    return BaseServices<R, E>.success(transform(data as T));
  }

  @override
  String toString() => isSuccess ? 'BaseServices.success($data)' : 'BaseServices.failure($failure, error: $error)';
}
