import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/auth/register.dart';
import 'package:smartduan/ui/theme.dart' as theme;
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'auth_fakes.dart';
import 'fakes.dart';

void main() {
  late FakeWebViewPlatform platform;
  late TestAuth api;
  late TestSession session;
  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    api = TestAuth();
    session = TestSession();
  });
  tearDown(() => api.client.close());
  testWidgets(
    'register Next follows field order and Done reveals first invalid input',
    (tester) async {
      await tester.pumpWidget(authApp(const RegisterScreen(), api, session));
      await tester.pumpAndSettle();
      expect(find.byType(AutofillGroup), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.map((f) => f.textInputAction), [
        TextInputAction.next,
        TextInputAction.next,
        TextInputAction.next,
        TextInputAction.done,
      ]);
      await tester.tap(find.byType(TextField).first);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(fields[1].focusNode!.hasFocus, isTrue);
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.pump();
      await tester.tap(find.byType(TextField).last);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fields.first.focusNode!.hasFocus, isTrue);
      expect(find.byType(TextField).first.hitTestable(), findsOneWidget);
      expect(api.registrations, isEmpty);
    },
  );
  testWidgets(
    'consent is one centered paragraph with an accessible inline link',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(authApp(const RegisterScreen(), api, session));
      await tester.pumpAndSettle();
      final paragraph = find.text(
        'Tôi đồng ý cho Smart Dự Án xử lý dữ liệu cá nhân theo Chính sách bảo mật (phiên bản v3)',
        findRichText: true,
      );
      expect(paragraph, findsOneWidget);
      final text = tester.widget<Text>(
        find.text(
          'Tôi đồng ý cho Smart Dự Án xử lý dữ liệu cá nhân theo Chính sách bảo mật (phiên bản v3)',
        ),
      );
      final span = text.textSpan! as TextSpan;
      final link = span.children!.whereType<TextSpan>().singleWhere(
        (s) => s.text == 'Chính sách bảo mật',
      );
      expect(link.style!.color, theme.link);
      expect(link.style!.fontWeight, FontWeight.w600);
      expect(link.recognizer, isNotNull);
      expect(link.semanticsLabel, 'Chính sách bảo mật');
      await tester.ensureVisible(paragraph);
      await tester.pumpAndSettle();
      final accessibleLink = tester
          .getSemantics(paragraph)
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
          .singleWhere(
            (node) => node.getSemanticsData().label == 'Chính sách bảo mật',
          );
      expect(
        accessibleLink.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      final row = tester.widget<Row>(
        find
            .ancestor(of: find.byType(Switch), matching: find.byType(Row))
            .first,
      );
      expect(row.crossAxisAlignment, CrossAxisAlignment.center);
      expect(row.spacing, 12);
      semantics.dispose();
    },
  );
  testWidgets('policy failure blocks registration and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authApiProvider.overrideWithValue(api),
          fetchPrivacyPolicyProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              throw const ApiError(503, 'server_error', 'Unavailable');
            }
            return const PrivacyPolicy(
              version: 'v3',
              title: 'Policy',
              url: null,
              effectiveFrom: '2026-11-12',
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: RegisterScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa tải được phiên bản chính sách bảo mật.'),
      findsOneWidget,
    );
    platform.latest.message('{"type":"turnstile","token":"tok"}');
    await tester.pumpAndSettle();
    await tapText(tester, 'Đăng ký và xác thực');
    expect(api.registrations, isEmpty);
    await tapText(tester, 'Tải lại');
    expect(find.textContaining('phiên bản v3'), findsOneWidget);
    expect(attempts, 2);
  });
  for (final consentError in [true, false]) {
    testWidgets(
      'server ${consentError ? 'consent' : 'field'} error consumes captcha and preserves form',
      (tester) async {
        api.failure = consentError
            ? const ApiError(400, 'consent_required', 'consent')
            : const ApiError(
                422,
                'validation_failed',
                'Không thể đăng ký',
                details: {
                  'email': ['Email đã tồn tại'],
                },
              );
        await tester.pumpWidget(authApp(const RegisterScreen(), api, session));
        await tester.pumpAndSettle();
        for (final (index, value) in [
          (0, 'Nguyễn Minh'),
          (1, 'a@b.vn'),
          (2, '0912345678'),
          (3, '1234567890'),
        ]) {
          await tester.enterText(find.byType(TextField).at(index), value);
        }
        await tester.ensureVisible(find.byType(Switch));
        await tester.pump();
        await tester.tap(find.byType(Switch));
        platform.latest.message('{"type":"turnstile","token":"once"}');
        await tester.pumpAndSettle();
        await tapText(tester, 'Đăng ký và xác thực');
        expect(
          find.text(
            consentError
                ? 'Bạn cần đồng ý với Chính sách bảo mật.'
                : 'Email đã tồn tại',
          ),
          findsOneWidget,
        );
        expect(platform.controllers.length, 2);
        expect(find.text('Nguyễn Minh'), findsOneWidget);
        await tapText(tester, 'Đang chờ xác minh…');
        expect(api.registrations.length, 1);
        await tester.enterText(find.byType(TextField).at(1), 'new@b.vn');
        await tester.pump();
        if (!consentError) expect(find.text('Email đã tồn tại'), findsNothing);
      },
    );
  }
  testWidgets('register → OTP → session entirely inside app', (tester) async {
    await tester.pumpWidget(authApp(const RegisterScreen(), api, session));
    await tester.pumpAndSettle();
    for (final (index, value) in [
      (0, 'Nguyễn Minh'),
      (1, ' A@B.vn '),
      (2, '+84 912 345 678'),
      (3, '1234567890'),
    ]) {
      await tester.enterText(find.byType(TextField).at(index), value);
    }
    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('phiên bản v3'), findsOneWidget);
    platform.latest.message('{"type":"turnstile","token":"tok-1"}');
    await tester.pumpAndSettle();
    await tapText(tester, 'Đăng ký và xác thực');
    expect(api.registrations.single, {
      'full_name': 'Nguyễn Minh',
      'email': 'a@b.vn',
      'phone': '0912345678',
      'password': '1234567890',
      'consent_version': 'v3',
      'turnstile_token': 'tok-1',
    });
    await tester.enterText(find.byType(TextField), '12a3456');
    await tapText(tester, 'Xác thực và đăng nhập');
    expect(api.verifications, [
      ['a@b.vn', '123456', '1234567890'],
    ]);
    expect(session.tokens, ['jwt']);
  });
  testWidgets('missing information marks fields without API call', (
    tester,
  ) async {
    await tester.pumpWidget(authApp(const RegisterScreen(), api, session));
    await tester.pumpAndSettle();
    platform.latest.message('{"type":"turnstile","token":"tok-2"}');
    await tester.pumpAndSettle();
    await tapText(tester, 'Đăng ký và xác thực');
    expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    expect(find.text('Bạn cần đồng ý với Chính sách bảo mật.'), findsOneWidget);
    expect(api.registrations, isEmpty);
  });
}
