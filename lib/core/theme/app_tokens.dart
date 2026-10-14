// Token giao diện của app, light theme. Khung mẫu: giữ tên nhóm, thay giá trị theo design system của từng app.
// Màu và bóng chỉ khai ở đây; widget không viết `Color(0x…)` / `BoxShadow(...)` trần.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_typography.dart';

// Kiểu chữ tách sang file riêng; export lại để chỗ nào import tokens vẫn dùng được AppText
export 'app_typography.dart';

abstract final class AppColors {
  // Primary — màu thương hiệu (mẫu: xanh dương), 500 là nền nút chính
  static const primary50 = Color(0xFFEFF6FF);
  static const primary100 = Color(0xFFDBEAFE);
  static const primary200 = Color(0xFFBFDBFE);
  static const primary300 = Color(0xFF93C5FD);
  static const primary400 = Color(0xFF60A5FA);
  static const primary500 = Color(0xFF3B82F6);
  static const primary600 = Color(0xFF2563EB); // pressed
  static const primary700 = Color(0xFF1D4ED8); // chữ & icon màu primary
  static const primary800 = Color(0xFF1E40AF);
  static const primary900 = Color(0xFF1E3A8A);

  // Neutral — nền, viền, chữ
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral25 = Color(0xFFF8FAFC);
  static const neutral50 = Color(0xFFF1F5F9);
  static const neutral100 = Color(0xFFE2E8F0);
  static const neutral200 = Color(0xFFCBD5E1);
  static const neutral300 = Color(0xFF94A3B8);
  static const neutral500 = Color(0xFF64748B);
  static const neutral600 = Color(0xFF475569); // chữ phụ trên nền sáng
  static const neutral700 = Color(0xFF334155);
  static const neutral900 = Color(0xFF0F172A); // chữ chính

  // Semantic — mỗi trạng thái một bộ nền / màu chính / chữ
  static const successBg = Color(0xFFECFDF5);
  static const success = Color(0xFF10B981);
  static const successText = Color(0xFF047857);
  static const warningBg = Color(0xFFFFFBEB);
  static const warning = Color(0xFFF59E0B);
  static const warningText = Color(0xFFB45309);
  static const dangerBg = Color(0xFFFEF2F2);
  static const danger = Color(0xFFEF4444);
  static const dangerText = Color(0xFFB91C1C);
  static const infoBg = Color(0xFFEFF6FF);
  static const info = Color(0xFF3B82F6);
  static const infoText = Color(0xFF1D4ED8);

  // Phủ mờ
  static const scrim = Color(0x660F172A); // 40% · nền sau dialog / sheet
}

/// Thang khoảng cách (bội số 4).
abstract final class AppSpacing {
  static const xxs = 4.0, xs = 8.0, sm = 12.0, md = 16.0, lg = 24.0, xl = 32.0, xxl = 40.0, xxxl = 56.0;

  /// Lề ngang của màn hình.
  static const screen = 16.0;

  /// Vùng chạm tối thiểu (Apple HIG 44pt).
  static const minTouch = 44.0;
}

abstract final class AppRadius {
  static const tag = 6.0, input = 10.0, button = 12.0, card = 16.0, sheet = 20.0, pill = 999.0;
}

abstract final class AppBorderRadius {
  static const tag = BorderRadius.all(Radius.circular(AppRadius.tag));
  static const input = BorderRadius.all(Radius.circular(AppRadius.input));
  static const button = BorderRadius.all(Radius.circular(AppRadius.button));
  static const card = BorderRadius.all(Radius.circular(AppRadius.card));
  static const pill = BorderRadius.all(Radius.circular(AppRadius.pill));

  /// Sheet chỉ bo hai góc trên.
  static const sheet = BorderRadius.vertical(top: Radius.circular(AppRadius.sheet));
}

abstract final class AppBorders {
  static const hairline = BorderSide(color: AppColors.neutral100);
}

/// Bóng theo bậc nổi. Bóng riêng của component nào thì thêm hằng có tên ở đây.
abstract final class AppShadows {
  static const e0 = <BoxShadow>[];

  /// Card.
  static const e1 = [BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x0F0F172A))];

  /// Khối nổi trên nội dung (menu, popover).
  static const e2 = [BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color(0x140F172A))];

  /// Dialog, sheet.
  static const e3 = [BoxShadow(offset: Offset(0, 12), blurRadius: 28, color: Color(0x240F172A))];
}

abstract final class AppIconSize {
  static const inline = 20.0, standard = 24.0;
}

abstract final class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const pressCurve = Curves.easeOut;

  /// Chờ ngắn hơn ngưỡng này thì không hiện loading: hiện rồi tắt ngay trông như nháy.
  static const loadingDelay = Duration(milliseconds: 300);

  /// Đã hiện loading thì giữ tối thiểu chừng này, cũng để khỏi nháy.
  static const loadingMin = Duration(milliseconds: 400);

  static const page = Duration(milliseconds: 320);

  /// Người dùng bật giảm chuyển động → trượt / scale rút về fade.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: AppColors.primary500).copyWith(
    primary: AppColors.primary500,
    onPrimary: Colors.white,
    error: AppColors.danger,
    onError: Colors.white,
    surface: AppColors.neutral0,
    onSurface: AppColors.neutral900,
    outline: AppColors.neutral300,
    outlineVariant: AppColors.neutral100,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.neutral25,
    // fontFamily cho mọi chữ không đi qua textTheme (vd TextField, SnackBar) vẫn ra đúng font
    fontFamily: AppFont.family,
    textTheme: AppText.textTheme,
    cupertinoOverrideTheme: CupertinoThemeData(textTheme: AppText.cupertinoTextTheme),
    // Chuyển trang kiểu Cupertino trên cả hai nền tảng (Android vẫn giữ nút Back hệ thống). Muốn kiểu Material thì
    // bỏ pageTransitionsTheme
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _AppPageTransitionsBuilder(),
        TargetPlatform.iOS: _AppPageTransitionsBuilder(),
      },
    ),
  );
}

/// Trượt Cupertino nhưng dài [AppMotion.page] (mặc định của Cupertino 500ms, hơi chậm). Máy bật giảm chuyển động thì
/// chỉ mờ dần.
class _AppPageTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return FadeTransition(opacity: animation, child: child);
    return super.buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}
