import 'package:flutter_core_kit/singletons/storage_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Kho bảo mật hỏng (iOS máy chưa mở khoá lần nào, Keystore lỗi…): đọc / ghi / xoá đều ném.
class _BrokenSecureStorage extends TestFlutterSecureStoragePlatform {
  _BrokenSecureStorage() : super({});

  @override
  Future<String?> read({required String key, required Map<String, String> options}) {
    throw PlatformException(code: 'errSecInteractionNotAllowed');
  }

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) {
    throw PlatformException(code: 'errSecInteractionNotAllowed');
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) {
    throw PlatformException(code: 'errSecInteractionNotAllowed');
  }
}

/// Chỉ xoá lỗi, đọc / ghi vẫn bình thường; [failDelete] tắt được để giả máy hết lỗi.
class _FlakyDeleteSecureStorage extends TestFlutterSecureStoragePlatform {
  _FlakyDeleteSecureStorage(super.data);

  bool failDelete = true;

  @override
  Future<void> delete({required String key, required Map<String, String> options}) {
    if (failDelete) throw PlatformException(code: 'KeyStoreException');
    return super.delete(key: key, options: options);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('kho bảo mật cho token', () {
    const FlutterSecureStorage secure = FlutterSecureStorage();
    late Map<String, String> keychain;

    setUp(() {
      keychain = {};
      FlutterSecureStorage.setMockInitialValues(keychain);
    });

    Future<void> prepare(SharedPreferencesAsync prefs) {
      return StorageHandler.prepareSecureStore(prefs: prefs, secure: secure, prefix: 'AppStorage.');
    }

    test('lần cài mới: dọn token còn sót trong kho bảo mật, đặt cờ, không đụng khoá thường', () async {
      final SharedPreferencesAsync prefs = SharedPreferencesAsync();
      await prefs.setString('AppStorage.language', 'en');
      keychain.addAll({'token': 'old', 'expireToken': '123'});

      await prepare(prefs);

      expect(keychain, isEmpty);
      expect(await prefs.getString('AppStorage.language'), 'en');
      expect(await prefs.getString('AppStorage.secure_store_ready'), 'true');
    });

    test('cài lại app (shared_preferences trống, Keychain còn phiên cũ): xoá phiên cũ', () async {
      keychain.addAll({'token': 'old', 'expireToken': '123', 'other_app_key': 'x'});

      await prepare(SharedPreferencesAsync());

      expect(keychain, {'other_app_key': 'x'});
    });

    test('đã có cờ thì không đụng gì nữa', () async {
      final SharedPreferencesAsync prefs = SharedPreferencesAsync();
      await prefs.setString('AppStorage.secure_store_ready', 'true');
      keychain['token'] = 'current';

      await prepare(prefs);

      expect(keychain, {'token': 'current'});
    });

    test('read / write / remove: token vào kho bảo mật, khoá khác vẫn ở shared_preferences', () async {
      await StorageHandler.write('token', 'abc');
      await StorageHandler.write('expireToken', '123');
      await StorageHandler.write('language', 'en');

      expect(keychain, {'token': 'abc', 'expireToken': '123'});
      expect(await SharedPreferencesAsync().getKeys(), isNot(contains('token')));
      expect(await StorageHandler.read('token'), 'abc');
      expect(await StorageHandler.read('language'), 'en');

      await StorageHandler.remove('token');
      expect(keychain.containsKey('token'), isFalse);
      expect(await StorageHandler.read('token'), isNull);
    });

    test('kho bảo mật đọc lỗi thì coi như chưa đăng nhập, không ném', () async {
      FlutterSecureStoragePlatform.instance = _BrokenSecureStorage();
      expect(await StorageHandler.read('token'), isNull);
    });

    test('kho bảo mật xoá lỗi thì không ném (đăng xuất / mất phiên vẫn rời được phiên), ghi lỗi thì ném', () async {
      FlutterSecureStoragePlatform.instance = _BrokenSecureStorage();
      await StorageHandler.remove('token');
      await StorageHandler.remove('expireToken');
      expect(StorageHandler.write('token', 'abc'), throwsA(isA<PlatformException>()));
    });

    test('xoá lỗi mà đọc vẫn được: token cũ không "sống lại", hết lỗi thì xoá hẳn, ghi mới thì đọc lại được', () async {
      final _FlakyDeleteSecureStorage flaky = _FlakyDeleteSecureStorage(keychain);
      FlutterSecureStoragePlatform.instance = flaky;
      await StorageHandler.write('token', 'old');

      await StorageHandler.remove('token');
      expect(keychain['token'], 'old');
      expect(await StorageHandler.read('token'), isNull);

      // Máy hết lỗi: lần đọc sau xoá hẳn bản cũ
      flaky.failDelete = false;
      expect(await StorageHandler.read('token'), isNull);
      expect(keychain.containsKey('token'), isFalse);

      // Đăng nhập lại khi dấu đã xoá vẫn còn (xoá vẫn lỗi): token mới đọc được
      flaky.failDelete = true;
      await StorageHandler.write('token', 'old');
      await StorageHandler.remove('token');
      await StorageHandler.write('token', 'new');
      expect(await StorageHandler.read('token'), 'new');
    });
  });
}
