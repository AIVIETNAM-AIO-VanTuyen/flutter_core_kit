import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_core_kit/core/network/api_client.dart';
import 'package:flutter_core_kit/core/result/result.dart';
import 'package:flutter_core_kit/helpers/network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Adapter giả: trả response dựng sẵn, ghi lại request cuối.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.reply);

  Future<ResponseBody> Function(RequestOptions options) reply;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    last = options;
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, Object?> _envelope(Object? data, {int success = 1, String? message}) {
  return {
    'data': {'success': success, 'message': message, 'data': data},
  };
}

void main() {
  late _FakeAdapter adapter;
  late ApiClient api;
  String? token;
  String? storedToken;

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_URL=https://api.test/api');
  });

  setUp(() {
    token = 'abc';
    storedToken = 'abc';
    globalInternetNotifier.value = true;
    adapter = _FakeAdapter((_) async => _json(200, _envelope(null)));
    final Dio dio = Dio(ApiConfig.baseOptions())..httpClientAdapter = adapter;
    api = ApiClient(
      dio: dio,
      tokenProvider: () async => token,
      storedTokenProvider: () async => storedToken,
      languageProvider: () async => 'en',
      appVersionProvider: () async => '1.0.0',
    );
  });

  test('bóc envelope: body là lớp chứa success, giữ message và data', () async {
    adapter.reply = (_) async => _json(200, _envelope({'id': 7}, message: 'Đã lưu'));
    final BaseResponse res = await api.get('v1/x');
    expect(res.isSuccessApi, isTrue);
    expect(res.statusCode, 200);
    expect(res.success, 1);
    expect(res.data, {'id': 7});
    expect(res.message, 'Đã lưu');
    expect(res.body, containsPair('success', 1));
  });

  test('gắn token (kèm tiền tố Bearer), language và nối path sau /api', () async {
    await api.get('v1/capsules', query: {'page': 1});
    expect(adapter.last!.headers['Authorization'], 'Bearer abc');
    expect(adapter.last!.headers['language'], 'en');
    expect(adapter.last!.uri.toString(), '${ApiConfig.baseUrl}/v1/capsules?page=1');
  });

  test('gửi phiên bản app, không gửi nền tảng', () async {
    await api.get('v1/x');
    expect(adapter.last!.headers['X-App-Version'], '1.0.0');
    expect(adapter.last!.headers.containsKey('X-Platform'), isFalse);
  });

  test('chưa đăng nhập thì không gửi Authorization', () async {
    token = null;
    await api.get('v1/x');
    expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
  });

  test('body không theo envelope thì body là nguyên JSON', () async {
    adapter.reply = (_) async => _json(200, {'ok': true});
    final BaseResponse res = await api.get('v1/x');
    expect(res.isSuccessApi, isTrue);
    expect(res.body, {'ok': true});
    expect(res.raw, {'ok': true});
  });

  test('success != 1 → isFailSuccess với message server, không ném, giữ body', () async {
    adapter.reply = (_) async => _json(200, _envelope(null, success: 0, message: 'Sai mật khẩu'));
    final BaseResponse res = await api.post('v1/login', body: {'a': 1});
    expect(res.isSuccessApi, isFalse);
    expect(res.isFailSuccess, isTrue);
    expect(res.failure, isA<ApiFailure>().having((ApiFailure f) => f.message, 'message', 'Sai mật khẩu'));
    expect(res.message, 'Sai mật khẩu');
    expect(res.success, 0);
  });

  test('success là true / "1" vẫn tính là thành công, không ném khi đọc', () async {
    for (final Object value in [true, '1']) {
      adapter.reply = (_) async => _json(200, {
        'data': {'success': value, 'message': null, 'data': null},
      });
      final BaseResponse res = await api.get('v1/x');
      expect(res.isSuccessApi, isTrue, reason: '$value');
      expect(res.success, 1, reason: '$value');
    }
  });

  test('422 → validation kèm lỗi từng trường', () async {
    adapter.reply = (_) async => _json(
      422,
      _envelope(
        {
          'email': ['Email không hợp lệ'],
          'name': 'Bắt buộc',
        },
        success: 0,
        message: 'Dữ liệu sai',
      ),
    );
    final BaseResponse res = await api.post('v1/x');
    expect(res.isUnprocessableEntity, isTrue);
    expect(res.statusCode, 422);
    expect(res.message, 'Dữ liệu sai');
    expect(res.errors, {
      'email': ['Email không hợp lệ'],
      'name': 'Bắt buộc',
    });
    expect((res.failure! as ValidationFailure).firstErrorOf('name'), 'Bắt buộc');
  });

  test('500 → server, không lộ message kỹ thuật', () async {
    adapter.reply = (_) async => _json(500, {'message': 'SQLSTATE[42S22]'});
    final BaseResponse res = await api.get('v1/x');
    expect(res.isServerError, isTrue);
    expect(res.message, isNot(contains('SQL')));
    expect(res.errors, isNull);
  });

  test('401 → báo onUnauthorized một lần cho nhiều request cùng lúc, kèm câu BE', () async {
    final List<String> messages = [];
    api.onUnauthorized = messages.add;
    adapter.reply = (_) async => _json(401, {
      'data': {'message': 'Login session has expired'},
    });
    final List<BaseResponse> responses = await Future.wait([for (int i = 0; i < 3; i++) api.get('v1/x')]);
    expect(responses.every((BaseResponse r) => r.isUnauthorized), isTrue);
    expect(messages, ['Login session has expired']);
  });

  test('401 về muộn của request gửi bằng token cũ (đã đăng nhập lại) thì không báo', () async {
    int calls = 0;
    api.onUnauthorized = (_) => calls++;
    adapter.reply = (_) async {
      // Trong lúc request chậm còn chạy, người dùng đăng nhập lại
      token = 'new';
      storedToken = 'new';
      return _json(401, _envelope(null, success: 0));
    };
    final BaseResponse res = await api.get('v1/slow');
    expect(adapter.last!.headers['Authorization'], 'Bearer abc');
    expect(res.isUnauthorized, isTrue);
    expect(calls, 0);
  });

  test('401 sau khi phiên cũ đã bị xoá (token đã gỡ) thì không báo lần nữa', () async {
    int calls = 0;
    api.onUnauthorized = (_) => calls++;
    adapter.reply = (_) async {
      token = null;
      storedToken = null;
      return _json(401, _envelope(null, success: 0));
    };
    await api.get('v1/slow');
    expect(calls, 0);
  });

  test('token trên máy đã quá hạn (không gửi Authorization) mà 401 thì vẫn báo mất phiên', () async {
    // TokenStorage.read() lọc hạn nên trả null, nhưng kho vẫn còn token
    token = null;
    int calls = 0;
    api.onUnauthorized = (_) => calls++;
    adapter.reply = (_) async => _json(401, _envelope(null, success: 0));
    await api.get('v1/x');
    expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
    expect(calls, 1);
  });

  test('chưa đăng nhập (kho không có token) mà 401 thì không báo mất phiên', () async {
    token = null;
    storedToken = null;
    int calls = 0;
    api.onUnauthorized = (_) => calls++;
    adapter.reply = (_) async => _json(401, _envelope(null, success: 0));
    final BaseResponse res = await api.post('auth/login');
    expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
    expect(res.isUnauthorized, isTrue);
    expect(calls, 0);
  });

  test('request đánh dấu skipUnauthorized thì 401 không báo', () async {
    int calls = 0;
    api.onUnauthorized = (_) => calls++;
    adapter.reply = (_) async => _json(401, _envelope(null, success: 0));
    final BaseResponse res = await api.post(
      'auth/logout',
      options: Options(extra: {ApiClient.skipUnauthorized: true}),
    );
    expect(res.isUnauthorized, isTrue);
    expect(calls, 0);
  });

  test('401 không kèm câu của request ngoài phiên (đăng nhập) không nói "hết phiên"', () async {
    adapter.reply = (_) async => _json(401, _envelope(null, success: 0));
    final BaseResponse login = await api.post('auth/login', options: Options(extra: {ApiClient.skipUnauthorized: true}));
    expect(login.isUnauthorized, isTrue);
    expect(login.message, 'Something went wrong, please try again');
    expect((await api.get('auth/me')).message, 'Login session has expired');
  });

  test('401 lúc chưa gắn onUnauthorized không chặn lần báo ngay sau khi gắn', () async {
    adapter.reply = (_) async => _json(401, _envelope(null, success: 0));
    await api.get('v1/x');
    final List<String> messages = [];
    api.onUnauthorized = messages.add;
    await api.get('v1/x');
    expect(messages, ['Login session has expired']);
  });

  test('lỗi kết nối: mất mạng và server không phản hồi đều là lỗi mạng, khác câu báo', () async {
    adapter.reply = (RequestOptions o) async =>
        throw DioException.connectionError(requestOptions: o, reason: 'Failed host lookup');
    globalInternetNotifier.value = false;
    final BaseResponse offline = await api.get('v1/x');
    expect(offline.isNetworkError, isTrue);
    expect(offline.message, 'Access the Internet to continue');
    expect(offline.statusCode, isNull);
    globalInternetNotifier.value = true;
    final BaseResponse online = await api.get('v1/x');
    expect(online.isNetworkError, isTrue);
    expect(online.message, 'System under maintenance, please try again later');
  });

  test('huỷ qua CancelToken → cancelled', () async {
    final CancelToken cancel = CancelToken();
    adapter.reply = (RequestOptions o) async {
      cancel.cancel();
      throw DioException.requestCancelled(requestOptions: o, reason: null);
    };
    expect((await api.get('v1/x', cancelToken: cancel)).isCancelled, isTrue);
  });

  test('base URL lấy từ .env', () {
    expect(ApiConfig.baseUrl, 'https://api.test/api');
  });

  group('TokenStorage', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('lưu, đọc, xoá token', () async {
      expect(await TokenStorage.read(), isNull);
      await TokenStorage.save('xyz', expiresAt: DateTime.now().add(const Duration(days: 1)));
      expect(await TokenStorage.read(), 'xyz');
      expect(await TokenStorage.hasToken, isTrue);
      await TokenStorage.clear();
      expect(await TokenStorage.read(), isNull);
    });

    test('token hết hạn coi như chưa đăng nhập', () async {
      await TokenStorage.save('xyz', expiresAt: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(await TokenStorage.read(), isNull);
      // Kho vẫn còn token: interceptor 401 dùng để biết máy còn phiên đã hết hạn
      expect(await TokenStorage.readRaw(), 'xyz');
    });

    test('ApiClient mặc định gắn token từ TokenStorage', () async {
      await TokenStorage.save('from-prefs');
      final Dio dio = Dio(ApiConfig.baseOptions())..httpClientAdapter = adapter;
      await ApiClient(
        dio: dio,
        languageProvider: () async => null,
        appVersionProvider: () async => '1.0.0',
      ).get('v1/x');
      expect(adapter.last!.headers['Authorization'], 'Bearer from-prefs');
    });
  });

  test('ApiPage đọc trang Laravel', () {
    final ApiPage<int> page = ApiPage.fromJson({
      'data': [
        {'id': 1},
        {'id': 2},
      ],
      'current_page': 1,
      'last_page': '3',
      'total': 25,
    }, (Map<String, dynamic> m) => m['id'] as int);
    expect(page.items, [1, 2]);
    expect(page.hasMore, isTrue);
    expect(page.total, 25);
  });
}
