import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/auth/routes.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'auth_fakes.dart';
import 'fakes.dart';

class DiagnosticApi extends PublicApi {
  DiagnosticApi(super.client);
  final calls = <String>[];
  bool failed = false;
  @override
  Future<Object?> health() async {
    calls.add('health');
    if (failed) {
      throw const ApiError(0, 'network', 'Không kết nối được máy chủ');
    }
    return {};
  }

  @override
  Future<List<Province>> fetchProvinces() async {
    calls.add('provinces');
    return [Province(name: 'Hà Nội', oldNames: [])];
  }
}

void main() {
  testWidgets(
    'registered screens navigate with notice, privacy and diagnostics at mobile width',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      WebViewPlatform.instance = FakeWebViewPlatform();
      final api = TestAuth();
      addTearDown(api.client.close);
      final diagnostics = DiagnosticApi(api.client);
      final router = GoRouter(
        initialLocation: '/dang-nhap?notice=Hello',
        routes: [
          for (final entry in authScreens.entries)
            GoRoute(path: entry.key, builder: entry.value),
          GoRoute(
            path: '/chinh-sach-bao-mat',
            builder: (_, _) => const Scaffold(body: Text('Policy destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authApiProvider.overrideWithValue(api),
            sessionProvider.overrideWith(TestSession.new),
            publicApiProvider.overrideWithValue(diagnostics),
            fetchPrivacyPolicyProvider.overrideWith(
              (ref) async => const PrivacyPolicy(
                version: 'v3',
                title: 'Policy',
                url: null,
                effectiveFrom: '2026-11-12',
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      await tapText(tester, 'Kiểm tra');
      expect(diagnostics.calls, ['health', 'provinces']);
      expect(find.textContaining('Kết nối OK · 1 tỉnh/thành'), findsOneWidget);
      diagnostics.failed = true;
      await tapText(tester, 'Kiểm tra');
      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
      expect(diagnostics.calls, ['health', 'provinces', 'health']);
      await tapText(tester, 'Quên mật khẩu?');
      expect(router.state.uri.path, '/quen-mat-khau');
      expect(
        find.text(
          'Nhập email đăng ký, chúng tôi sẽ gửi link đặt lại mật khẩu.',
        ),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();
      await tapText(tester, 'Đăng ký tài khoản');
      expect(router.state.uri.path, '/dang-ky');
      final paragraph = find.textContaining('Tôi đồng ý cho Smart Dự Án');
      await tester.ensureVisible(paragraph);
      await tester.pumpAndSettle();
      final link = tester
          .getSemantics(paragraph)
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
          .singleWhere(
            (node) => node.getSemanticsData().label == 'Chính sách bảo mật',
          );
      expect(link.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      link.owner!.performAction(link.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('Policy destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
