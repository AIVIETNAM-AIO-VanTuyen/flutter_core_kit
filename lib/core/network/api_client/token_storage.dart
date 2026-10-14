part of '../api_client.dart';

/// Lưu token đăng nhập trong Keychain (iOS) / Keystore (Android), qua [StorageHandler] (nơi định tuyến hai khoá này
/// vào kho bảo mật).
abstract final class TokenStorage {
  static const String _tokenKey = AppStorageKeys.token;

  /// Mốc hết hạn, mili giây epoch dạng chuỗi
  static const String _expireKey = AppStorageKeys.expireToken;

  /// [expiresAt] bỏ trống thì coi như không hết hạn.
  static Future<void> save(String token, {DateTime? expiresAt}) async {
    await StorageHandler.write(_tokenKey, token);
    // Thiếu mốc hết hạn thì [read] coi là chưa đăng nhập, nên luôn ghi một mốc
    final DateTime expire = expiresAt ?? DateTime(9999);
    await StorageHandler.write(_expireKey, '${expire.millisecondsSinceEpoch}');
  }

  /// Token còn hạn, hoặc `null` nếu chưa đăng nhập / đã hết hạn.
  static Future<String?> read() async {
    final String? expire = await StorageHandler.read(_expireKey);
    final int? expireMs = expire == null ? null : int.tryParse(expire);
    if (expireMs == null || clock.now().millisecondsSinceEpoch > expireMs) return null;
    final String? token = await StorageHandler.read(_tokenKey);
    return token == null || token.isEmpty ? null : token;
  }

  /// Token đang lưu, kể cả đã quá hạn: để biết máy còn phiên (dù hết hạn) hay chưa đăng nhập / đã bị xoá.
  static Future<String?> readRaw() async {
    final String? token = await StorageHandler.read(_tokenKey);
    return token == null || token.isEmpty ? null : token;
  }

  static Future<bool> get hasToken async => await read() != null;

  static Future<void> clear() async {
    await StorageHandler.remove(_tokenKey);
    await StorageHandler.remove(_expireKey);
  }
}
