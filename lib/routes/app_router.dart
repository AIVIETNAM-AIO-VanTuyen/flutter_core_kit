import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../modules/home/home_page.dart';
import '../modules/login/login_page.dart';
import '../modules/not_found/not_found_page.dart';
import '../modules/splash/splash_page.dart';
import 'app_routes.dart';
import 'unknown_route_redirect.dart';

/// Router của app. [navigatorKey] là navigator gốc, để [AppNavigator] và overlay gọi được không cần `BuildContext`.
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: AppRoutes.splash,
  // Link mở app có path lạ (deep linking của Flutter bật mặc định) → về chỗ hợp lệ, không hiện "Page Not Found"
  redirect: UnknownRouteRedirect().call,
  errorBuilder: (_, _) => const NotFoundPage(),
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
    GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
    GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
  ],
);
