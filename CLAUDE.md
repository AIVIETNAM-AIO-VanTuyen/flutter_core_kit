# Quy tắc dự án

App Flutter dựng từ `flutter_core_kit`: phần core (API, lỗi, lưu trữ, phiên, router, Firebase) có sẵn, UI tự dựng.
Khi dựng app mới từ kit: sửa dòng trên thành mô tả app, thêm mục design system của app bên dưới.

## Giao tiếp
- Trả lời người dùng bằng **tiếng Việt**. Comment trong code cũng viết tiếng Việt, ngắn, nói *vì sao* chứ không nhắc lại code.
- Cuối mỗi việc, báo rõ: file mới/đổi, cách dùng, kết quả analyze/test, và **chỗ lệch spec hoặc chỗ tự quyết** để người dùng duyệt.
- Chỉ commit khi được yêu cầu. Không tự `git rm`, không tự xoá file đã có.

## Git
- Nhánh mới: `feature/<tên-nhánh>` (viết thường, gạch ngang, không dấu), tạo từ `dev` mới nhất và **bắt buộc `--no-track`**:
  `git fetch origin && git switch -c feature/<tên-nhánh> --no-track origin/dev`. Thiếu `--no-track` thì upstream là
  `origin/dev`, bấm Push/Sync trong VS Code sẽ đẩy thẳng vào `dev`. Lần push đầu: `git push -u origin feature/<tên-nhánh>`.
- Đang có thay đổi chưa commit thì hỏi người dùng trước khi đổi nhánh (mang theo, stash hay commit).

## Toolchain
- Flutter ghim ở `.fvmrc` (3.47.6), gọi qua FVM (`fvm flutter …`). `.fvm/` bị gitignore.
- Trước khi thêm/nâng package: chọn bản hợp với Flutter / Dart đang ghim (xem `environment` trên pub.dev); package có
  phần native → build thử `flutter build apk --debug`.
- Thêm package có native thì phải **dừng hẳn app và chạy lại**; hot reload/restart không nạp plugin mới.

## Định dạng code
- Chỉ format file **mới tạo**: `dart format -l 120 <file>`. File có sẵn thì sửa tay theo style xung quanh, không format hàng loạt.
- Dòng tối đa ~120 ký tự. Khai kiểu rõ cho biến local (`final Color color = …`).
- Callback viết `void Function()`, không dùng `VoidCallback`.

## Cấu trúc
```
lib/
  config/        Firebase, PushService, AnalyticsService
  constants/     navigatorKey, messengerKey, AppStorageKeys
  core/
    network/     ApiClient + part (config, exception, interceptors, token_storage, base_response, api_page)
    result/      Result, AppFailure
    theme/       token giao diện
    utils/       tiện ích thuần Dart
  enums/         PermissionEnum…
  helpers/       mạng, FCM token
  models/        XModel + interfaces/XInterface
  repositories/  xApi() + interfaces/ (response bọc riêng, response_parse)
  routes/        AppRoutes, appRouter, AppNavigator, middleware
  services/      xService(), BaseServices
  singletons/    StorageHandler, AccountStore
  modules/<màn>/ màn hình
```
- Giữ mỗi file dưới ~400 dòng; dài hơn thì tách `part` theo vai trò. Class nội bộ để private (`_`).

## Token giao diện (`lib/core/theme/`)
- Widget chỉ dùng token: `AppColors`, `AppSpacing`, `AppRadius` / `AppBorderRadius`, `AppBorders`, `AppShadows`,
  `AppIconSize`, `AppMotion`, `AppText` / `AppFont`.
- **Màu và bóng chỉ nằm trong `app_tokens.dart`**: không viết `Color(0x…)` / `BoxShadow(...)` trong widget. Số đo riêng
  của component mà thang không có → hằng có tên + comment nguồn, không rải số trần.
- Vùng chạm ≥ 44×44 (`AppSpacing.minTouch`). Phần tử chỉ có icon phải có `Semantics(label: …)`.
- Chữ không cố định chiều cao (hỗ trợ phóng chữ), dùng `minHeight`.

## Trạng thái & bất đồng bộ
- `AnimationController` tạo trong `initState`, **không** `late final … = AnimationController(...)` lazy (lần đầu đụng
  tới có thể là trong `dispose` → crash).
- Đo thời gian bằng `clock.now()` (package `clock`), không `DateTime.now()`, để test giả được thời gian.
- Overlay (dialog, sheet) push lên root navigator; hàm `show…` trả Future xong **sau** animation đóng.
- Snackbar từ nơi không có context: `messengerKey.currentState` (đã gắn ở `MaterialApp`).
- Điều hướng không cần context: `AppNavigator` (`go` thay cả stack, `push`, `pushReplacement`, `back`).
- **Hạn chế `try-catch`.** Không bọc theo thói quen hay chỉ để nuốt lỗi bằng `debugPrint`; để lỗi nổi lên. Chỉ bắt khi
  có cách xử lý thật (fallback cụ thể, báo lỗi cho người dùng, thử lại) hoặc ở ranh giới không được để app chết (khởi
  động app, analytics). Bắt thì bắt đúng loại lỗi khi được, và comment vì sao cần bắt.

## Triển khai API (theo khung đăng nhập)
- **Cần trước**: method, path, tham số, phân trang; **response mẫu thật** cả thành công lẫn lỗi (422, `success: 0`);
  màn dùng và chỗ hiện lỗi; có cần token không. BE trả khác tài liệu thì báo, không đoán.
- **Interface** `lib/models/interfaces/<x>_interface.dart` (lớp bọc response như token + user thì ở
  `lib/repositories/interfaces/`): field `final` nullable đúng kiểu BE, `fromJson` / `toJson`, đọc mềm bằng
  `asInt` / `asString` (`response_parse.dart`), viết theo response thật.
- **Model** `lib/models/<x>_model.dart`: `XModel({required XInterface data})`, mặc định khi thiếu field, đổi kiểu cho
  UI (0/1 → bool, chuỗi ngày → DateTime). Không `fromJson`, không ném lỗi.
- **Repository** `lib/repositories/<nhóm>_repository.dart`: `Future<BaseResponse> xApi(...)` qua `ApiClient.instance`,
  không ném lỗi, không đọc dữ liệu; tuỳ chỉnh qua `Options` (timeout, `ApiClient.skipUnauthorized`) kèm comment lý do.
- **Service** `lib/services/<nhóm>_service.dart`: `BaseServices.from(response, parser:, errorParser:)` rồi `.map` sang
  model; việc đi kèm (store, kho) làm ở đây; khai `typedef` để màn nhận bản giả; doc liệt kê các `AppFailure` có thể trả.
- **Màn hình**: xử lý theo loại lỗi (422 → lỗi từng ô, còn lại → câu lỗi chung / mất mạng / thử lại); không gọi trùng
  khi bấm liên tục, bỏ kết quả về muộn khi đã rời màn (`if (!mounted) return`).
- Khoá lưu ở `storage_keys.dart`; dữ liệu nhạy cảm thêm vào `_secureKeys` của `StorageHandler` (Keychain / Keystore).

## Quy trình làm tính năng mới
1. **Đọc và đối chiếu trước khi code**: tài liệu ticket (AC) + design. Liệt kê chỗ vênh và chỗ app chưa có (i18n, mã
   lỗi BE…) để người dùng chốt **một lần từ đầu**.
2. **Nhánh riêng** mỗi tính năng.
3. **Tính các tình huống từ đầu**: mạng chậm (loading sau `AppMotion.loadingDelay`, tối thiểu `loadingMin`), bấm liên
   tục, lỗi từng ô / lỗi chung / mất mạng / hết phiên, Back Android, vào nền rồi mở lại, chữ 200%, màn nhỏ (360×640),
   TalkBack / VoiceOver.
4. **Test theo AC** (tên test ghi mã AC). Sửa lỗi nào thì thử bỏ bản sửa xem test có fail không.
5. **Rà trước khi báo xong**: cho một agent review độc lập phần vừa làm; `flutter analyze lib test` sạch, `flutter test`
   pass toàn bộ.

## Test
- Đặt theo đường dẫn trong `lib/` (vd `test/services/…`, `test/modules/login/…`), mỗi trạng thái/hành vi chính một test.
- Giả API: thay `ApiClient.instance = ApiClient(dio: dio)` với `HttpClientAdapter` giả (xem `auth_service_test.dart`).
- Giả kho: `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()` và
  `FlutterSecureStorage.setMockInitialValues({})`.
- Màn nhận service qua tham số (`typedef`), test truyền bản giả.
- Có spinner/animation lặp → không `pumpAndSettle`, dùng vòng `pump(Duration)`.
- Biến static giữ Future (kho `StorageHandler`, `rootBundle`) mà tạo lần đầu trong `testWidgets` thì test sau await sẽ
  treo: nạp sẵn trong `setUpAll` (xem `splash_page_test.dart`).
- Plugin native (Firebase…) → giả platform instance trong test.
