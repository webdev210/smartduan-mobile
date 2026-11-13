import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/api/errors.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/auth/login.dart';
import 'package:smartduan/screens/auth/register.dart';
import 'package:smartduan/screens/auth/forgot_password.dart';
import 'package:smartduan/screens/public/home.dart';
import 'package:smartduan/screens/public/explore.dart';
import 'package:smartduan/screens/public/developer.dart';
import 'package:smartduan/screens/public/post.dart';
import 'package:smartduan/screens/public/privacy_policy.dart';
import 'package:smartduan/screens/public/project_compare.dart';
import 'package:smartduan/screens/public/loan.dart';
import 'package:smartduan/screens/public/tour_360.dart';
import 'package:smartduan/screens/public/viewer.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:smartduan/ui/loan_result_cards.dart';
import 'package:smartduan/ui/tour360.dart';
import 'package:smartduan/ui/tour_frame.dart';
// Platform interface comes with webview_flutter.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../api/fake_http.dart';
import '../../api/public_test.dart' show projectJson;
import '../../support/responsive.dart';
import '../../ui/detail_webview_fake.dart';
import '../auth/auth_fakes.dart';
import 'home_test.dart' show homeReply;

const longName =
    'Khu đô thị ven sông Thành phố Hồ Chí Minh dành cho gia đình nhiều thế hệ';
const tourUrl = 'https://360.smartrealtors.vn/share/collection/7H1b3';

Reply reply(String path, String state) {
  if (state == 'error') return const Reply(503, {'error': 'unavailable'});
  if (path == '/public/projects') {
    return Reply(200, {
      'data': state == 'empty'
          ? <Object?>[]
          : [
              for (var i = 0; i < 6; i++)
                {
                  ...projectJson('P$i'),
                  'name': '$longName $i',
                  'province': 'Hà Nội',
                  'price_from': '1234567890123',
                },
            ],
      'page': 1,
      'per_page': 50,
      'total': state == 'empty' ? 0 : 6,
    });
  }
  if (path == '/public/loans/calculate') {
    return Reply(200, {
      'price': 1234567890123,
      'loan_amount': 864197523086,
      'monthly_payment': 12345678901,
      'totals': {
        'principal': 864197523086,
        'interest': 123456789012,
        'total': 987654312098,
      },
      'schedule': [
        for (var i = 1; i <= 12; i++)
          {
            'period': i,
            'principal': 1234567890,
            'interest': 1234567890,
            'total': 2469135780,
            'remaining': 864197523086,
          },
      ],
    });
  }
  if (path.startsWith('/public/projects/')) {
    return Reply(200, {...projectJson(path.split('/').last), 'name': longName});
  }
  if (path == '/public/developers/dev') {
    return Reply(200, {
      'id': 'dev',
      'slug': 'dev',
      'name': longName,
      'website': 'https://example.vn',
      'description': List.filled(12, longName).join(' '),
      'badges': ['Chủ đầu tư dự án nhà ở đô thị'],
    });
  }
  if (path == '/public/posts/post') {
    return Reply(200, {
      'id': 'post',
      'slug': 'post',
      'title': longName,
      'kind': 'event',
      'location': longName,
      'body': '<p>${List.filled(15, longName).join(' ')}</p>',
    });
  }
  if (path.startsWith('/privacy/')) {
    return Reply(200, {
      'version': 'v3',
      'title': 'Chính sách bảo mật',
      'body': '<p>$longName</p>',
      'url': null,
    });
  }
  return homeReply(path);
}

Future<void> scrollEnd(WidgetTester tester) async {
  for (final element in find.byType(Scrollable).evaluate().toList()) {
    final state = (element as StatefulElement).state as ScrollableState;
    if (state.position.axis == Axis.vertical &&
        state.position.hasContentDimensions) {
      state.position.jumpTo(state.position.maxScrollExtent);
    }
  }
  await tester.pump();
}

void main() {
  setUp(() {
    WebViewPlatform.instance = DetailWebViewPlatform();
    testerBinding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (_) async => 'success',
    );
  });
  final screens = <String, Widget>{
    'home': const PublicHome(),
    'home menu': const PublicHome(),
    'explore': const PublicExplore(params: {'q': ''}),
    'developer': const DeveloperScreen(slug: 'dev'),
    'post': const PostScreen(slug: 'post'),
    'policy': const PrivacyPolicyScreen(),
    'comparison': const ProjectCompareScreen(),
    'loan': const LoanScreen(),
    'login': const LoginScreen(notice: longName),
    'login pending': const LoginScreen(),
    'login keyboard': const LoginScreen(),
    'register': const RegisterScreen(),
    'register keyboard': const RegisterScreen(),
    'forgot password': const ForgotPasswordScreen(),
    'forgot password keyboard': const ForgotPasswordScreen(),
    'loan keyboard': const LoanScreen(),
    'tour screen': const Tour360Screen(url: tourUrl, name: longName),
    'tour invalid': const Tour360Screen(url: 'bad', name: longName),
    'inline tour': const Scaffold(
      body: SingleChildScrollView(
        child: Tour360(url: tourUrl, name: longName, cover: null),
      ),
    ),
    'inline playing': const Scaffold(
      body: SingleChildScrollView(
        child: Tour360(url: tourUrl, name: longName, cover: null),
      ),
    ),
    'tour frame': const Scaffold(
      body: TourFrame(url: tourUrl, title: longName),
    ),
    'viewer': const ViewerScreen(
      url: 'https://example.vn/page',
      title: longName,
    ),
    'viewer invalid': const ViewerScreen(url: 'bad', title: longName),
    'document': const ViewerScreen(
      url: 'https://example.vn/a.pdf',
      title: longName,
    ),
  };
  for (final MapEntry(key: name, value: screen) in screens.entries) {
    final states =
        [
          'home',
          'explore',
          'developer',
          'post',
          'policy',
          'comparison',
          'document',
          'loan',
          'tour frame',
          'viewer',
          'tour screen',
        ].contains(name)
        ? ['data', 'empty', 'error', 'loading']
        : ['data'];
    for (final state in states) {
      testWidgets('$name $state responsive matrix', (tester) async {
        await expectResponsive(tester, () async {
          tester.view.viewInsets = const FakeViewPadding();
          final pending = Completer<Reply>();
          final client = ApiClient(
            adapter: FakeHttp(
              (c) => state == 'loading' ? pending.future : reply(c.path, state),
            ),
          );
          final auth = TestAuth();
          if (name == 'login pending') {
            auth.failure = const ApiError(
              202,
              'device_pending',
              '',
              body: {
                'contact': {'name': longName, 'phone': '0901234567'},
              },
            );
          }
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              publicApiProvider.overrideWithValue(PublicApi(client)),
              authApiProvider.overrideWithValue(auth),
              sessionProvider.overrideWith(TestSession.new),
              viewerFileProvider('https://example.vn/a.pdf')
                  .overrideWith((_) async {
                    if (state == 'loading') return Completer<String>().future;
                    if (state == 'error') throw StateError('offline');
                    return '/tmp/document.pdf';
                  }),
            ],
          );
          if (name == 'comparison' && state != 'empty') {
            container.read(projectCompareProvider.notifier)
              ..add('A')
              ..add('B')
              ..add('C');
          }
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  appBar:
                      [
                        'login',
                        'register',
                        'forgot password',
                      ].any(name.startsWith)
                      ? AppBar(title: Text(name))
                      : null,
                  body: SafeArea(child: screen),
                ),
              ),
            ),
          );
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          if (name == 'home menu') {
            await tester.tap(find.text('Menu'));
            await tester.pump(const Duration(milliseconds: 300));
          }
          if (name == 'inline playing') {
            await tester.tap(find.bySemanticsLabel('Xem tour 360° $longName'));
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          }
          if (name == 'login pending') {
            await tester.enterText(
              find.byType(TextField).first,
              'sale@example.vn',
            );
            await tester.enterText(find.byType(TextField).last, 'password');
            await tester.pump();
            await tester.ensureVisible(find.text('Đăng nhập'));
            await tester.pump();
            await tester.tap(find.text('Đăng nhập'));
            await tester.pump();
            expect(find.text('Gọi người duyệt'), findsOneWidget);
          }
          if (name.endsWith('keyboard')) {
            final field = find.byType(TextField).last;
            await tester.ensureVisible(field);
            await tester.pump();
            await tester.tap(field);
            final height = tester.view.physicalSize.height;
            final keyboard = height < 500 ? 160.0 : 280.0;
            tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.ensureVisible(field);
            await tester.pump();
            expect(
              tester.getBottomRight(field).dy,
              lessThanOrEqualTo(height - keyboard),
            );
          }
          if (name == 'loan' && state != 'empty') {
            await tester.enterText(
              find.byType(TextField).first,
              '1234567890123',
            );
            await tester.pump();
            await tester.ensureVisible(find.text('Tính'));
            await tester.pump();
            await tester.tap(find.text('Tính'));
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          }
          if (['tour frame', 'viewer', 'tour screen'].contains(name)) {
            final web = WebViewPlatform.instance as DetailWebViewPlatform;
            for (final controller in web.controllers) {
              if (state == 'error') {
                controller.navigation?.error?.call(
                  WebResourceError(
                    errorCode: -1,
                    description: 'offline',
                    isForMainFrame: true,
                  ),
                );
              } else if (state != 'loading') {
                controller.navigation?.finished?.call('https://example.vn');
              }
            }
            await tester.pump();
          }
          if (state == 'data' &&
              ['developer', 'post', 'comparison'].contains(name)) {
            expect(find.text(longName), findsWidgets);
          }
          if (name == 'loan' && state == 'data') {
            expect(find.byType(LoanResultCards), findsOneWidget);
          }
          await scrollEnd(tester);
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          client.close();
          auth.client.close();
        });
      });
    }
  }
}

final testerBinding = TestWidgetsFlutterBinding.ensureInitialized();
