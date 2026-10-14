import 'package:flutter_core_kit/enums/permission_enum.dart';
import 'package:flutter_core_kit/models/account_model.dart';
import 'package:flutter_core_kit/models/interfaces/account_model_interface.dart';
import 'package:flutter_core_kit/singletons/account_store.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(accountStore.clear);

  test('setAccount: giữ tài khoản, báo người nghe', () {
    int notified = 0;
    void listener() => notified++;
    accountStore.addListener(listener);
    addTearDown(() => accountStore.removeListener(listener));

    accountStore.setAccount(AccountModel(data: const AccountModelInterface(id: 52)));

    expect(accountStore.isLoggedIn, isTrue);
    expect(accountStore.userId, 52);
    expect(notified, 1);
  });

  test('clear: xoá tài khoản; đang trống thì không báo lại', () {
    accountStore.setAccount(AccountModel(data: const AccountModelInterface(id: 52)));
    int notified = 0;
    void listener() => notified++;
    accountStore.addListener(listener);
    addTearDown(() => accountStore.removeListener(listener));

    accountStore.clear();
    accountStore.clear();

    expect(accountStore.account, isNull);
    expect(accountStore.isLoggedIn, isFalse);
    expect(notified, 1);
  });

  test('quyền: setPermissions / hasPermission; clear xoá cả quyền', () {
    accountStore.setPermissions(['OTHER']);
    expect(accountStore.hasPermission(PermissionEnum.example), isFalse);

    accountStore.setPermissions(['OTHER', 'EXAMPLE']);
    expect(accountStore.hasPermission(PermissionEnum.example), isTrue);

    accountStore.clear();
    expect(accountStore.permissions, isEmpty);
  });

  test('sessionNotice: takeSessionNotice lấy một lần rồi xoá', () {
    accountStore.setSessionNotice('Logged in on another device');
    expect(accountStore.takeSessionNotice(), 'Logged in on another device');
    expect(accountStore.takeSessionNotice(), isNull);
  });

  test('CHECK_PERMISSION=false trong .env: bỏ kiểm tra, quyền nào cũng có', () {
    dotenv.loadFromString(envString: 'CHECK_PERMISSION=false');
    addTearDown(() => dotenv.loadFromString(envString: 'CHECK_PERMISSION=true'));

    expect(accountStore.permissions, isEmpty);
    expect(accountStore.hasPermission(PermissionEnum.example), isTrue);
  });
}
