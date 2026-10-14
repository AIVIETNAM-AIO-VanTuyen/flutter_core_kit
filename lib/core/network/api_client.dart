import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../constants/storage_keys.dart';
import '../../helpers/network.dart';
import '../../singletons/storage_handler.dart';
import '../result/result.dart';

part 'api_client/api_config.dart';
part 'api_client/api_exception.dart';
part 'api_client/api_failure.dart';
part 'api_client/api_page.dart';
part 'api_client/base_response.dart';
part 'api_client/interceptors.dart';
part 'api_client/token_storage.dart';

/// Cổng gọi API backend.
///
/// - Base URL lấy từ `API_URL` trong `.env`. Token lấy từ [TokenStorage] (Keychain / Keystore), ngôn ngữ từ
///   [AppStorageKeys.language].
/// - Mọi hàm trả [BaseResponse] và **không ném lỗi**: mất mạng, HTTP lỗi, `success != 1` đều nằm trong
///   [BaseResponse.failure]. Không tự hiện dialog — màn gọi tự quyết cách hiện lỗi.
/// - Không đọc JSON thành model: repository trả [BaseResponse] nguyên, service đọc bằng `BaseServices.from`.
/// - 401 → gọi [onUnauthorized] một lần, kèm câu BE gửi (app xoá phiên, về Đăng nhập).
///
/// Backend khác định dạng envelope / header thì sửa ở [ApiConfig], [BaseResponse.fromHttp] và `_AuthInterceptor`.
///
/// ```dart
/// Future<BaseResponse> loginApi({required String email, required String password}) {
///   return ApiClient.instance.post('v2/login', body: {'email': email, 'password': password});
/// }
/// ```
class ApiClient {
  ApiClient({
    Dio? dio,
    ApiTokenProvider? tokenProvider,
    ApiTokenProvider? storedTokenProvider,
    ApiLanguageProvider? languageProvider,
    ApiAppVersionProvider? appVersionProvider,
  }) : dio = dio ?? Dio(ApiConfig.baseOptions()) {
    this.dio.interceptors.addAll([
      _AuthInterceptor(
        tokenProvider: tokenProvider ?? TokenStorage.read,
        languageProvider: languageProvider ?? ApiConfig.readLanguage,
        appVersionProvider: appVersionProvider ?? ApiConfig.readAppVersion,
      ),
      _UnauthorizedInterceptor(
        storedTokenProvider: storedTokenProvider ?? TokenStorage.readRaw,
        notify: (String message) {
          final void Function(String message)? handler = onUnauthorized;
          handler?.call(message);
          return handler != null;
        },
      ),
      if (kDebugMode) _LogInterceptor(),
    ]);
  }

  static ApiClient? _instance;

  /// Bản dùng chung cho cả app. Test thay bằng `ApiClient.instance = ApiClient(dio: …)`.
  static ApiClient get instance => _instance ??= ApiClient();
  @visibleForTesting
  static set instance(ApiClient client) => _instance = client;

  final Dio dio;

  /// Gọi khi server trả 401 (token hết hạn / bị thu hồi / tài khoản bị khoá), kèm câu BE gửi.
  void Function(String message)? onUnauthorized;

  /// Đặt `true` trong `Options.extra` để 401 của request đó không gọi [onUnauthorized] (vd đăng xuất: 401 nghĩa là
  /// phiên đã hết sẵn, không phải sự cố cần báo).
  static const String skipUnauthorized = 'skipUnauthorized';

  Future<BaseResponse> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request(path, method: 'GET', query: query, cancelToken: cancelToken, options: options);
  }

  Future<BaseResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request(
      path,
      method: 'POST',
      body: body,
      query: query,
      cancelToken: cancelToken,
      options: options,
    );
  }

  Future<BaseResponse> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request(
      path,
      method: 'PUT',
      body: body,
      query: query,
      cancelToken: cancelToken,
      options: options,
    );
  }

  Future<BaseResponse> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request(
      path,
      method: 'PATCH',
      body: body,
      query: query,
      cancelToken: cancelToken,
      options: options,
    );
  }

  Future<BaseResponse> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request(
      path,
      method: 'DELETE',
      body: body,
      query: query,
      cancelToken: cancelToken,
      options: options,
    );
  }

  /// Gốc của mọi lời gọi: gửi, bóc envelope, đổi lỗi thành [BaseResponse.failure].
  Future<BaseResponse> request(
    String path, {
    required String method,
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
  }) async {
    final Response<Object?> response;
    try {
      response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: (options ?? Options()).copyWith(method: method),
      );
    } on DioException catch (e) {
      // Chỗ duy nhất bắt lỗi mạng / HTTP: từ đây trở lên chỉ hỏi isSuccessApi / failure
      return BaseResponse.fromException(ApiException.fromDio(e));
    }
    return BaseResponse.fromHttp(response.statusCode, response.data);
  }
}
