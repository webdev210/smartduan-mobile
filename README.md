# Smart Dự Án

Ứng dụng Flutter cho sales: bảng hàng, chính sách và tài liệu dự án.
M0 hiện chỉ hiển thị trạng thái đang tải; mã React Native tham chiếu nằm ở `legacy-rn/`.

## Chạy ứng dụng

Cài Flutter stable, kết nối thiết bị hoặc mở trình giả lập, rồi chạy:

```sh
flutter pub get
# Máy test
flutter run --dart-define=API_URL=https://dev.smartduan.vn/m/api/v1
# Production
flutter run --dart-define=API_URL=https://smartduan.vn/m/api/v1
```

`API_URL` là cấu hình dự kiến cho M1; M0 chưa đọc biến này hoặc gọi API.
Giá trị mặc định sẽ được triển khai ở M1. Hợp đồng API: `docs/MOBILE-API.md`.

## Bản cài

Android: chạy `flutter build apk --release`; lấy APK tại
`build/app/outputs/flutter-apk/app-release.apk`.
Khi M1 hỗ trợ cấu hình, thêm `--dart-define=API_URL=…` để chọn máy chủ.

IPA chưa ký được tạo trên GitHub Actions: chọn workflow **iOS unsigned IPA** →
**Run workflow** → tải artifact **ios-ipa** → giải nén lấy `app.ipa` → dùng
**Sideloadly** ký bằng Apple ID và cài lên iPhone. Workflow build trên macOS
bằng `flutter build ios --release --no-codesign`, rồi đóng gói `Runner.app`
vào `Payload/`. Không cần build iOS trực tiếp trên Windows.

