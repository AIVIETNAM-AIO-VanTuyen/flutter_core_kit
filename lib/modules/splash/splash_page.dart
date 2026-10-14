import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../config/firebase_config.dart';
import '../../config/push_service.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_tokens.dart';
import '../../routes/app_navigator.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

/// Màn khởi động: nạp `.env`, dựng Firebase và phiên đăng nhập, rồi chọn màn đầu tiên.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  /// Lỗi cấu hình làm app không khởi động được (thiếu `.env` / `API_URL`, kho hỏng…), hiện ra thay vì quay mãi.
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // App khoá dọc; màn nào cần xoay thì tự mở khoá và trả lại trong dispose()
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    final String next;
    try {
      // .env nạp song song với Firebase. ignore() để lỗi .env không thành lỗi lạc zone trong lúc chờ Firebase; await
      // phía dưới vẫn nhận lỗi gốc
      final Future<void> env = dotenv.load(fileName: '.env')..ignore();
      final bool firebaseReady = await _setupFirebase();
      await env;
      startSessionHandling(listenPushToken: firebaseReady);
      next = await _launchRoute();
    } catch (e) {
      // Ranh giới khởi động: không bắt thì Splash quay mãi không ai biết vì sao
      debugPrint('Lỗi khởi động: $e');
      if (mounted) setState(() => _error = e);
      return;
    }
    if (!mounted) return;
    // go() thay cả stack: Back ở màn sau thoát app, không về Splash
    AppNavigator.go(next);
  }

  /// `false` khi Firebase không dựng được: thiếu file cấu hình, máy không có Google Play Services…
  Future<bool> _setupFirebase() async {
    try {
      await setupFirebase();
    } catch (e) {
      // Lỗi Firebase không được giữ app đứng ở Splash: vẫn vào app, chỉ mất push / analytics
      debugPrint('Lỗi khởi tạo Firebase: $e');
      return false;
    }
    try {
      await pushService.init();
    } catch (e) {
      // Firebase vẫn chạy (token FCM vẫn gửi được), chỉ mất thông báo local / bấm thông báo
      debugPrint('Lỗi dựng thông báo: $e');
    }
    return true;
  }

  /// Token còn hạn → Home; còn lại → Đăng nhập. [TokenStorage.hasToken] đã so mốc hết hạn.
  Future<String> _launchRoute() async {
    if (await TokenStorage.hasToken) return AppRoutes.home;
    // Token quá hạn còn trong kho thì 401 của API gọi trước khi đăng nhập lại bị coi là mất phiên (interceptor đọc
    // kho không lọc hạn)
    await TokenStorage.clear();
    return AppRoutes.login;
  }

  @override
  Widget build(BuildContext context) {
    final Object? error = _error;
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(padding: const EdgeInsets.all(AppSpacing.screen), child: Text('$error')),
      ),
    );
  }
}
