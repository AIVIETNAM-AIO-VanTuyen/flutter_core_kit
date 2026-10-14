import 'package:flutter_core_kit/repositories/interfaces/permissions_response_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đọc danh sách quyền, bỏ phần tử lạ kiểu', () {
    final PermissionsResponseInterface data = PermissionsResponseInterface.fromJson({
      'permissions': ['LIBRARY', null, 'CHAT', 7],
      'success': 1,
    });
    expect(data.permissions, ['LIBRARY', 'CHAT', '7']);
  });

  test('thiếu permissions → TypeError', () {
    expect(() => PermissionsResponseInterface.fromJson({'success': 1}), throwsA(isA<TypeError>()));
  });
}
