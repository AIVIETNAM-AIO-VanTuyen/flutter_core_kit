import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../enums/permission_enum.dart';
import '../singletons/account_store.dart';
import 'app_routes.dart';

/// Chặn route khi tài khoản thiếu quyền: báo snackbar rồi về Home. Gắn vào `redirect` của route cần quyền:
///
/// ```dart
/// GoRoute(
///   path: AppRoutes.example,
///   redirect: (_, _) => permissionMiddleware(PermissionEnum.example),
///   builder: (_, _) => const ExamplePage(),
/// )
/// ```
String? permissionMiddleware(PermissionEnum permission) {
  if (accountStore.hasPermission(permission)) return null;
  // redirect chạy giữa lúc dựng route: đợi frame sau mới hiện snackbar. Đổi sang snackbar của design system app
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('You do not have permission to access this feature')),
    ),
  );
  return AppRoutes.home;
}
