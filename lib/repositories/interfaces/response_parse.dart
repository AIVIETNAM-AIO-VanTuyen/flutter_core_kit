// Hàm đọc JSON dùng chung cho tầng interface.
//
// Laravel có lúc gửi số dạng chuỗi (`"1"`), cờ dạng bool hoặc 0/1. Ép cứng (`as int?`) thì một trường phụ lệch
// kiểu là hỏng cả response (vd đăng nhập đúng mật khẩu vẫn báo lỗi), nên trường phụ đọc mềm: sai kiểu thành `null`.

/// Số nguyên: nhận `int`, `double`, chuỗi số, bool (`true` → 1); còn lại `null`.
int? asInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  final bool flag => flag ? 1 : 0,
  _ => null,
};

/// Chuỗi: nhận `String`, số và bool đổi thành chuỗi; còn lại (map, list…) `null`.
String? asString(Object? value) => switch (value) {
  final String text => text,
  final num number => '$number',
  final bool flag => '$flag',
  _ => null,
};
