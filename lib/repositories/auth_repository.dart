import 'package:dio/dio.dart' show Options;

import '../core/network/api_client.dart';

// Mẫu: path và tham số theo backend thật. Mỗi hàm một API, không ném lỗi, trả JSON để service đọc.

/// `POST auth/login`.
///
/// [deviceToken]: mã FCM của máy, để BE gửi push tới đúng máy này.
Future<BaseResponse> loginApi({required String email, required String password, String? deviceToken}) {
  return ApiClient.instance.post(
    'auth/login',
    body: {'email': email, 'password': password, 'device_token': ?deviceToken},
    // Chờ ngắn hơn mặc định (30): mạng chập chờn thì nút đăng nhập quay tối đa ~30 giây (connect 15 + 15) rồi báo lỗi,
    // thay vì ~45 giây
    //
    // 401 của login là sai thông tin đăng nhập, không phải mất phiên (máy có thể còn token cũ đã hết hạn trong kho)
    options: Options(
      sendTimeout: _loginTimeout,
      receiveTimeout: _loginTimeout,
      extra: {ApiClient.skipUnauthorized: true},
    ),
  );
}

const Duration _loginTimeout = Duration(seconds: 15);

/// `POST auth/logout`: BE thu hồi phiên và gỡ máy nhận push.
Future<BaseResponse> logoutApi() {
  return ApiClient.instance.post(
    'auth/logout',
    // 401 lúc đăng xuất nghĩa là phiên đã hết sẵn: không kích hoạt luồng "phiên hết hạn"
    options: Options(extra: {ApiClient.skipUnauthorized: true}),
  );
}

/// `GET auth/me`: hồ sơ người đang đăng nhập. Token do interceptor gắn từ [TokenStorage].
Future<BaseResponse> getProfileApi() {
  return ApiClient.instance.get('auth/me');
}

/// `GET auth/permissions`: mã quyền của tài khoản.
Future<BaseResponse> getPermissionsApi() {
  return ApiClient.instance.get('auth/permissions');
}

/// `POST auth/devices`: gửi lại mã FCM mới khi Firebase đổi mã.
Future<BaseResponse> registerDeviceApi(String deviceToken) {
  return ApiClient.instance.post('auth/devices', body: {'device_token': deviceToken});
}
