import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../enums/permission_enum.dart';
import '../models/account_model.dart';

/// Tài khoản đang đăng nhập, dùng chung cả app.
///
/// Service tự cập nhật: đăng nhập / lấy hồ sơ xong thì [setAccount] + [setPermissions], đăng xuất / phiên hết thì
/// [clear]. Màn hình chỉ
/// đọc, hoặc nghe thay đổi để vẽ lại:
///
/// ```dart
/// accountStore.account?.name
/// if (accountStore.hasPermission(PermissionEnum.example)) …
/// ListenableBuilder(listenable: accountStore, builder: (_, _) => Text(accountStore.account?.name ?? ''))
/// ```
///
/// Chỉ giữ trong bộ nhớ: mở lại app thì trống, Home gọi lại `getProfileService()` để nạp (token vẫn ở TokenStorage).
final AccountStore accountStore = AccountStore._internal();

class AccountStore extends ChangeNotifier {
  AccountStore._internal();

  AccountModel? _account;

  /// `null` khi chưa đăng nhập hoặc chưa nạp hồ sơ.
  AccountModel? get account => _account;

  bool get isLoggedIn => _account != null;

  int? get userId => _account?.id;

  List<String> _permissions = const [];

  /// Mã quyền từ `GET auth/permissions`. Rỗng khi chưa nạp: chưa hiện chức năng cần quyền.
  List<String> get permissions => _permissions;

  /// `CHECK_PERMISSION=false` trong `.env` thì bỏ kiểm tra quyền (tiện thử giao diện khi tài khoản test thiếu quyền).
  /// Thiếu khoá thì **vẫn kiểm tra**: quên cấu hình không được mở hết chức năng.
  bool get checkPermission => !dotenv.isInitialized || dotenv.maybeGet('CHECK_PERMISSION') != 'false';

  /// Chỉ hiện chức năng / mở route khi tài khoản có quyền tương ứng.
  bool hasPermission(PermissionEnum permission) => !checkPermission || _permissions.contains(permission.value);

  void setAccount(AccountModel account) {
    _account = account;
    notifyListeners();
  }

  void setPermissions(List<String> permissions) {
    _permissions = List<String>.unmodifiable(permissions);
    notifyListeners();
  }

  String? _sessionNotice;

  /// Câu BE gửi khi phiên bị kết thúc từ phía server (đăng nhập ở máy khác, tài khoản bị khoá…). Màn Đăng nhập lấy
  /// ra bằng [takeSessionNotice] để hiện cho người dùng.
  String? get sessionNotice => _sessionNotice;

  void setSessionNotice(String message) {
    _sessionNotice = message;
    notifyListeners();
  }

  /// Lấy rồi xoá: mỗi câu chỉ hiện một lần.
  String? takeSessionNotice() {
    final String? notice = _sessionNotice;
    _sessionNotice = null;
    return notice;
  }

  void clear() {
    if (_account == null && _permissions.isEmpty) return;
    _account = null;
    _permissions = const [];
    notifyListeners();
  }
}
