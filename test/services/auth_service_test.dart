import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_core_kit/enums/permission_enum.dart';
import 'package:flutter_core_kit/helpers/network.dart';
import 'package:flutter_core_kit/models/account_model.dart';
import 'package:flutter_core_kit/models/interfaces/account_model_interface.dart';
import 'package:flutter_core_kit/repositories/interfaces/login_response_interface.dart';
import 'package:flutter_core_kit/services/auth_service.dart';
import 'package:flutter_core_kit/services/base_services.dart';
import 'package:flutter_core_kit/singletons/account_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Adapter giả: trả response dựng sẵn, ghi lại mọi request. API quyền có response riêng vì login / hồ sơ gọi kèm nó
/// ngay sau.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.reply);

  Future<ResponseBody> Function(RequestOptions options) reply;
  Future<ResponseBody> Function(RequestOptions options) permissionsReply = (_) async => _json(200, _permissions);
  final List<RequestOptions> requests = [];

  RequestOptions? get last => requests.lastOrNull;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return options.path.endsWith('auth/permissions') ? permissionsReply(options) : reply(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Response mẫu của `GET auth/permissions`.
const Map<String, Object?> _permissions = {
  'data': {
    'permissions': ['EXAMPLE', 'OTHER'],
    'success': 1,
  },
};

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// Response đăng nhập thành công: `token` và `user` nằm cạnh `success`, không nằm trong `data`.
Map<String, Object?> _loggedIn({Object? token}) => {
  'data': {
    'token': token ?? {'access_token': 'eyJ0eXAi', 'access_expire': 1793836800, 'token_type': 'Bearer'},
    'user': {'id': 12, 'name': 'Lan Nguyen'},
    'message': 'Logged in successfully',
    'success': 1,
  },
};

/// Response mẫu của `GET auth/me`.
const Map<String, Object?> _profile = {
  'data': {
    'user': {'id': 52, 'name': 'Amélie Legrand', 'email': 'user01@example.com'},
    'success': 1,
  },
};

/// Keystore / Keychain hỏng: ghi / xoá đều ném (đọc thì StorageHandler đã đổi thành null).
class _BrokenSecureStorage extends TestFlutterSecureStoragePlatform {
  _BrokenSecureStorage() : super({});

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) {
    throw PlatformException(code: 'KeyStoreException');
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) {
    throw PlatformException(code: 'KeyStoreException');
  }
}

void main() {
  late _FakeAdapter adapter;

  void breakSecureStorage() {
    FlutterSecureStoragePlatform.instance = _BrokenSecureStorage();
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
  }

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_URL=https://api.test/api');
    // StorageHandler bám kho giả của lần tạo đầu, nên đặt một lần rồi xoá token mỗi test
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    await TokenStorage.clear();
    accountStore.clear();
    globalInternetNotifier.value = true;
    adapter = _FakeAdapter((_) async => _json(200, _loggedIn()));
    final Dio dio = Dio(ApiConfig.baseOptions())..httpClientAdapter = adapter;
    // tokenProvider mặc định: đọc TokenStorage như app thật (test hồ sơ cần token đi kèm request)
    ApiClient.instance = ApiClient(
      dio: dio,
      languageProvider: () async => 'en',
      appVersionProvider: () async => '1.0.0',
    );
  });

  test('thành công: gửi POST auth/login, trả hồ sơ, lưu token', () async {
    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(adapter.requests.first.method, 'POST');
    expect(adapter.requests.first.uri.toString(), 'https://api.test/api/auth/login');
    expect(adapter.requests.first.data, {'email': 'lan@example.com', 'password': '123456'});
    // Login chờ ngắn hơn mặc định 30 giây
    expect(adapter.requests.first.receiveTimeout, const Duration(seconds: 15));
    expect(adapter.requests.first.sendTimeout, const Duration(seconds: 15));
    // 401 của login không kích hoạt luồng mất phiên
    expect(adapter.requests.first.extra[ApiClient.skipUnauthorized], isTrue);

    final AccountModel account = result.data!;
    expect(account.id, 12);
    expect(account.name, 'Lan Nguyen');
    expect(await TokenStorage.read(), 'eyJ0eXAi');
    expect(accountStore.userId, 12);
  });

  test('gửi kèm device_token (mã FCM); không lấy được mã thì không gửi khoá đó', () async {
    await loginService(email: 'lan@example.com', password: '123456', pushToken: () async => 'fcm-abc');
    expect(adapter.requests.first.data, {'email': 'lan@example.com', 'password': '123456', 'device_token': 'fcm-abc'});

    adapter.requests.clear();
    await loginService(email: 'lan@example.com', password: '123456', pushToken: () async => null);
    expect((adapter.requests.first.data as Map<String, dynamic>).containsKey('device_token'), isFalse);
  });

  test('đăng nhập xong lấy quyền kèm token mới, quyền vào accountStore', () async {
    await loginService(email: 'lan@example.com', password: '123456');

    expect(adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'), [
      'POST auth/login',
      'GET auth/permissions',
    ]);
    expect(adapter.last!.headers['Authorization'], 'Bearer eyJ0eXAi');
    expect(accountStore.permissions, ['EXAMPLE', 'OTHER']);
    expect(accountStore.hasPermission(PermissionEnum.example), isTrue);
  });

  test('API quyền lỗi: đăng nhập vẫn thành công, chưa có quyền nào', () async {
    adapter.permissionsReply = (_) async => _json(500, {'message': 'x'});

    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(result.isSuccess, isTrue);
    expect(accountStore.permissions, isEmpty);
  });

  test('đăng nhập lỗi thì không gọi API quyền', () async {
    adapter.reply = (_) async => _json(200, {
      'data': {'message': 'Wrong email or password.', 'success': 0, 'data': []},
    });

    await loginService(email: 'lan@example.com', password: '123456');

    expect(adapter.requests, hasLength(1));
  });

  test('lỗi nghiệp vụ (200 + success 0) → ApiFailure mang nguyên câu BE, không lưu token', () async {
    adapter.reply = (_) async => _json(200, {
      'data': {'message': 'Wrong email or password.', 'success': 0, 'data': []},
    });

    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(
      result.failure,
      isA<ApiFailure>().having((ApiFailure f) => f.message, 'message', 'Wrong email or password.'),
    );
    expect(await TokenStorage.read(), isNull);
  });

  test('422 → error là LoginErrorForm theo từng ô', () async {
    adapter.reply = (_) async => _json(422, {
      'data': {
        'status': 422,
        'message': 'Invalid data transmission',
        'data': {'email': 'That email address is not valid.'},
      },
    });

    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(email: 'lan', password: '123456');

    expect(result.isUnprocessableEntity, isTrue);
    expect(result.error?.emailError, 'That email address is not valid.');
    expect(result.error?.passwordError, isNull);
  });

  test('response thiếu token → ParseFailure, không lưu gì', () async {
    adapter.reply = (_) async => _json(200, _loggedIn(token: {'token_type': 'Bearer'}));

    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(result.failure, isA<ParseFailure>());
    expect(await TokenStorage.read(), isNull);
  });

  test('response thiếu user → ParseFailure, không lưu token', () async {
    adapter.reply = (_) async => _json(200, {
      'data': {
        'token': {'access_token': 'eyJ0eXAi', 'access_expire': 1793836800},
        'success': 1,
      },
    });

    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(result.failure, isA<ParseFailure>());
    expect(await TokenStorage.read(), isNull);
  });

  test('Keystore / Keychain không ghi được token → UnknownFailure để Login cho thử lại, không vào app', () async {
    breakSecureStorage();
    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(result.failure, isA<UnknownFailure>());
    expect(result.message, 'Something went wrong, please try again');
    expect(accountStore.userId, isNull);
    // Không lấy quyền khi chưa có phiên
    expect(adapter.requests, hasLength(1));
  });

  test('mất mạng → NetworkFailure', () async {
    globalInternetNotifier.value = false;
    adapter.reply = (RequestOptions o) async =>
        throw DioException.connectionError(requestOptions: o, reason: 'Failed host lookup');

    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(result.failure, isA<NetworkFailure>());
  });

  test('5xx → ServerFailure kèm mã', () async {
    adapter.reply = (_) async => _json(500, {'message': 'SQLSTATE…'});

    final BaseServices<AccountModel, LoginErrorForm> result = await loginService(
      email: 'lan@example.com',
      password: '123456',
    );

    expect(result.failure, isA<ServerFailure>().having((ServerFailure f) => f.statusCode, 'status', 500));
  });

  group('logoutService', () {
    test('thành công: gửi POST auth/logout, xoá token', () async {
      await TokenStorage.save('eyJ0eXAi');
      adapter.reply = (_) async => _json(200, {
        'data': {'message': 'Log out successfully', 'success': 1},
      });

      accountStore.setAccount(AccountModel(data: const AccountModelInterface(id: 12)));

      final BaseServices<void, void> result = await logoutService();

      expect(accountStore.isLoggedIn, isFalse);
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.uri.toString(), 'https://api.test/api/auth/logout');
      // 401 lúc đăng xuất không kích hoạt luồng "phiên hết hạn"
      expect(adapter.last!.extra[ApiClient.skipUnauthorized], isTrue);
      expect(result.isSuccess, isTrue);
      expect(await TokenStorage.read(), isNull);
    });

    test('401 (token đã bị thu hồi) vẫn tính là đã đăng xuất', () async {
      await TokenStorage.save('eyJ0eXAi');
      adapter.reply = (_) async => _json(401, {});

      expect((await logoutService()).isSuccess, isTrue);
      expect(await TokenStorage.read(), isNull);
    });

    test('Keystore / Keychain xoá lỗi vẫn đăng xuất được, xoá accountStore', () async {
      accountStore.setAccount(AccountModel(data: const AccountModelInterface(id: 12)));
      breakSecureStorage();
      final BaseServices<void, void> result = await logoutService();
      expect(result.isSuccess, isTrue);
      expect(accountStore.userId, isNull);
    });

    test('mất mạng vẫn xoá token và accountStore, chỉ báo lại NetworkFailure', () async {
      await TokenStorage.save('eyJ0eXAi');
      accountStore.setPermissions(['EXAMPLE']);
      globalInternetNotifier.value = false;
      adapter.reply = (RequestOptions o) async =>
          throw DioException.connectionError(requestOptions: o, reason: 'Failed host lookup');

      expect((await logoutService()).failure, isA<NetworkFailure>());
      expect(await TokenStorage.read(), isNull);
      expect(accountStore.permissions, isEmpty);
    });
  });

  group('getProfileService', () {
    setUp(() => adapter.reply = (_) async => _json(200, _profile));

    test('đã đăng nhập: gửi GET auth/me kèm token, trả hồ sơ', () async {
      await TokenStorage.save('eyJ0eXAi');

      final BaseServices<AccountModel, void> result = await getProfileService();

      expect(adapter.requests.first.method, 'GET');
      expect(adapter.requests.first.uri.toString(), 'https://api.test/api/auth/me');
      expect(adapter.requests.first.headers['Authorization'], 'Bearer eyJ0eXAi');
      expect(result.data?.id, 52);
      expect(result.data?.name, 'Amélie Legrand');
      expect(accountStore.account?.name, 'Amélie Legrand');
      // Mở lại app với phiên còn hạn cũng lấy lại quyền
      expect(adapter.last!.path, 'auth/permissions');
      expect(accountStore.permissions, ['EXAMPLE', 'OTHER']);
    });

    test('chưa đăng nhập: UnauthorizedFailure, không gọi API', () async {
      final BaseServices<AccountModel, void> result = await getProfileService();

      expect(result.isUnauthorized, isTrue);
      expect(adapter.last, isNull);
    });

    test('401 (phiên bị thu hồi) → UnauthorizedFailure, xoá token và accountStore', () async {
      await TokenStorage.save('eyJ0eXAi');
      accountStore.setAccount(AccountModel(data: const AccountModelInterface(id: 52)));
      adapter.reply = (_) async => _json(401, {
        'data': {'message': 'Login session has expired'},
      });

      final BaseServices<AccountModel, void> result = await getProfileService();

      expect(result.isUnauthorized, isTrue);
      expect(result.message, 'Login session has expired');
      expect(await TokenStorage.read(), isNull);
      expect(accountStore.isLoggedIn, isFalse);
    });

    test('mất mạng → NetworkFailure, giữ token', () async {
      await TokenStorage.save('eyJ0eXAi');
      globalInternetNotifier.value = false;
      adapter.reply = (RequestOptions o) async =>
          throw DioException.connectionError(requestOptions: o, reason: 'Failed host lookup');

      final BaseServices<AccountModel, void> result = await getProfileService();

      expect(result.failure, isA<NetworkFailure>());
      expect(await TokenStorage.read(), 'eyJ0eXAi');
    });

    test('response thiếu user → ParseFailure', () async {
      await TokenStorage.save('eyJ0eXAi');
      adapter.reply = (_) async => _json(200, {
        'data': {'success': 1},
      });

      expect((await getProfileService()).isParseError, isTrue);
    });
  });

  group('registerDeviceService', () {
    test('đang đăng nhập: gửi mã FCM mới', () async {
      await TokenStorage.save('eyJ0eXAi');
      adapter.reply = (_) async => _json(200, {
        'data': {'success': 1},
      });

      final BaseServices<void, void> result = await registerDeviceService('fcm-new');

      expect(result.isSuccess, isTrue);
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, 'auth/devices');
      expect(adapter.last!.data, {'device_token': 'fcm-new'});
    });

    test('chưa đăng nhập: không gọi API', () async {
      expect((await registerDeviceService('fcm-new')).isUnauthorized, isTrue);
      expect(adapter.requests, isEmpty);
    });
  });
}
