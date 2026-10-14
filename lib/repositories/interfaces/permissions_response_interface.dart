import 'response_parse.dart';

/// JSON response `GET auth/permissions`: `{"data": {"permissions": ["EXAMPLE", …], "success": 1}}`.
class PermissionsResponseInterface {
  const PermissionsResponseInterface({required this.permissions});

  /// [json] là `BaseResponse.body`. Thiếu `permissions` → [TypeError] (BaseServices.from đổi thành ParseFailure);
  /// phần tử lạ kiểu thì bỏ qua.
  factory PermissionsResponseInterface.fromJson(Map<String, dynamic> json) {
    final List<dynamic> list = json['permissions'] as List<dynamic>;
    return PermissionsResponseInterface(permissions: [for (final Object? item in list) ?asString(item)]);
  }

  final List<String> permissions;

  Map<String, dynamic> toJson() => {'permissions': permissions};
}
