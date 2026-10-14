part of '../api_client.dart';

/// Loại lỗi của [ApiException] → [AppFailure] mà service / UI dùng.
extension ApiFailureX on ApiException {
  AppFailure toFailure() => switch (type) {
    ApiErrorType.noInternet || ApiErrorType.timeout || ApiErrorType.connection => NetworkFailure(message: message),
    ApiErrorType.cancelled => CancelledFailure(message: message),
    ApiErrorType.unauthorized => UnauthorizedFailure(message: message),
    ApiErrorType.forbidden => ForbiddenFailure(message: message),
    ApiErrorType.notFound => NotFoundFailure(message: message),
    ApiErrorType.validation => ValidationFailure(message: message, errors: fieldErrors),
    ApiErrorType.server => ServerFailure(message: message, statusCode: statusCode),
    ApiErrorType.business => ApiFailure(message: message),
    ApiErrorType.unknown => UnknownFailure(message: message, cause: data),
  };
}
