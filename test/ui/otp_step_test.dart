import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/ui/otp_step.dart';
import 'package:smartduan/ui/kit.dart' show Button;
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../screens/auth/auth_fakes.dart';
import '../screens/auth/fakes.dart';

void main() {
  testWidgets('resend remains busy until the request completes', (
    tester,
  ) async {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    final api = _PendingResend();
    addTearDown(api.client.close);
    await tester.pumpWidget(
      authApp(
        OtpStep(
          email: 'a@b.vn',
          password: '1234567890',
          notice: 'Sent',
          onBack: () {},
        ),
        api,
        TestSession(),
      ),
    );
    await tapText(tester, 'Gửi lại mã');
    platform.latest.message('{"type":"turnstile","token":"fresh"}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final resend = find.widgetWithText(Button, 'Gửi lại mã');
    expect(tester.widget<Button>(resend).loading, isTrue);
    await tester.tap(resend);
    await tester.pump();
    expect(api.calls, 1);
    api.pending.complete({});
    await tester.pumpAndSettle();
    expect(tester.widget<Button>(resend).loading, isFalse);
  });
  testWidgets(
    'OTP validates six digits, maps device error, resends with fresh captcha',
    (tester) async {
      final platform = FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
      final api = TestAuth();
      addTearDown(api.client.close);
      final session = TestSession();
      var backs = 0;
      await tester.pumpWidget(
        authApp(
          OtpStep(
            email: 'a@b.vn',
            password: '1234567890',
            notice: 'Mã đã gửi',
            onBack: () => backs++,
          ),
          api,
          session,
        ),
      );
      await tester.enterText(find.byType(TextField), '12');
      await tapText(tester, 'Xác thực và đăng nhập');
      expect(api.verifications, isEmpty);
      api.failure = const ApiError(403, 'device_revoked', 'revoked');
      await tester.enterText(find.byType(TextField), '12a3456');
      await tapText(tester, 'Xác thực và đăng nhập');
      expect(
        find.text('Thiết bị đã bị thu hồi — liên hệ quản trị'),
        findsOneWidget,
      );
      expect(session.tokens, isEmpty);
      api.failure = null;
      await tapText(tester, 'Gửi lại mã');
      platform.latest.message('{"type":"turnstile","token":"fresh"}');
      await tester.pumpAndSettle();
      expect(api.resends, [
        ['a@b.vn', 'fresh'],
      ]);
      expect(
        find.text(
          'Đã gửi mã mới tới a@b.vn. Kiểm tra cả hộp thư Spam/Quảng cáo.',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Gửi lại mã');
      expect(platform.controllers.length, 2);
      await tapText(tester, 'Quay lại');
      expect(backs, 1);
    },
  );
}

class _PendingResend extends TestAuth {
  final pending = Completer<Map<String, dynamic>>();
  int calls = 0;
  @override
  Future<Map<String, dynamic>> resendRegistrationOtp(
    String email,
    String token,
  ) {
    calls++;
    return pending.future;
  }
}
