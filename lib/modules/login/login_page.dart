import 'package:flutter/material.dart';

import '../../core/result/result.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/account_model.dart';
import '../../repositories/interfaces/login_response_interface.dart';
import '../../routes/app_navigator.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/base_services.dart';
import '../../singletons/account_store.dart';

/// Màn Đăng nhập mẫu: cách dùng service, đọc lỗi theo loại và lỗi từng ô (422). Giao diện dùng widget Material thuần,
/// thay bằng component design system của app.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.login = loginService, this.onLoggedIn});

  /// Mặc định gọi API thật; test truyền bản giả.
  final LoginService login;

  /// Mặc định thay cả stack bằng Home (Back không về Đăng nhập).
  final void Function()? onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _submitting = false;
  String? _emailError;
  String? _passwordError;

  /// Lỗi chung (sai mật khẩu, mất mạng…), hoặc câu BE gửi khi phiên bị kết thúc từ phía server.
  String? _notice;

  @override
  void initState() {
    super.initState();
    // Về đây vì phiên hết hạn / bị đăng xuất từ máy khác: hiện câu BE gửi một lần
    _notice = accountStore.takeSessionNotice();
    // Câu tới khi màn đang mở (request chạy nền về 401) cũng phải hiện
    accountStore.addListener(_onAccountStore);
  }

  void _onAccountStore() {
    if (accountStore.sessionNotice == null) return;
    setState(() => _notice = accountStore.takeSessionNotice());
  }

  /// Gõ lại thì lỗi cũ không còn đúng nữa
  void _clearErrors() {
    if (_notice == null && _emailError == null && _passwordError == null) return;
    setState(() {
      _notice = null;
      _emailError = null;
      _passwordError = null;
    });
  }

  @override
  void dispose() {
    accountStore.removeListener(_onAccountStore);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Bấm liên tục: chỉ gửi một lần tới khi có kết quả
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _emailError = null;
      _passwordError = null;
      _notice = null;
    });

    final BaseServices<AccountModel, LoginErrorForm> result = await widget.login(
      email: _email.text.trim(),
      password: _password.text,
    );
    // Đã rời màn trong lúc chờ: bỏ kết quả về muộn
    if (!mounted) return;
    if (result.isSuccess) {
      (widget.onLoggedIn ?? () => AppNavigator.go(AppRoutes.home))();
      return;
    }
    setState(() {
      _submitting = false;
      switch (result.failure) {
        case ValidationFailure():
          _emailError = result.error?.emailError;
          _passwordError = result.error?.passwordError;
          // 422 mà không có lỗi ô nào đọc được thì vẫn phải báo gì đó
          if (_emailError == null && _passwordError == null) _notice = result.message;
        case CancelledFailure():
          break;
        default:
          _notice = result.message ?? 'Something went wrong, please try again';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? notice = _notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Log in', style: AppText.title1.copyWith(color: AppColors.neutral900)),
                  const SizedBox(height: AppSpacing.lg),
                  if (notice != null) ...[
                    Text(notice, style: AppText.subhead.copyWith(color: AppColors.dangerText)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextField(
                    controller: _email,
                    enabled: !_submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => _clearErrors(),
                    decoration: InputDecoration(labelText: 'Email', errorText: _emailError),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _password,
                    enabled: !_submitting,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onChanged: (_) => _clearErrors(),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(labelText: 'Password', errorText: _passwordError),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Log in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
