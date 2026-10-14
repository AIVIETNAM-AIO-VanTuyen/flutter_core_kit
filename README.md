# flutter_core_kit

Bộ khung **core** cho app Flutter, tách từ dự án thực tế. Repo không có UI hay design system, vì mỗi app tự dựng phần đó.
Bên trong có sẵn:

| Phần | Ở đâu | Làm gì |
|---|---|---|
| Gọi API | `lib/core/network/` | `ApiClient` (Dio): gắn token / ngôn ngữ / phiên bản app, phân loại lỗi, không ném lỗi, gộp 401, log có che token |
| Kết quả & lỗi | `lib/core/result/` | `Result<T>` (`Ok` / `Err`), `AppFailure` sealed (`NetworkFailure`, `ValidationFailure`…) |
| Tầng dữ liệu | `lib/models/`, `lib/repositories/`, `lib/services/` | Khung Interface → Model → Repository → Service, `BaseServices` cho UI |
| Lưu trữ | `lib/singletons/storage_handler.dart` | shared_preferences + token trong Keychain / Keystore, chịu được kho bảo mật hỏng |
| Phiên đăng nhập | `lib/services/auth_service.dart`, `lib/singletons/account_store.dart` | đăng nhập / đăng xuất / hồ sơ / quyền, 401 → về Đăng nhập kèm câu BE |
| Điều hướng | `lib/routes/` | go_router, `AppNavigator` (không cần context), middleware quyền, link lạ |
| Firebase | `lib/config/` | push (FCM + thông báo local), analytics không bao giờ ném |
| Theme | `lib/core/theme/` | khung token (màu, khoảng cách, bo góc, bóng, chữ, chuyển động) với giá trị mẫu |
| Màn mẫu | `lib/modules/` | Splash, Login, Home, NotFound bằng widget Material thuần, để thay |
| Test | `test/` | ~150 test cho các phần trên, giả `ApiClient`, kho, đồng hồ |

## Tạo app mới từ kit

1. Tạo repo từ template này (GitHub: **Use this template**) rồi clone về.
2. Đổi tên package và bundle id:
   - `pubspec.yaml`: `name: <ten_app>`, rồi thay `package:flutter_core_kit/` thành `package:<ten_app>/` trong `test/`.
   - Android: `namespace` và `applicationId` trong `android/app/build.gradle.kts`, thư mục
     `android/app/src/main/kotlin/com/example/flutter_core_kit/` (MainActivity), `android:label` trong AndroidManifest.
   - iOS: `PRODUCT_BUNDLE_IDENTIFIER` trong `ios/Runner.xcodeproj/project.pbxproj`, `CFBundleDisplayName` trong `Info.plist`.
3. `cp .env.example .env` rồi sửa `API_URL`. Bắt buộc trước cả `flutter test` / CI: `.env` khai là asset nhưng bị
   gitignore. Thiếu file hoặc thiếu `API_URL` thì Splash hiện lỗi thay vì vào app.
4. Firebase: `flutterfire configure`, hoặc thả `google-services.json` vào `android/app/` và `GoogleService-Info.plist`
   vào `ios/Runner/`. Android còn phải thêm plugin `com.google.gms.google-services` vào `settings.gradle.kts` và
   `app/build.gradle.kts`. Chưa cấu hình thì app vẫn chạy, chỉ không có push / analytics. Các file này đã nằm trong
   `.gitignore`.
5. iOS push: bật capability *Push Notifications* và *Background Modes → Remote notifications* trong Xcode, rồi tải
   APNs key lên Firebase.
6. Theo backend thật, sửa:
   - `ApiConfig` (`tokenPrefix`, timeout, mã `success`), `BaseResponse.fromHttp` / `envelopeOf` nếu envelope khác
     `{"data": {"success", "message", "data"}}`.
   - `auth_repository.dart` (path), các interface trong `repositories/interfaces/`, `models/` theo response mẫu thật.
   - `PermissionEnum` theo mã quyền của BE.
7. Thay các màn trong `lib/modules/` và giá trị token trong `lib/core/theme/` bằng design system của app.

## Chạy

Dự án ghim Flutter **3.47.6** qua FVM (`.fvmrc`):

```sh
fvm install && fvm flutter pub get
fvm flutter run
fvm flutter analyze lib test
fvm flutter test
```

Android: AGP 9.1 · Gradle 9.3.1 · Kotlin 2.4 (mặc định của `flutter create` bản 3.47.6). Thêm package có phần native
thì build thử `flutter build apk --debug`, rồi dừng hẳn app và chạy lại (hot restart không nạp plugin mới).

## Cách dùng nhanh

**Gọi API mới** theo đủ 4 tầng. Ví dụ đầy đủ là luồng đăng nhập: `login_response_interface.dart` →
`account_model.dart` → `auth_repository.dart` → `auth_service.dart` → `login_page.dart`.

```dart
// repositories/order_repository.dart: chỉ gọi, không đọc JSON, không ném lỗi
Future<BaseResponse> getOrdersApi({int page = 1}) => ApiClient.instance.get('orders', query: {'page': page});

// services/order_service.dart: đọc JSON thành model, lỗi thành AppFailure
Future<BaseServices<List<OrderModel>, void>> getOrdersService() async {
  final BaseServices<OrdersResponseInterface, void> res = BaseServices.from(
    await getOrdersApi(),
    parser: OrdersResponseInterface.fromJson,
  );
  return res.map((OrdersResponseInterface data) => [for (final OrderInterface o in data.orders) OrderModel(data: o)]);
}

// màn hình: xử lý theo loại lỗi
final BaseServices<List<OrderModel>, void> res = await getOrdersService();
if (!mounted) return;
switch (res.failure) {
  case null: showList(res.data!);
  case NetworkFailure(): showOffline();
  case ValidationFailure(): showFieldErrors(res.error);
  default: showError(res.message);
}
```

**Điều hướng** từ bất kỳ đâu: `AppNavigator.go(AppRoutes.home)`, `AppNavigator.push<bool>('/scan')`, `AppNavigator.back(true)`.

**Push**: gán `pushService.onTap = (data) => AppNavigator.push(...)` ở màn đã đăng nhập (ví dụ `initState` của Home),
không gán ở `main`, vì Splash xong sẽ thay cả stack. Cú bấm tới trước đó được giữ lại tới khi gán. Gọi
`pushService.requestPermission()` vào lúc hợp lý, không xin ngay lúc mở app.

**Lưu ý backend**: `ApiClient` gửi header `language` và `X-App-Version`, đồng thời bỏ khoá `_debugbar` (Laravel
debugbar) khỏi log. Backend khác thì sửa ở `interceptors.dart`.

**Quyền**: `accountStore.hasPermission(PermissionEnum.x)` để ẩn hoặc hiện chức năng; route cần quyền thì thêm
`redirect: (_, _) => permissionMiddleware(PermissionEnum.x)`.

## Quy ước

Quy tắc code (đặt tên, comment, try-catch, test…) nằm trong `CLAUDE.md`, đọc trước khi thêm tính năng.
