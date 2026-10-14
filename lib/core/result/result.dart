import 'app_failure.dart';

export 'app_failure.dart';

/// Kết quả của một thao tác có thể thất bại: [Ok] hoặc [Err].
///
/// Service trả [Result] thay vì ném lỗi, nên màn gọi bắt buộc phải xử lý cả nhánh lỗi:
///
/// ```dart
/// switch (await loginService(email: email, password: password)) {
///   case Ok(:final AccountModel value): …
///   case Err(failure: NetworkFailure()): …
///   case Err(:final AppFailure failure): …
/// }
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(AppFailure failure) = Err<T>;

  /// Chạy [body]; JSON sai hình dạng (TypeError, FormatException) thành [ParseFailure].
  ///
  /// Dùng cho đoạn đọc JSON — nơi dễ ném lỗi kiểu nhất. Lỗi khác vẫn nổi lên vì đó là lỗi code, không phải dữ liệu.
  static Result<T> guard<T>(T Function() body) {
    try {
      return Ok<T>(body());
    } on TypeError catch (e) {
      return Err<T>(ParseFailure(message: '$e', cause: e));
    } on FormatException catch (e) {
      return Err<T>(ParseFailure(message: e.message, cause: e));
    }
  }

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Giá trị nếu thành công, ngược lại `null`.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final T value) => value,
    Err<T>() => null,
  };

  /// Lỗi nếu thất bại, ngược lại `null`.
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final AppFailure failure) => failure,
  };

  /// Biến đổi giá trị bên trong, giữ nguyên lỗi. [transform] chạy qua [guard].
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final T value) => Result.guard<R>(() => transform(value)),
    Err<T>(:final AppFailure failure) => Err<R>(failure),
  };

  /// Như [map] nhưng [transform] tự trả [Result].
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(:final T value) => transform(value),
    Err<T>(:final AppFailure failure) => Err<R>(failure),
  };

  /// Gộp hai nhánh về một giá trị.
  R fold<R>({required R Function(T value) ok, required R Function(AppFailure failure) err}) => switch (this) {
    Ok<T>(:final T value) => ok(value),
    Err<T>(:final AppFailure failure) => err(failure),
  };

  /// Giá trị nếu thành công, ngược lại giá trị thay thế tính từ lỗi.
  T getOrElse(T Function(AppFailure failure) orElse) => switch (this) {
    Ok<T>(:final T value) => value,
    Err<T>(:final AppFailure failure) => orElse(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Ok<T> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok<T>, value);
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'Err($failure)';

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Err<T> && other.failure == failure);

  @override
  int get hashCode => Object.hash(Err<T>, failure);
}
