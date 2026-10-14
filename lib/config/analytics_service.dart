import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';


/// Singleton dùng chung cho cả app.
final analytics = AnalyticsService();

/// Bọc Firebase Analytics.
///
/// Mọi hàm ở đây **không bao giờ ném**: đo đạc hỏng thì nuốt lỗi, không được làm gãy luồng nghiệp vụ. Tên sự kiện /
/// tham số sai luật Firebase thì sự kiện bị bỏ âm thầm phía server: kiểm bằng [isValidName] khi viết sự kiện mới.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() => _instance;

  AnalyticsService._internal();

  /// Giới hạn của Firebase Analytics, vượt là sự kiện bị bỏ âm thầm phía server.
  static const int maxEventNameLength = 40;
  static const int maxParamCount = 25;
  static const int maxParamNameLength = 40;
  static const int maxParamValueLength = 100;

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// [params] nhận kiểu JSON bất kỳ; hàm tự ép về String/num trước khi gửi.
  /// Firebase `assert(value is String || value is num)` — truyền bool thẳng vào
  /// là sự kiện rơi mất (debug thì ném, release thì assert bị bỏ rồi chết ở tầng native).
  Future<void> logEvent(String name, [Map<String, dynamic>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params == null ? null : coerceParams(params));
    } catch (e) {
      _swallow('logEvent($name)', e);
    }
  }

  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _analytics.logScreenView(screenName: screenName, screenClass: screenClass);
    } catch (e) {
      _swallow('logScreenView($screenName)', e);
    }
  }

  /// Truyền null lúc đăng xuất.
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      _swallow('setUserId', e);
    }
  }

  Future<void> setUserProperty(String name, String? value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      _swallow('setUserProperty($name)', e);
    }
  }

  /// Tắt thu thập (người dùng từ chối theo dõi).
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      _swallow('setCollectionEnabled($enabled)', e);
    }
  }

  /// Tên hợp lệ: bắt đầu bằng chữ cái, chỉ chữ/số/gạch dưới, không quá [maxLength].
  static bool isValidName(String name, int maxLength) =>
      name.isNotEmpty && name.length <= maxLength && RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(name);

  /// Ép tham số về kiểu Firebase nhận (chỉ String và num). **Không ném.**
  ///
  /// bool → "true"/"false", Map/List → JSON, chuỗi dài hơn [maxParamValueLength] bị cắt (Firebase cũng cắt, cắt sẵn
  /// để log ra đúng thứ thật sự được gửi). Giá trị null bị bỏ qua — Firebase không có khái niệm tham số rỗng.
  static Map<String, Object> coerceParams(Map<String, dynamic> params) {
    final Map<String, Object> result = {};
    params.forEach((key, value) {
      if (value == null) return;
      result[key] = value is num ? value : _truncate(_stringify(value));
    });
    return result;
  }

  static String _stringify(Object value) {
    if (value is String) return value;
    if (value is bool) return value.toString();
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  static String _truncate(String value) =>
      value.length <= maxParamValueLength ? value : value.substring(0, maxParamValueLength);

  void _swallow(String action, Object error) {
    debugPrint('⚠️ Analytics "$action" lỗi, bỏ qua: $error');
  }
}
