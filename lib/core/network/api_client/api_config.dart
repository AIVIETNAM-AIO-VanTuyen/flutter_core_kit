part of '../api_client.dart';

typedef ApiTokenProvider = Future<String?> Function();
typedef ApiLanguageProvider = Future<String?> Function();
typedef ApiAppVersionProvider = Future<String> Function();

/// Cấu hình chung cho [ApiClient].
abstract final class ApiConfig {
  /// Server API, lấy từ `API_URL` trong file `.env` (nạp ở Splash). Thiếu khoá thì báo lỗi ngay thay vì
  /// lặng lẽ gọi nhầm server.
  static String get baseUrl => dotenv.get('API_URL');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// `success` của envelope khi thành công.
  static const int statusSuccess = 1;

  /// Tiền tố header `Authorization`. Backend nhận token trần (không "Bearer ") thì đặt `''`.
  static const String tokenPrefix = 'Bearer ';

  static BaseOptions baseOptions() {
    return BaseOptions(
      // Thêm '/' để path tương đối ('v1/…') nối vào sau '/api' thay vì thay thế nó
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
      // Để mọi mã HTTP về [ApiException] → [BaseResponse] xử lý thống nhất (cần đọc body lỗi 422…)
      validateStatus: (int? status) => status != null && status >= 200 && status < 300,
    );
  }

  /// Ngôn ngữ đang chọn, gửi ở header `language`. `null` thì không gửi.
  static Future<String?> readLanguage() => StorageHandler.read(AppStorageKeys.language);

  /// Header `X-App-Version`: `version` trong pubspec (`1.2.0`, không kèm build number), để BE chặn / cảnh báo bản cũ.
  /// [PackageInfo.fromPlatform] tự cache sau lần đọc đầu.
  static Future<String> readAppVersion() async => (await PackageInfo.fromPlatform()).version;
}
