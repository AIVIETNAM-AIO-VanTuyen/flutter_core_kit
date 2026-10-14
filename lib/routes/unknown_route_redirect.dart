import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// `redirect` cấp gốc của GoRouter: đường dẫn không khớp route nào thì về Home thay vì màn lỗi.
///
/// Flutter bật deep linking mặc định nên link/intent mở app được đẩy thẳng vào GoRouter; link lạ về Home. Ngoại lệ:
/// chưa qua Splash (mở nguội bằng link, hoặc link tới lúc Splash đang chạy) thì về Splash, vì Firebase / .env khởi tạo
/// ở đó; Splash xong tự vào Home nếu còn đăng nhập.
class UnknownRouteRedirect {
  /// Đã tới một màn sau Splash, tức khởi tạo xong.
  bool _pastSplash = false;

  String? call(BuildContext context, GoRouterState state) {
    if (state.error == null) {
      if (state.uri.path != AppRoutes.splash) _pastSplash = true;
      return null;
    }
    final String target = _pastSplash ? AppRoutes.home : AppRoutes.splash;
    debugPrint('Route lạ "${state.uri}", chuyển về $target');
    return target;
  }
}
