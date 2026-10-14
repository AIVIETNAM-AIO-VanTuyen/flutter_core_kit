import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';

/// Điều hướng không cần `BuildContext`: gọi được từ màn, service, handler thông báo.
///
/// ```dart
/// AppNavigator.go(AppRoutes.home);                                 // thay cả stack, Back thoát app
/// final bool? ok = await AppNavigator.push<bool>('/scan', query: {'mode': 'qr'});
/// AppNavigator.pushReplacement(AppRoutes.login);                  // thay màn trên cùng, có animation
/// AppNavigator.back(true);                                         // không còn gì để lùi thì bỏ qua
/// ```
///
/// Router lấy qua [navigatorKey] (navigator gốc của app, gắn ở `app_router.dart`), nên router nào gắn key đó
/// (kể cả router dựng riêng trong test) đều dùng được.
abstract final class AppNavigator {
  static GoRouter get _router {
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) throw StateError('AppNavigator: router chưa gắn navigatorKey hoặc chưa dựng xong');
    return GoRouter.of(context);
  }

  static NavigatorState get _navigator => navigatorKey.currentState!;

  /// Thay cả stack bằng màn [path] (như `pushAndRemoveUntil`): Back ở màn mới thoát app, không về màn cũ.
  static void go(String path, {Map<String, Object?> query = const {}, Object? extra}) =>
      _router.go(_location(path, query), extra: extra);

  /// Chồng màn [path] lên trên. Future xong khi màn đó pop, mang kết quả của [back].
  static Future<T?> push<T extends Object?>(String path, {Map<String, Object?> query = const {}, Object? extra}) =>
      _router.push<T>(_location(path, query), extra: extra);

  /// Thay màn trên cùng bằng [path], có animation chuyển màn. Back ở màn mới về màn dưới màn bị thay.
  static Future<T?> pushReplacement<T extends Object?>(
    String path, {
    Map<String, Object?> query = const {},
    Object? extra,
  }) => _router.pushReplacement<T>(_location(path, query), extra: extra);

  /// Như [pushReplacement] nhưng giữ page key: không animation, state của màn được giữ nếu cùng loại widget.
  static Future<T?> replace<T extends Object?>(String path, {Map<String, Object?> query = const {}, Object? extra}) =>
      _router.replace<T>(_location(path, query), extra: extra);

  /// Có màn để lùi không.
  static bool get canBack => _router.canPop();

  /// Lùi một màn, trả [result] cho `push`. Đang ở màn đầu thì bỏ qua (không pop mất màn gốc → màn đen).
  /// Trả `true` nếu đã lùi.
  static bool back<T extends Object?>([T? result]) {
    if (!canBack) return false;
    _router.pop<T>(result);
    return true;
  }

  /// Lùi về màn đầu stack.
  static void backToFirst() => _navigator.popUntil((Route<dynamic> route) => route.isFirst);

  /// Ghép query vào path. Giá trị không phải chuỗi được đổi sang chuỗi (Uri chỉ nhận `String` / `Iterable<String>`,
  /// truyền số là crash); giá trị `null` bị bỏ.
  static String _location(String path, Map<String, Object?> query) {
    final Map<String, Object> params = {
      for (final MapEntry<String, Object?> e in query.entries)
        if (e.value case final Object value)
          e.key: value is Iterable ? value.map((Object? v) => '$v').toList() : '$value',
    };
    return Uri(path: path, queryParameters: params.isEmpty ? null : params).toString();
  }
}
