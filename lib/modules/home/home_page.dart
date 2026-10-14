import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/account_model.dart';
import '../../routes/app_navigator.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/base_services.dart';

/// Màn chính mẫu: tải hồ sơ (`GET auth/me`), xử lý đang tải / lỗi / thử lại, và đăng xuất. Thay bằng Home thật.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.getProfile = getProfileService, this.logout = logoutService, this.onLoggedOut});

  /// Mặc định gọi API thật; test truyền bản giả.
  final ProfileService getProfile;
  final Future<BaseServices<void, void>> Function() logout;

  /// Khi rời Home về Đăng nhập (đăng xuất xong, hoặc phiên đã hết). Mặc định thay cả stack (Back không về Home).
  final void Function()? onLoggedOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// `null` khi đang tải.
  BaseServices<AccountModel, void>? _profile;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_profile != null) setState(() => _profile = null);
    final BaseServices<AccountModel, void> profile = await widget.getProfile();
    if (!mounted) return;
    // Chưa đăng nhập / phiên đã hết (service đã xoá token): ở lại Home cũng không làm được gì
    if (profile.isUnauthorized) {
      _leave();
      return;
    }
    setState(() => _profile = profile);
  }

  // Phiên trên máy đã xoá dù API lỗi, nên luôn về Đăng nhập, không báo lỗi
  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await widget.logout();
    if (mounted) _leave();
  }

  void _leave() => (widget.onLoggedOut ?? () => AppNavigator.go(AppRoutes.login))();

  @override
  Widget build(BuildContext context) {
    final BaseServices<AccountModel, void>? profile = _profile;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profile == null)
                  const CircularProgressIndicator()
                else if (profile.data case final AccountModel account) ...[
                  Text(account.name, style: AppText.title2.copyWith(color: AppColors.neutral900)),
                  if (account.email case final String email)
                    Text(email, style: AppText.subhead.copyWith(color: AppColors.neutral600)),
                ] else ...[
                  Text(
                    profile.message ?? 'Something went wrong, please try again',
                    style: AppText.subhead.copyWith(color: AppColors.neutral600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.tonal(onPressed: _loadProfile, child: const Text('Try again')),
                ],
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(onPressed: _loggingOut ? null : _logout, child: const Text('Log out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
