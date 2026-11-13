import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/screens/auth/forgot_password.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'auth_fakes.dart';
import 'fakes.dart';

void main() {
  testWidgets(
    'forgot validates, normalizes, hides account existence and refreshes captcha',
    (tester) async {
      final platform = FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
      final api = TestAuth();
      addTearDown(api.client.close);
      await tester.pumpWidget(
        authApp(const ForgotPasswordScreen(), api, TestSession()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bad');
      platform.latest.message('{"type":"turnstile","token":"tok"}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Gửi link đặt lại');
      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(api.resets, isEmpty);
      await tester.enterText(find.byType(TextField), ' A@B.vn ');
      await tapText(tester, 'Gửi link đặt lại');
      expect(api.resets, [
        ['a@b.vn', 'tok'],
      ]);
      expect(find.textContaining('Nếu a@b.vn có tài khoản'), findsOneWidget);
      expect(platform.controllers.length, 2);
      api.failure = const ApiError(
        400,
        'captcha_failed',
        'Xác thực chống bot thất bại, vui lòng thử lại',
      );
      platform.latest.message('{"type":"turnstile","token":"tok2"}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Gửi lại link');
      expect(
        find.text('Xác thực chống bot thất bại, vui lòng thử lại'),
        findsOneWidget,
      );
      expect(platform.controllers.length, 3);
      expect(api.resets.length, 2);
    },
  );
}
