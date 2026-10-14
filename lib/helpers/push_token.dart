import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Mã thiết bị nhận push (FCM token), gửi kèm khi đăng nhập (`device_token`).
///
/// iOS chỉ cấp FCM token sau khi nhận được APNs token, gọi `getToken()` sớm hơn sẽ ném apns-token-not-set: chờ
/// APNs tối đa ~2,5s. Không lấy được thì trả `null` — app vẫn chạy, chỉ là máy này không nhận thông báo.
Future<String?> fetchPushToken() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apns = await FirebaseMessaging.instance.getAPNSToken();
      for (int i = 0; apns == null && i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        apns = await FirebaseMessaging.instance.getAPNSToken();
      }
      if (apns == null) {
        debugPrint('⚠️ Chưa nhận được APNs token, bỏ qua lấy FCM token');
        return null;
      }
    }
    return await FirebaseMessaging.instance.getToken();
  } catch (e) {
    // Firebase chưa dựng được (vd lỗi lúc khởi động) hoặc máy không có Google Play Services: coi như không có mã
    debugPrint('Lấy FCM token lỗi: $e');
    return null;
  }
}
