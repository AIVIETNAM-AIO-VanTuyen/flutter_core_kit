/// Khoá lưu trong shared_preferences (qua `StorageHandler`).
abstract final class AppStorageKeys {
  /// Kho riêng của app (tên file SharedPreferences trên Android, tiền tố `AppStorage.` trên iOS).
  static const String appStore = 'AppStorage';

  /// Token đăng nhập và mốc hết hạn (mili giây epoch dạng chuỗi). Nằm trong Keychain / Keystore chứ không ở
  /// shared_preferences, xem `StorageHandler`.
  static const String token = 'token';
  static const String expireToken = 'expireToken';

  /// `'true'` khi kho bảo mật đã sẵn sàng cho lần cài này (đã dọn Keychain còn sót từ lần cài trước).
  static const String secureStoreReady = 'secure_store_ready';

  /// Tiền tố dấu "đã xoá" của khoá bảo mật (`secure_removed_token`): Keychain / Keystore xoá lỗi thì ghi dấu này, đọc
  /// khoá đó coi như không còn.
  static const String secureRemovedPrefix = 'secure_removed_';

  /// Ngôn ngữ đang chọn, `ApiClient` gửi ở header `language`.
  static const String language = 'language';
}
