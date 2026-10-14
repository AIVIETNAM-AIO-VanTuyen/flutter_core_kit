import '../../models/interfaces/account_model_interface.dart';
import 'response_parse.dart';

/// JSON response `POST auth/login`.
///
/// Mẫu: `token` và `user` nằm cạnh `success` trong envelope, không nằm trong `data`:
/// `{"data": {"token": {"access_token", "access_expire"}, "user": {"id", "name", …}, "success": 1}}`.
/// Backend trả dạng khác thì sửa [LoginResponseInterface.fromJson] theo response thật.
class LoginResponseInterface {
  const LoginResponseInterface({required this.token, required this.user});

  /// [json] là `BaseResponse.body` (lớp chứa `success`). Thiếu `token` / `user` → [TypeError] (BaseServices.from đổi
  /// thành ParseFailure).
  factory LoginResponseInterface.fromJson(Map<String, dynamic> json) {
    return LoginResponseInterface(
      token: TokenInterface.fromJson(json['token'] as Map<String, dynamic>),
      user: AccountModelInterface.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final TokenInterface token;
  final AccountModelInterface user;

  Map<String, dynamic> toJson() => {'token': token.toJson(), 'user': user.toJson()};
}

class TokenInterface {
  const TokenInterface({required this.accessToken, required this.accessExpire});

  /// Token và hạn là bắt buộc: thiếu / rỗng → [FormatException], vì lưu token hỏng thì app tưởng đã đăng nhập.
  /// `access_expire` đọc mềm (Laravel có lúc gửi số dạng chuỗi).
  factory TokenInterface.fromJson(Map<String, dynamic> json) {
    final String? accessToken = asString(json['access_token']);
    final int? accessExpire = asInt(json['access_expire']);
    if (accessToken == null || accessToken.isEmpty || accessExpire == null) {
      throw const FormatException('Response đăng nhập thiếu token.access_token / token.access_expire');
    }
    return TokenInterface(accessToken: accessToken, accessExpire: accessExpire);
  }

  /// Access token, gửi kèm header `Authorization`.
  final String accessToken;

  /// Giây epoch.
  final int accessExpire;

  DateTime get expiresAt => DateTime.fromMillisecondsSinceEpoch(accessExpire * 1000);

  Map<String, dynamic> toJson() => {'access_token': accessToken, 'access_expire': accessExpire};
}

/// Lỗi 422 của đăng nhập, theo từng ô: `{"email": "That email address is not valid.", "password": "…"}`.
///
/// Có BE gửi mỗi ô một câu, Laravel gốc gửi mảng câu, nên nhận cả hai, lấy câu đầu.
class LoginErrorForm {
  const LoginErrorForm({this.emailError, this.passwordError});

  factory LoginErrorForm.fromJson(Map<String, dynamic> json) {
    return LoginErrorForm(emailError: _first(json['email']), passwordError: _first(json['password']));
  }

  final String? emailError;
  final String? passwordError;

  bool get isEmpty => emailError == null && passwordError == null;

  Map<String, dynamic> toJson() => {'email': emailError, 'password': passwordError};

  static String? _first(Object? value) => switch (value) {
    final String message => message,
    [final String message, ...] => message,
    _ => null,
  };

  @override
  String toString() => 'LoginErrorForm(email: $emailError, password: $passwordError)';
}
