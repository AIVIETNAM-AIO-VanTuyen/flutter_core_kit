import 'package:flutter_core_kit/models/interfaces/account_model_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, dynamic> _user = {'id': 12, 'name': 'Lan Nguyen', 'email': 'lan@example.com', 'avatar': null};

void main() {
  test('fromJson đọc đủ trường, bỏ trường lạ; toJson trả lại đúng JSON', () {
    final AccountModelInterface user = AccountModelInterface.fromJson({..._user, 'workplace': []});

    expect(user.id, 12);
    expect(user.name, 'Lan Nguyen');
    expect(user.toJson(), _user);
  });

  test('thiếu trường → null', () {
    expect(AccountModelInterface.fromJson({}).id, isNull);
  });

  test('đọc mềm: số dạng chuỗi đọc được; trường lệch kiểu thành null thay vì ném', () {
    final AccountModelInterface user = AccountModelInterface.fromJson({
      'id': '12',
      'name': ['không phải chuỗi'],
      'avatar': {'url': 'x'},
    });
    expect(user.id, 12);
    expect(user.name, isNull);
    expect(user.avatar, isNull);
  });
}
