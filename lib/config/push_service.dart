import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton dùng chung cho cả app.
final PushService pushService = PushService._();

/// Thông báo đẩy (FCM) và thông báo local.
///
/// ```dart
/// await pushService.init();                       // Splash, sau setupFirebase()
/// // Gán ở màn đã đăng nhập (vd initState của Home), không gán ở main: Splash xong gọi go() thay cả stack, màn mở
/// // từ thông báo trước đó sẽ mất
/// pushService.onTap = (data) => AppNavigator.push('/orders/${data['id']}');
/// await pushService.requestPermission();          // lúc hợp lý, vd sau đăng nhập — không xin ngay khi mở app
/// ```
///
/// App đang mở: iOS để FCM tự hiện banner, Android không tự hiện nên dựng thông báo local từ push.
class PushService {
  PushService._();

  /// Một kênh cho cả thông báo local lẫn push lúc app chạy nền: id này cũng khai ở
  /// `com.google.firebase.messaging.default_notification_channel_id` trong AndroidManifest để hai nguồn hiện giống nhau.
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default',
    'Notifications',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  /// Cú bấm tới trước khi app gắn [onTap] (mở app từ thông báo lúc app tắt hẳn), giữ lại để giao khi gắn.
  Map<String, dynamic>? _pendingTap;

  void Function(Map<String, dynamic> data)? _onTap;

  /// Người dùng bấm thông báo (push hoặc local), nhận `data` của thông báo.
  set onTap(void Function(Map<String, dynamic> data)? handler) {
    _onTap = handler;
    final Map<String, dynamic>? pending = _pendingTap;
    if (handler != null && pending != null) {
      _pendingTap = null;
      // Setter hay được gọi trong initState: điều hướng ngay giữa lúc build là lỗi, đợi hết frame hiện tại
      Future<void>.microtask(() => handler(pending));
    }
  }

  /// Gọi nhiều lần cũng chỉ dựng một lần. Cần Firebase đã dựng xong. Lỗi thì lần gọi sau dựng lại.
  Future<void> init() {
    return _ready ??= _init().catchError((Object e, StackTrace stack) {
      _ready = null;
      Error.throwWithStackTrace(e, stack);
    });
  }

  Future<void> _init() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Không xin quyền lúc dựng: hộp thoại hiện ngay khi mở app thì người dùng dễ từ chối; gọi [requestPermission]
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onLocalTap,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_onForegroundPush);
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) => _deliverTap(message.data));

    // Mở app từ thông báo lúc app tắt hẳn: chỉ đọc được một lần
    final RemoteMessage? initial = await messaging.getInitialMessage();
    if (initial != null) {
      _deliverTap(initial.data);
      return;
    }
    final NotificationAppLaunchDetails? launch = await _local.getNotificationAppLaunchDetails();
    final NotificationResponse? response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) _onLocalTap(response);
  }

  /// Hiện hộp thoại xin quyền (chỉ lần đầu; các lần sau hệ điều hành trả lại câu trả lời đã lưu).
  Future<bool> requestPermission() async {
    final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Hiện thông báo local. [data] trả lại qua [onTap] khi người dùng bấm.
  Future<void> show({required int id, String? title, String? body, Map<String, dynamic>? data}) {
    return _local.show(
      // Android chỉ nhận int 32-bit có dấu
      id: id & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: data == null ? null : jsonEncode(data),
    );
  }

  void _onForegroundPush(RemoteMessage message) {
    // iOS đã hiện qua setForegroundNotificationPresentationOptions; push chỉ có `data` thì không có gì để hiện
    final RemoteNotification? notification = message.notification;
    if (defaultTargetPlatform != TargetPlatform.android || notification == null) return;
    show(id: message.messageId.hashCode, title: notification.title, body: notification.body, data: message.data);
  }

  String? _lastLocalTap;
  DateTime? _lastLocalTapAt;

  void _onLocalTap(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    // Mở app từ thông báo local lúc app tắt hẳn: plugin giao cú bấm hai lần (onNewIntent và
    // getNotificationAppLaunchDetails), cách nhau vài mili giây. Chỉ khử trong cửa sổ ngắn để bấm thật hai lần vẫn tính
    final String signature = '${response.id}|${response.actionId}|$payload';
    final DateTime now = clock.now();
    final DateTime? last = _lastLocalTapAt;
    final bool repeat = signature == _lastLocalTap && last != null && now.difference(last) < const Duration(seconds: 5);
    _lastLocalTap = signature;
    _lastLocalTapAt = now;
    if (repeat) return;

    final Object? data;
    try {
      data = jsonDecode(payload);
    } on FormatException catch (e) {
      // Payload do chính app ghi bằng jsonEncode; hỏng thì bỏ cú bấm thay vì làm chết callback của plugin
      debugPrint('[Push] Payload thông báo local không phải JSON: $e');
      return;
    }
    if (data is Map<String, dynamic>) _deliverTap(data);
  }

  void _deliverTap(Map<String, dynamic> data) {
    final void Function(Map<String, dynamic> data)? handler = _onTap;
    if (handler == null) {
      _pendingTap = data;
      return;
    }
    handler(data);
  }
}
