// Thang chữ của app. Khung mẫu theo cỡ chữ iOS: thay giá trị theo design system của từng app.
// fontSize và letterSpacing tính bằng logical pixel (không phải em), height là hệ số nhân với fontSize.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppFont {
  /// `null` = font hệ thống (Roboto / SF Pro). Dùng font riêng thì khai trong pubspec.yaml (mỗi độ đậm một file
  /// static, không dựa vào bold tổng hợp) rồi đặt tên family ở đây. Nhớ kiểm tra font có đủ chữ tiếng Việt có dấu.
  static const String? family = null;

  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semiBold = FontWeight.w600;
  static const bold = FontWeight.w700;
}

/// Kiểu chữ của hệ thống. Không mang màu — thêm màu tại chỗ dùng bằng `.copyWith(color: AppColors.…)`.
///
/// Đổi cỡ chữ của một kiểu thì tính lại letterSpacing, đừng giữ số cũ: letterSpacing là giá trị tuyệt đối, không co
/// giãn theo fontSize như em.
abstract final class AppText {
  static TextStyle _s(double size, FontWeight weight, double letterSpacing, double height) => TextStyle(
    fontFamily: AppFont.family,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// 34 · tiêu đề lớn
  static final largeTitle = _s(34, AppFont.bold, -0.8, 1.21);

  /// 28 · tiêu đề màn hình
  static final title1 = _s(28, AppFont.bold, -0.6, 1.21);

  /// 22 · nhóm nội dung
  static final title2 = _s(22, AppFont.bold, -0.4, 1.27);

  /// 20 · tiêu đề card
  static final title3 = _s(20, AppFont.semiBold, -0.3, 1.25);

  /// 17 · tiêu đề dòng list
  static final headline = _s(17, AppFont.semiBold, -0.2, 1.29);

  /// 17 · cỡ đọc mặc định cho đoạn văn và giá trị field
  static final body = _s(17, AppFont.regular, 0, 1.41);

  /// 15 · chữ phụ, câu hướng dẫn
  static final subhead = _s(15, AppFont.regular, 0, 1.33);

  /// 13 · thời gian, metadata, gợi ý field
  static final footnote = _s(13, AppFont.regular, 0, 1.38);

  /// 12 · tiêu đề nhóm
  static final caption = _s(12, AppFont.semiBold, 0.5, 1.33);

  /// 17 · chữ trên nút
  static final button = _s(17, AppFont.semiBold, -0.2, 1.29);

  /// 11 · nhãn tab bar
  static final tabLabel = _s(11, AppFont.semiBold, 0.1, 1.18);

  /// Slot M3: map slot thừa về kiểu gần nhất thay vì nghĩ ra cỡ mới, để widget Material vẫn nằm trong thang chữ.
  static TextTheme get textTheme => TextTheme(
    displayLarge: largeTitle,
    displayMedium: largeTitle,
    displaySmall: largeTitle,
    headlineLarge: title1,
    headlineMedium: title1,
    headlineSmall: title2,
    titleLarge: title3,
    titleMedium: headline,
    titleSmall: headline,
    bodyLarge: body,
    bodyMedium: subhead,
    bodySmall: footnote,
    labelLarge: button,
    labelMedium: caption,
    labelSmall: tabLabel,
  );

  /// Slot Cupertino cho chrome iOS (CupertinoNavigationBar, CupertinoButton, CupertinoTabBar).
  static CupertinoTextThemeData get cupertinoTextTheme => CupertinoTextThemeData(
    textStyle: body,
    actionTextStyle: button,
    navTitleTextStyle: headline,
    navLargeTitleTextStyle: largeTitle,
    tabLabelTextStyle: tabLabel,
  );
}

extension AppTextStyleX on TextStyle {
  /// Chữ số cùng bề ngang cho bảng, tiền, bộ đếm, để số không nhảy mỗi lần rebuild.
  TextStyle get tabular => copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Chia khoảng dôi của `height` đều trên và dưới glyph, cho chữ nằm trong hàng cao cố định được canh giữa.
  TextStyle get evenLeading => copyWith(leadingDistribution: TextLeadingDistribution.even);
}
