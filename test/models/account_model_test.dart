import 'package:flutter_core_kit/models/account_model.dart';
import 'package:flutter_core_kit/models/interfaces/account_model_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('giữ nguyên các trường, tên đã trim', () {
    final AccountModel account = AccountModel(
      data: const AccountModelInterface(id: 12, name: ' Lan Nguyen ', email: 'lan@example.com'),
    );
    expect(account.id, 12);
    expect(account.name, 'Lan Nguyen');
    expect(account.email, 'lan@example.com');
    expect(account.avatar, isNull);
  });

  test('thiếu id / name → 0 / chuỗi rỗng', () {
    final AccountModel empty = AccountModel(data: const AccountModelInterface());
    expect(empty.id, 0);
    expect(empty.name, '');
  });
}
