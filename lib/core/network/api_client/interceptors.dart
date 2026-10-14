part of '../api_client.dart';

/// Gắn token, ngôn ngữ, phiên bản app. Đọc kho mỗi request để đăng nhập / đăng xuất có hiệu lực ngay.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required this.tokenProvider, required this.languageProvider, required this.appVersionProvider});

  final ApiTokenProvider tokenProvider;
  final ApiLanguageProvider languageProvider;
  final ApiAppVersionProvider appVersionProvider;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final String? token = await tokenProvider();
    if (token != null && token.isNotEmpty) options.headers['Authorization'] ??= '${ApiConfig.tokenPrefix}$token';
    final String? language = await languageProvider();
    if (language != null && language.isNotEmpty) options.headers['language'] ??= language;
    options.headers['X-App-Version'] ??= await appVersionProvider();
    handler.next(options);
  }
}

/// Báo 401 cho app kèm câu BE gửi; nhiều request cùng 401 một lúc chỉ báo một lần. Request có `extra[ApiClient.skipUnauthorized] == true` (vd đăng xuất) không báo.
///
/// Chỉ báo khi máy còn phiên (token trong kho, kể cả đã quá hạn) và 401 thuộc phiên đó:
/// - kho không có token: chưa đăng nhập hoặc phiên đã bị xoá (401 đầu đã báo) → bỏ qua;
/// - không gửi token: token trên máy đã quá hạn nên interceptor không gắn → vẫn báo, nếu không người dùng kẹt lại;
/// - gửi token khác token trong kho: request chậm của phiên cũ (về sau hơn [_window], receiveTimeout tới 30 giây),
///   báo nữa sẽ xoá phiên vừa đăng nhập lại → bỏ qua.
class _UnauthorizedInterceptor extends Interceptor {
  _UnauthorizedInterceptor({required this.storedTokenProvider, required this.notify});

  /// Các 401 về lệch nhau trong khoảng này được gộp thành một lần báo
  static const Duration _window = Duration(seconds: 3);

  /// Token trong kho, không lọc hạn ([TokenStorage.readRaw])
  final ApiTokenProvider storedTokenProvider;
  /// Báo cho app; `false` khi chưa có ai nhận ([ApiClient.onUnauthorized] còn `null`)
  final bool Function(String message) notify;
  DateTime? _lastNotified;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && err.requestOptions.extra[ApiClient.skipUnauthorized] != true) {
      if (await _belongsToStoredSession(err.requestOptions)) {
        final DateTime now = clock.now();
        final DateTime? last = _lastNotified;
        if (last == null || now.difference(last) > _window) {
          // Chỉ ghi mốc khi đã có nơi nhận: 401 lúc chưa gắn handler không được chặn 401 thật ngay sau đó
          if (notify(ApiException.fromStatus(401, err.response?.data).message)) _lastNotified = now;
        }
      }
    }
    handler.next(err);
  }

  Future<bool> _belongsToStoredSession(RequestOptions options) async {
    final String? stored = await storedTokenProvider();
    if (stored == null) return false;
    final Object? sent = options.headers['Authorization'];
    return sent == null || sent == '' || sent == '${ApiConfig.tokenPrefix}$stored';
  }
}

/// Khoá bị che khi in log (không ghi mật khẩu, token vào log), viết thường.
const Set<String> _secretKeys = {
  'password',
  'password_confirmation',
  'current_password',
  'new_password',
  'token',
  'access_token',
  'refresh_token',
  'api_token',
  'authorization',
  'device_token',
  'fcm_token',
};

/// Bản sao của [data] với mọi giá trị dưới [_secretKeys] (không phân biệt hoa thường) thay bằng `***`, ở mọi tầng
/// lồng nhau. Khoá bí mật mà giá trị là object (login: `token: {access_token, access_expire}`) thì che từng khoá
/// bên trong, để log còn thấy hạn token.
Object? _maskSecrets(Object? data) => switch (data) {
  final Map<dynamic, dynamic> map => {
    for (final MapEntry<dynamic, dynamic> e in map.entries)
      e.key: _secretKeys.contains('${e.key}'.toLowerCase()) && e.value != null && e.value is! Map
          ? '***'
          : _maskSecrets(e.value),
  },
  final List<dynamic> list => [for (final Object? item in list) _maskSecrets(item)],
  _ => data,
};

/// Log ở debug: method, URL, thời gian và JSON body hai chiều. Không in header (token); mật khẩu, token trong body
/// bị che ([_secretKeys]).
class _LogInterceptor extends Interceptor {
  static const String _startKey = '_apiStart';

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = clock.now();
    debugPrint('[API] → ${options.method} ${options.uri}');
    if (options.data != null) _printJson('[API] → body', _maskSecrets(options.data));
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('[API] ← ${response.statusCode} ${response.requestOptions.uri} ${_elapsed(response.requestOptions)}');
    _printJson('[API] ← body', _maskSecrets(_withoutDebugbar(response.data)));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final RequestOptions o = err.requestOptions;
    debugPrint('[API] ✕ ${err.response?.statusCode ?? err.type.name} ${o.method} ${o.uri} ${_elapsed(o)}');
    if (err.response?.data != null) _printJson('[API] ✕ body', _maskSecrets(_withoutDebugbar(err.response!.data)));
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final Object? start = options.extra[_startKey];
    return start is DateTime ? '${clock.now().difference(start).inMilliseconds}ms' : '';
  }

  void _printJson(String label, Object? data) {
    // FormData / stream không encode được thành JSON thì in kiểu của nó
    final String text = data is Map || data is List ? _encoder.convert(data) : '$data';
    // debugPrint in từng dòng và giãn nhịp, log dài không bị logcat Android cắt / bỏ như print
    debugPrint('$label:\n$text');
  }

  /// Laravel debugbar (BE local bật debug) gắn `_debugbar` vào mọi JSON, dài hàng trăm dòng
  Object? _withoutDebugbar(Object? data) {
    if (data is! Map || !data.containsKey('_debugbar')) return data;
    return Map<dynamic, dynamic>.of(data)..remove('_debugbar');
  }
}
