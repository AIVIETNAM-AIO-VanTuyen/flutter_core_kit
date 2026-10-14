import 'package:flutter/material.dart';

/// Key điều hướng toàn cục, dùng để truy cập Navigator/Overlay/BuildContext
/// từ những nơi không có sẵn BuildContext (handler, singleton, service...).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Gắn vào `MaterialApp.scaffoldMessengerKey`, để hiện snackbar từ nơi không có `BuildContext` (middleware, service).
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
