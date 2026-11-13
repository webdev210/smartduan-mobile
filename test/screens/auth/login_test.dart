import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/screens/auth/login.dart';
import 'package:smartduan/ui/otp_step.dart';

import 'auth_fakes.dart';
import 'fakes.dart';

void main() {
  testWidgets('login displays the RN Smartland logo', (tester) async {
    final api = TestAuth();
    addTearDown(api.client.close);
    await tester.pumpWidget(authApp(const LoginScreen(), api, TestSession()));
    final logo = tester.widget<Image>(find.byType(Image));
    expect(logo.image, const AssetImage('assets/smartland-mark.png'));
    expect(logo.semanticLabel, 'Smartland');
    expect(logo.width, 52);
    expect(logo.height, 52);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final failureAt in [null, 'health', 'provinces']) {
    testWidgets('connection check displays result with failure at $failureAt', (
      tester,
    ) async {
      final api = TestAuth();
      final public = ConnectionApi(failureAt);
      addTearDown(api.client.close);
      addTearDown(public.client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [publicApiProvider.overrideWithValue(public)],
          child: authApp(const LoginScreen(), api, TestSession()),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.bySemanticsLabel('Kiểm tra kết nối máy chủ');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      if (failureAt == null) {
        expect(
          find.textContaining(RegExp(r'^Kết nối OK · 2 tỉnh/thành · \d+ms$')),
          findsOneWidget,
        );
      } else {
        expect(find.text('Máy chủ tạm ngừng'), findsOneWidget);
      }
      expect(
        public.calls,
        failureAt == 'health' ? ['health'] : ['health', 'provinces'],
      );
    });
  }
  testWidgets('login disabled until fields filled, trims email and signs in', (
    tester,
  ) async {
    final api = TestAuth();
    addTearDown(api.client.close);
    final session = TestSession(reason: 'password_reset');
    await tester.pumpWidget(
      authApp(const LoginScreen(notice: 'Thông báo'), api, session),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Mật khẩu vừa được đổi, vui lòng đăng nhập lại'),
      findsOneWidget,
    );
    expect(find.text('Thông báo'), findsOneWidget);
    await tapText(tester, 'Đăng nhập');
    expect(api.logins, isEmpty);
    await tester.enterText(find.byType(TextField).at(0), ' A@B.vn ');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tapText(tester, 'Đăng nhập');
    expect(api.logins, [
      ['A@B.vn', 'password'],
    ]);
    expect(session.tokens, ['jwt']);
  });
  for (final (error, message) in <(Object, String)>[
    (
      const ApiError(401, 'invalid_credentials', 'bad'),
      'Email hoặc mật khẩu không đúng',
    ),
    (
      const ApiError(
        423,
        'account_temporarily_locked',
        'Khoá',
        retryAfter: 120,
        body: {'message': 'Chờ 120 giây'},
      ),
      'Chờ 120 giây',
    ),
    (
      const ApiError(429, 'rate_limited', 'slow', retryAfter: 90),
      'Thử lại sau 90 giây',
    ),
    (
      const ApiError(
        202,
        'device_pending',
        'pending',
        body: {
          'contact': {'name': 'Admin', 'phone': '0901'},
        },
      ),
      'Thiết bị đang chờ quản trị duyệt. Liên hệ: Admin — 0901',
    ),
    (
      const ApiError(403, 'device_revoked', 'revoked'),
      'Thiết bị đã bị thu hồi — liên hệ quản trị',
    ),
    (
      const ApiError(
        403,
        'email_domain_not_allowed',
        'domain',
        body: {
          'allowed_domains': ['congty.vn'],
        },
      ),
      'Email phải thuộc: congty.vn',
    ),
    (
      const ApiError(403, 'account_pending', 'pending'),
      'Tài khoản đang chờ duyệt',
    ),
    (
      const ApiError(403, 'account_rejected', 'rejected'),
      'Tài khoản đã bị từ chối',
    ),
    (const ApiError(403, 'account_locked', 'locked'), 'Tài khoản đã bị khoá'),
    (
      const ApiError(403, 'email_unverified', 'unverified'),
      'Email chưa được xác thực — kiểm tra hộp thư',
    ),
    (
      const ApiError(400, 'device_required', 'device'),
      'Không lấy được mã thiết bị, thử lại sau',
    ),
    (
      const ApiError(500, 'device_signing_unavailable', 'device'),
      'Máy chủ tạm thời chưa cấp được mã thiết bị, thử lại sau',
    ),
    (const ApiError(500, 'server_error', 'Thử lại sau'), 'Thử lại sau'),
  ]) {
    testWidgets('login displays $message without retry', (tester) async {
      final api = TestAuth()..failure = error;
      addTearDown(api.client.close);
      final session = TestSession();
      await tester.pumpWidget(authApp(const LoginScreen(), api, session));
      await tester.enterText(find.byType(TextField).at(0), 'a@b.vn');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tapText(tester, 'Đăng nhập');
      expect(find.text(message), findsOneWidget);
      expect(api.logins.length, 1);
      expect(session.tokens, isEmpty);
    });
  }
  testWidgets(
    'pending verification opens OTP with server email and retained password',
    (tester) async {
      final api = TestAuth()
        ..failure = const ApiError(
          403,
          'pending_verification',
          'verify',
          body: {'email': 'server@b.vn'},
        );
      addTearDown(api.client.close);
      final session = TestSession();
      await tester.pumpWidget(authApp(const LoginScreen(), api, session));
      await tester.enterText(find.byType(TextField).at(0), 'a@b.vn');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tapText(tester, 'Đăng nhập');
      final otp = tester.widget<OtpStep>(find.byType(OtpStep));
      expect(otp.email, 'server@b.vn');
      expect(otp.password, 'password');
      await tapText(tester, 'Quay lại');
      expect(find.byType(TextField), findsNWidgets(2));
    },
  );
}

class ConnectionApi extends PublicApi {
  ConnectionApi(this.failureAt) : super(ApiClient());
  final String? failureAt;
  final calls = <String>[];

  void record(String call) {
    calls.add(call);
    if (failureAt == call) {
      throw const ApiError(503, 'server_error', 'Máy chủ tạm ngừng');
    }
  }

  @override
  Future<Object?> health() async {
    record('health');
    return {'status': 'ok'};
  }

  @override
  Future<List<Province>> fetchProvinces() async {
    record('provinces');
    return [
      Province(name: 'Hà Nội', oldNames: []),
      Province(name: 'Hồ Chí Minh', oldNames: []),
    ];
  }
}
