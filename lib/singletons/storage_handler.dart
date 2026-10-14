import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import '../constants/storage_keys.dart';

/// Kho khoá–giá trị (chuỗi) của app.
///
/// Dữ liệu thường nằm ở shared_preferences, kho riêng [AppStorageKeys.appStore]:
/// - Android: một file SharedPreferences riêng, khoá để trần.
/// - iOS: chung `UserDefaults.standard`, phân biệt bằng tiền tố `<tên kho>.`.
///
/// Riêng token đăng nhập ([_secureKeys]) nằm trong Keychain (iOS) / Keystore (Android). Nơi gọi vẫn dùng cùng
/// [read] / [write]; định tuyến ở đây để không phải biết khoá nào nằm ở đâu.
abstract final class StorageHandler {
  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Android phải chỉ rõ backend SharedPreferences: mặc định plugin ghi sang DataStore, là kho khác hẳn.
  static SharedPreferencesAsync _store(String fileName) {
    return _isAndroid
        ? SharedPreferencesAsync(
            options: SharedPreferencesAsyncAndroidOptions(
              backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
              originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(fileName: fileName),
            ),
          )
        : SharedPreferencesAsync();
  }

  static final SharedPreferencesAsync _prefs = _store(AppStorageKeys.appStore);

  /// Khoá phải nằm trong kho bảo mật.
  static const Set<String> _secureKeys = {AppStorageKeys.token, AppStorageKeys.expireToken};

  /// iOS `first_unlock_this_device`: app chạy nền vẫn đọc được sau lần mở khoá máy đầu (FCM đổi mã cần token để gửi
  /// lên BE), và không theo bản sao lưu iCloud sang máy khác. Android để mặc định `resetOnError`: khôi phục bản sao
  /// lưu sang máy mới (mất khoá Keystore) thì kho tự xoá, người dùng đăng nhập lại thay vì lỗi mãi.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Chạy một lần mỗi phiên; mọi lệnh chờ nó xong để không đọc kho bảo mật lúc còn sót dữ liệu lần cài trước.
  static final Future<void> _ready = prepareSecureStore(prefs: _prefs, secure: _secure, prefix: _storeKey(''))
      .catchError((Object e) {
        // Chưa đặt cờ nên lần mở app sau thử lại; không được để lỗi này chặn mọi lệnh đọc / ghi
        debugPrint('[Storage] Chuẩn bị kho bảo mật lỗi: $e');
      });

  static Future<String?> read(String key) async {
    await _ready;
    if (_secureKeys.contains(key)) return _readSecure(key);
    return _prefs.getString(_storeKey(key));
  }

  /// Kho bảo mật ghi lỗi thì ném [PlatformException]: lưu token hỏng mà im lặng là tưởng đã đăng nhập; `loginService`
  /// bắt và báo lỗi đăng nhập.
  static Future<void> write(String key, String value) async {
    await _ready;
    if (_secureKeys.contains(key)) {
      await _secure.write(key: key, value: value);
      // Giá trị mới thay cho bản cũ chưa xoá được
      await _prefs.remove(_removedKey(key));
      return;
    }
    await _prefs.setString(_storeKey(key), value);
  }

  static Future<void> remove(String key) async {
    await _ready;
    if (_secureKeys.contains(key)) return _removeSecure(key);
    await _prefs.remove(_storeKey(key));
  }

  static Future<void> _removeSecure(String key) async {
    try {
      await _secure.delete(key: key);
      await _prefs.remove(_removedKey(key));
    } on PlatformException catch (e) {
      // Xoá token là để rời phiên (đăng xuất, mất phiên): ném lỗi ở đây là người dùng kẹt trong app. Xoá có thể lỗi
      // riêng trong khi đọc vẫn được → ghi dấu đã xoá ở shared_preferences để bản cũ không "sống lại" (Splash tưởng
      // còn phiên, vào Home một nhịp rồi bị 401 đá về)
      debugPrint('[Storage] Xoá $key trong kho bảo mật lỗi: $e');
      await _prefs.setString(_removedKey(key), 'true');
    }
  }

  static Future<String?> _readSecure(String key) async {
    if (await _prefs.getString(_removedKey(key)) == 'true') {
      // Lần trước xoá lỗi: thử xoá lại, được thì gỡ dấu; đằng nào bản cũ cũng không được trả ra
      await _removeSecure(key);
      return null;
    }
    try {
      return await _secure.read(key: key);
    } on PlatformException catch (e) {
      // Kho bảo mật không đọc được thì coi như chưa đăng nhập: người dùng đăng nhập lại là ghi đè được
      debugPrint('[Storage] Đọc $key trong kho bảo mật lỗi: $e');
      return null;
    }
  }

  /// Một lần cho mỗi lần cài (chưa có cờ [AppStorageKeys.secureStoreReady]) — [prefix] là tiền tố khoá của kho:
  /// xoá khoá còn sót trong [secure]. Keychain iOS không mất khi gỡ app, cài lại sẽ tự đăng nhập bằng phiên cũ;
  /// shared_preferences thì mất theo app, nên thiếu cờ nghĩa là lần cài mới.
  ///
  /// Đặt cờ sau cùng: chết giữa chừng thì lần sau chạy lại, cùng lắm phải đăng nhập lại.
  @visibleForTesting
  static Future<void> prepareSecureStore({
    required SharedPreferencesAsync prefs,
    required FlutterSecureStorage secure,
    required String prefix,
  }) async {
    final String readyKey = '$prefix${AppStorageKeys.secureStoreReady}';
    if (await prefs.getString(readyKey) == 'true') return;
    for (final String key in _secureKeys) {
      await secure.delete(key: key);
    }
    await prefs.setString(readyKey, 'true');
  }

  static String _removedKey(String key) => _storeKey('${AppStorageKeys.secureRemovedPrefix}$key');

  static String _storeKey(String key) => _isAndroid ? key : '${AppStorageKeys.appStore}.$key';
}
