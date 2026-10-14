import '../../models/interfaces/account_model_interface.dart';

/// JSON response `GET auth/me`: `{"data": {"user": {"id", "name", …}, "success": 1}}`. `user` cùng dạng với `user`
/// của đăng nhập.
class ProfileResponseInterface {
  const ProfileResponseInterface({required this.user});

  /// [json] là `BaseResponse.body`. Thiếu `user` → [TypeError] (BaseServices.from đổi thành ParseFailure).
  factory ProfileResponseInterface.fromJson(Map<String, dynamic> json) {
    return ProfileResponseInterface(user: AccountModelInterface.fromJson(json['user'] as Map<String, dynamic>));
  }

  final AccountModelInterface user;

  Map<String, dynamic> toJson() => {'user': user.toJson()};
}
