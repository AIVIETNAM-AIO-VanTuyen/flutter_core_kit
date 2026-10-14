import '../../repositories/interfaces/response_parse.dart';

/// JSON hồ sơ người dùng đúng như BE gửi (`user` của login và `GET auth/me`). Chỉ đọc đúng kiểu (số dạng chuỗi → số),
/// chưa đặt mặc định; việc đó ở [AccountModel].
///
/// Mẫu: thêm / bớt field theo response thật của backend.
class AccountModelInterface {
  const AccountModelInterface({this.id, this.name, this.email, this.avatar});

  /// Đọc mềm ([asInt] / [asString]): trường lệch kiểu thành `null` chứ không làm hỏng cả response.
  factory AccountModelInterface.fromJson(Map<String, dynamic> json) {
    return AccountModelInterface(
      id: asInt(json['id']),
      name: asString(json['name']),
      email: asString(json['email']),
      avatar: asString(json['avatar']),
    );
  }

  final int? id;
  final String? name;
  final String? email;
  final String? avatar;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'avatar': avatar};
}
