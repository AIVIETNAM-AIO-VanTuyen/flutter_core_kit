import 'package:firebase_core/firebase_core.dart';

/// Dựng Firebase. Cần file cấu hình của app: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
/// (hoặc `firebase_options.dart` của `flutterfire configure`, khi đó truyền `options:` vào [Firebase.initializeApp]).
/// Thiếu thì hàm ném; Splash bắt để app vẫn chạy, chỉ mất push / analytics.
Future<void> setupFirebase() async {
  await Firebase.initializeApp();
}
