/// Mã quyền tầng người dùng, trả về từ `GET auth/permissions`.
///
/// Mẫu: thay bằng mã thật của backend. BE thêm mã mới thì thêm ở đây.
enum PermissionEnum {
  example('EXAMPLE');

  const PermissionEnum(this.value);

  /// Mã BE gửi.
  final String value;
}
