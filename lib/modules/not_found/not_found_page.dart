import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../routes/app_navigator.dart';
import '../../routes/app_routes.dart';

/// `errorBuilder` của GoRouter. Lưới cuối: route lạ đã được `UnknownRouteRedirect` chuyển đi, màn này chỉ hiện khi
/// redirect cũng lỗi (vd URI hỏng), để người dùng không kẹt ở màn "Page Not Found" mặc định không có lối ra.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Page not found', style: AppText.title3.copyWith(color: AppColors.neutral900)),
                const SizedBox(height: AppSpacing.md),
                // Về Splash chứ không thẳng Home: Splash mới biết đang đăng nhập hay phải qua Đăng nhập
                FilledButton(onPressed: () => AppNavigator.go(AppRoutes.splash), child: const Text('Go home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
