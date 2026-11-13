import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/auth/login.dart';
import 'package:smartduan/screens/auth/register.dart';
import 'package:smartduan/screens/auth/forgot_password.dart';
import 'package:smartduan/screens/public/home.dart';
import 'package:smartduan/screens/public/developer.dart';
import 'package:smartduan/screens/public/project_compare.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/screens/public/viewer.dart';
import 'package:smartduan/screens/public/loan.dart';
import 'package:smartduan/screens/public/privacy_policy.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/bottom_bar.dart' as bars;
import 'package:smartduan/ui/theme.dart' as c;

import '../../api/fake_http.dart';
import '../../api/public_test.dart' show projectJson;
import 'home_test.dart' show mountHome, homeReply, GuestSession;
import '../auth/auth_fakes.dart';
import '../auth/fakes.dart';

// Installed by webview_flutter.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'detail_screens_test.dart' show DetailSession;

void main() {
  setUp(() => WebViewPlatform.instance = FakeWebViewPlatform());
  for (final screen in <Widget>[
    const LoginScreen(),
    const RegisterScreen(),
    const ForgotPasswordScreen(),
  ]) {
    testWidgets('16 ${screen.runtimeType} fields align to the 20dp gutter', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = TestAuth();
      addTearDown(auth.client.close);
      await tester.pumpWidget(authApp(screen, auth, TestSession()));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TextField).first).dx, 20);
      expect(tester.getSize(find.byType(TextField).first).width, 350);
    });
  }

  testWidgets('18 connection diagnostics are clearly labelled', (tester) async {
    final auth = TestAuth();
    addTearDown(auth.client.close);
    await tester.pumpWidget(authApp(const LoginScreen(), auth, TestSession()));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết kết nối'), findsOneWidget);
    expect(find.text('Máy chủ'), findsNothing);
    expect(find.bySemanticsLabel('Kiểm tra kết nối'), findsOneWidget);
  });

  testWidgets('7 guest promotions are flat brand surfaces with gold accents', (
    tester,
  ) async {
    await mountHome(tester, FakeHttp((call) => homeReply(call.path)));
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    final promos = tester
        .widgetList<kit.Card>(find.byType(kit.Card))
        .where((card) => card.style?.color == c.brandDeep);
    expect(promos, hasLength(2));
    for (final card in promos) {
      expect(card.style?.gradient, isNull);
      expect((card.style?.border as Border?)?.left.color, c.gold);
    }
  });

  testWidgets('29 public home uses the shared bottom bar', (tester) async {
    await mountHome(tester, FakeHttp((call) => homeReply(call.path)));
    expect(find.byType(bars.GuestBar), findsOneWidget);
    expect(
      tester
          .widget<bars.GuestBar>(find.byType(bars.GuestBar))
          .items
          .map((item) => item.label),
      ['Trang chủ', 'Dự án', 'Lãi vay', 'Menu'],
    );
  });

  testWidgets(
    '24 news and events reserve their sections while loading and refresh preserves content',
    (tester) async {
      final pending = Completer<List<PublicPost>>();
      final client = ApiClient(
        adapter: FakeHttp((call) => homeReply(call.path)),
      );
      addTearDown(client.close);
      final container = ProviderContainer.test(
        overrides: [
          sessionProvider.overrideWith(() => GuestSession()),
          publicApiProvider.overrideWithValue(PublicApi(client)),
          listPublicPostsProvider((kind: 'news', perPage: 3))
              .overrideWith((_) => pending.future),
          listPublicPostsProvider((kind: 'event', perPage: 3))
              .overrideWith((_) => pending.future),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PublicHome()),
        ),
      );
      await tester.pump();
      expect(find.text('Tin mới'), findsOneWidget);
      expect(find.text('Sự kiện'), findsOneWidget);
      expect(find.byType(kit.Skeleton), findsWidgets);
      pending.complete([
        const PublicPost(
          id: 'post',
          slug: 'post',
          title: 'Tin dự án',
          kind: 'news',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Tin dự án'), findsNWidgets(2));
      container.refresh(
        listPublicPostsProvider((kind: 'news', perPage: 3)).future,
      );
      await tester.pump();
      expect(find.text('Tin dự án'), findsNWidgets(2));
    },
  );

  testWidgets(
    '5 comparison pins project headings and attribute labels while scrolling',
    (tester) async {
      final container = ProviderContainer.test(
        overrides: [
          for (final code in ['A', 'B', 'C'])
            fetchPublicProjectProvider(code).overrideWith(
              (_) async => PublicProject(
                id: code,
                code: code,
                name: 'Dự án $code',
                status: 'selling',
                overviewJson: {
                  'amenities': List.filled(
                    5,
                    'Tiện ích dài để kiểm tra chiều cao hàng',
                  ),
                },
              ),
            ),
        ],
      );
      container.read(projectCompareProvider.notifier)
        ..add('A')
        ..add('B')
        ..add('C');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProjectCompareScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final heading = tester.getTopLeft(find.text('Dự án A'));
      final label = tester.getTopLeft(find.text('Giá'));
      final body = find
          .ancestor(
            of: find.text('Tiện ích'),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(body, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Dự án A')), heading);
      final horizontal = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where(
            (state) =>
                state.position.axis == Axis.horizontal &&
                state.position.maxScrollExtent > 0,
          )
          .last;
      horizontal.position.jumpTo(100);
      await tester.pump();
      expect(tester.getTopLeft(find.text('Giá')).dx, label.dx);
      expect(tester.getTopLeft(find.text('Dự án A')).dx, heading.dx - 100);
    },
  );

  testWidgets('6 comparison project title is a branded 48dp action', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        for (final code in ['A', 'B'])
          fetchPublicProjectProvider(code).overrideWith(
            (_) async => PublicProject(
              id: code,
              code: code,
              name: 'Dự án $code',
              status: 'selling',
            ),
          ),
      ],
    );
    container.read(projectCompareProvider.notifier)
      ..add('A')
      ..add('B');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectCompareScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.ancestor(
      of: find.text('Dự án A'),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    final text = tester.widget<Text>(find.text('Dự án A'));
    expect(text.style?.color, c.link);
    expect(text.style?.decoration, TextDecoration.underline);
  });

  testWidgets('10 comparison status is colored text without a pill', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        for (final code in ['A', 'B'])
          fetchPublicProjectProvider(code).overrideWith(
            (_) async => PublicProject(
              id: code,
              code: code,
              name: code,
              status: 'selling',
            ),
          ),
      ],
    );
    container.read(projectCompareProvider.notifier)
      ..add('A')
      ..add('B');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProjectCompareScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(kit.Pill), findsNothing);
    expect(
      tester
          .widget<Text>(find.text(projectStatus['selling']!.label).first)
          .style
          ?.color,
      Color(
        int.parse(
          projectStatus['selling']!.color.replaceFirst('#', 'ff'),
          radix: 16,
        ),
      ),
    );
  });

  testWidgets('27 developer project collection uses H2', (tester) async {
    final container = ProviderContainer.test(
      overrides: [
        fetchPublicDeveloperProvider('dev').overrideWith(
          (_) async => PublicDeveloper(
            id: 'dev',
            slug: 'dev',
            name: 'Chủ đầu tư',
            badges: [],
          ),
        ),
        listPublicProjectsProvider(
          const PublicFilters(developerId: 'dev', perPage: 50),
        ).overrideWith(
          (_) async => Paged(data: [], page: 1, perPage: 50, total: 0),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DeveloperScreen(slug: 'dev')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(of: find.text('Dự án'), matching: find.byType(kit.H2)),
      findsOneWidget,
    );
  });

  for (final price in <String?>[null, '', '0', '-1']) {
    testWidgets(
      '19 21 31 project uses inventory terms, contact price $price and remaining count',
      (tester) async {
        final container = ProviderContainer.test(
          overrides: [
            sessionProvider.overrideWith(
              () => DetailSession(SessionStatus.guest),
            ),
            fetchPublicProjectProvider('A').overrideWith(
              (_) async => PublicProject(
                id: 'A',
                code: 'A',
                name: 'Dự án A',
                status: 'selling',
                priceFrom: price,
                overviewJson: {
                  'amenities': [for (var i = 0; i < 7; i++) 'Tiện ích $i'],
                },
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ProjectDetailScreen(code: 'A')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Liên hệ'), findsWidgets);
        expect(find.text('Giá từ'), findsNothing);
        expect(find.textContaining('bảng hàng, quỹ hàng'), findsOneWidget);
        expect(find.text('Xem thêm (2)'), findsOneWidget);
        await tester.ensureVisible(find.text('Xem thêm (2)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xem thêm (2)'));
        await tester.pumpAndSettle();
        expect(find.text('Tiện ích 6'), findsOneWidget);
        expect(find.text('Thu gọn'), findsOneWidget);
      },
    );
  }

  testWidgets('32 downloaded document has one explicit open/share action', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (_) async => 'success',
    );
    final container = ProviderContainer.test(
      overrides: [
        viewerFileProvider('https://example.vn/a.pdf')
            .overrideWith((_) async => '/tmp/a.pdf'),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: const ViewerScreen(url: 'https://example.vn/a.pdf', file: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mở hoặc chia sẻ tài liệu'), findsOneWidget);
    expect(find.text('Mở file'), findsNothing);
    expect(find.text('Chia sẻ tài liệu'), findsNothing);
  });
  testWidgets('1 home rail fits content and equalizes displayed cards', (
    tester,
  ) async {
    await mountHome(
      tester,
      FakeHttp(
        (call) => call.path == '/public/projects'
            ? Reply(200, {
                'data': [
                  projectJson('A'),
                  {
                    ...projectJson('B'),
                    'name': 'Dự án có tên dài để xuống dòng',
                  },
                ],
                'page': 1,
                'per_page': 50,
                'total': 2,
              })
            : homeReply(call.path),
      ),
    );
    final cards = find.byType(ProjectCard);
    final a = tester.getRect(cards.at(0));
    final b = tester.getRect(cards.at(1));
    expect(a.bottom, b.bottom);
    expect(a.height, lessThan(a.width * 10 / 16 + 300));
  });

  testWidgets('15 public loan action is pinned and has term shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoanScreen())),
    );
    expect(
      find.descendant(of: find.byType(Scaffold), matching: find.text('Tính')),
      findsOneWidget,
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNotNull);
    for (final years in [10, 15, 20, 25, 30]) {
      expect(find.text('$years năm'), findsOneWidget);
    }
    await tester.tap(find.text('15 năm'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
      '180',
    );
  });

  test('30 policy links use the shared brand link color and underline', () {
    final hex = (c.link.toARGB32() & 0xffffff)
        .toRadixString(16)
        .padLeft(6, '0');
    expect(
      policyHtml('<a href="/">Link</a>'),
      contains('a{color:#$hex;text-decoration:underline}'),
    );
  });
}
