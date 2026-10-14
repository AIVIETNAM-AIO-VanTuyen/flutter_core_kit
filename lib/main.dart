import 'package:flutter/material.dart';

import 'constants/app_constants.dart';
import 'core/theme/app_tokens.dart';
import 'helpers/network.dart';
import 'routes/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // .env, Firebase, phiên đăng nhập dựng ở SplashPage: màn splash là chỗ chờ sẵn có, khỏi giữ màn đen trước runApp
  initInternetListener();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Core Kit',
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
