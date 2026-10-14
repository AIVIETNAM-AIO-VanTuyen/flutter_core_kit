import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../core/network/api_client.dart';
import '../core/result/result.dart';
import '../helpers/push_token.dart';
import '../models/account_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/interfaces/login_response_interface.dart';
import '../repositories/interfaces/permissions_response_interface.dart';
import '../repositories/interfaces/profile_response_interface.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../singletons/account_store.dart';
import 'base_services.dart';

/// Kiểu của [loginService], để màn Đăng nhập nhận bản giả trong test.
typedef LoginService =
    Future<BaseServices<AccountModel, LoginErrorForm>> Function({required String email, required String password});

/// Kiểu của [getProfileService], để màn hình nhận bản giả trong test.
typedef ProfileService = Future<BaseServices<AccountModel, void>> Function();

/// Đăng nhập. Thành công thì token đã được lưu, hồ sơ và quyền đã vào [accountStore]. Không hiện thông báo: màn
/// hình tự chọn chỗ hiện lỗi.
///
/// Lỗi: [ValidationFailure] (422, lỗi từng ô ở [BaseServices.error]) · [ApiFailure] (`message` là câu BE gửi) ·
/// [NetworkFailure] · [ServerFailure] · [ParseFailure] (response thiếu token / user) · [UnknownFailure] (Keychain /
/// Keystore không ghi được token).
///
/// [pushToken]: lấy mã FCM gửi kèm; test truyền bản giả.
Future<BaseServices<AccountModel, LoginErrorForm>> loginService({
  required String email,
  required String password,
  Future<String?> Function() pushToken = fetchPushToken,
}) async {
  final BaseServices<LoginResponseInterface, LoginErrorForm> login = BaseServices.from(
    await loginApi(email: email, password: password, deviceToken: await pushToken()),
    // `token` và `user` nằm cạnh `success` nên parser nhận cả body, không chỉ `data`
    parser: LoginResponseInterface.fromJson,
    errorParser: LoginErrorForm.fromJson,
  );
  final BaseServices<AccountModel, LoginErrorForm> account = login.map(
    (LoginResponseInterface data) => AccountModel(data: data.user),
  );
  if ((login.data, account.data) case (final LoginResponseInterface data, final AccountModel user)) {
    try {
      await TokenStorage.save(data.token.accessToken, expiresAt: data.token.expiresAt);
    } on PlatformException catch (e) {
      // Keystore hỏng (đổi mã khoá màn hình, ROM lạ), Keychain chưa mở khoá: không lưu được phiên thì vào app cũng
      // bị đá ra ngay. Báo lỗi để màn đăng nhập cho thử lại thay vì kẹt ở trạng thái đang tải; dọn phần đã ghi
      await TokenStorage.clear();
      return BaseServices<AccountModel, LoginErrorForm>.failure(
        UnknownFailure(message: 'Something went wrong, please try again', cause: e),
      );
    }
    accountStore.setAccount(user);
    // Lấy quyền ngay sau đăng nhập. Lỗi thì vẫn cho vào app, chưa hiện chức năng cần quyền
    await getPermissionsService();
  }
  return account;
}

/// Đăng xuất. **Luôn** xoá token và [accountStore] trên máy, kể cả khi API lỗi: người dùng bấm đăng xuất thì phải ra
/// khỏi app ngay, không kẹt lại vì mất mạng.
///
/// Kết quả chỉ để biết server đã thu hồi phiên hay chưa (mất mạng thì token cũ còn sống tới khi hết hạn, BE thu hồi
/// ở lần đăng nhập sau); màn gọi không cần xử lý lỗi.
Future<BaseServices<void, void>> logoutService() async {
  final BaseResponse response = await logoutApi();
  await TokenStorage.clear();
  accountStore.clear();
  // 401: token đã hết hạn / bị thu hồi, phía server cũng không còn phiên để huỷ
  if (response.isSuccessApi || response.isUnauthorized) return const BaseServices<void, void>.success(null);
  return BaseServices<void, void>.failure(response.failure!);
}

/// Hồ sơ người đang đăng nhập (`GET auth/me`). Thành công thì cập nhật [accountStore] và lấy lại quyền.
///
/// - Chưa đăng nhập (không có token, hoặc token trên máy đã hết hạn): trả [UnauthorizedFailure], không gọi API.
/// - BE trả 401 (token bị thu hồi, đăng nhập ở máy khác…): xoá token và [accountStore] rồi trả [UnauthorizedFailure],
///   để màn gọi đưa về Đăng nhập.
Future<BaseServices<AccountModel, void>> getProfileService() async {
  // Không có token thì BE chắc chắn trả 401: khỏi tốn một lượt mạng
  if (!await TokenStorage.hasToken) {
    return const BaseServices<AccountModel, void>.failure(UnauthorizedFailure(message: 'Please log in'));
  }

  final BaseResponse response = await getProfileApi();
  if (response.isUnauthorized) {
    await TokenStorage.clear();
    accountStore.clear();
  }
  final BaseServices<ProfileResponseInterface, void> profile = BaseServices.from(
    response,
    parser: ProfileResponseInterface.fromJson,
  );
  final BaseServices<AccountModel, void> account = profile.map(
    (ProfileResponseInterface data) => AccountModel(data: data.user),
  );
  if (account.data case final AccountModel user) {
    accountStore.setAccount(user);
    // Mở lại app với phiên còn hạn cũng lấy lại quyền
    await getPermissionsService();
  }
  return account;
}

/// Danh sách quyền. Thành công thì cập nhật [accountStore]; lỗi thì giữ quyền đang có.
Future<BaseServices<List<String>, void>> getPermissionsService() async {
  final BaseServices<PermissionsResponseInterface, void> permissions = BaseServices.from(
    await getPermissionsApi(),
    parser: PermissionsResponseInterface.fromJson,
  );
  if (permissions.data case final PermissionsResponseInterface data) accountStore.setPermissions(data.permissions);
  return permissions.map((PermissionsResponseInterface data) => data.permissions);
}

/// Phiên bị kết thúc từ phía server: xoá phiên trên máy, về Đăng nhập và để màn Đăng nhập hiện nguyên văn câu BE
/// gửi ([message]: đăng nhập ở máy khác, tài khoản bị khoá…).
Future<void> expireSession(String message) async {
  await TokenStorage.clear();
  accountStore.clear();
  accountStore.setSessionNotice(message);
  AppNavigator.go(AppRoutes.login);
}

StreamSubscription<String>? _pushTokenRefresh;

/// Gắn các việc chạy nền của phiên đăng nhập. Gọi một lần sau khi đã nạp `.env` và dựng Firebase (Splash):
/// - 401 từ bất kỳ API nào → [expireSession].
/// - Firebase đổi mã FCM khi đang đăng nhập → gửi mã mới cho BE ([registerDeviceService]).
///
/// [listenPushToken] `false` khi Firebase không dựng được (gọi `FirebaseMessaging.instance` sẽ ném).
void startSessionHandling({bool listenPushToken = true}) {
  ApiClient.instance.onUnauthorized = expireSession;
  _pushTokenRefresh?.cancel();
  if (listenPushToken) {
    _pushTokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(registerDeviceService);
  }
}

/// Gửi mã FCM mới cho BE. Chưa đăng nhập thì bỏ qua: lần đăng nhập sau đã gửi kèm `device_token`.
Future<BaseServices<void, void>> registerDeviceService(String deviceToken) async {
  if (!await TokenStorage.hasToken) {
    return const BaseServices<void, void>.failure(UnauthorizedFailure(message: 'Please log in'));
  }
  final BaseResponse response = await registerDeviceApi(deviceToken);
  if (response.failure case final AppFailure failure) return BaseServices<void, void>.failure(failure);
  return const BaseServices<void, void>.success(null);
}
