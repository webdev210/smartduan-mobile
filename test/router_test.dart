import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/main.dart';
import 'package:smartduan/router.dart';
import 'package:smartduan/screens/app/tabs_shell.dart';
import 'package:smartduan/screens/app/tab_routes.dart';
import 'package:smartduan/screens/app/project_routes.dart';
import 'package:smartduan/screens/app/board_routes.dart';
import 'package:smartduan/screens/app/share_routes.dart';
import 'package:smartduan/screens/app/account_routes.dart';
import 'package:smartduan/screens/app/admin_routes.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/screens/app/projects_tab.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/notifications.dart';
import 'package:smartduan/screens/app/menu_tab.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/app/unit.dart';
import 'package:smartduan/screens/app/compare_units.dart';
import 'package:smartduan/screens/app/loan.dart' as app;
import 'package:smartduan/screens/app/top_units.dart';
import 'package:smartduan/screens/app/board.dart';
import 'package:smartduan/screens/app/project_history.dart';
import 'package:smartduan/screens/app/basket.dart';
import 'package:smartduan/screens/app/presentation.dart';
import 'package:smartduan/screens/app/share_links.dart';
import 'package:smartduan/screens/app/profile.dart';
import 'package:smartduan/screens/app/saved_projects.dart';
import 'package:smartduan/screens/app/interests.dart';
import 'package:smartduan/screens/app/team.dart';
import 'package:smartduan/screens/app/become_sales.dart';
import 'package:smartduan/screens/app/consult.dart';
import 'package:smartduan/screens/app/process_pages.dart';
import 'package:smartduan/screens/app/process_page.dart';
import 'package:smartduan/screens/app/announcements.dart';
import 'package:smartduan/screens/app/announcement.dart';
import 'package:smartduan/screens/app/reports.dart';
import 'package:smartduan/screens/app/approve_accounts.dart';
import 'package:smartduan/screens/app/approve_devices.dart';
import 'package:smartduan/ui/menu.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/ui/bottom_bar.dart';
import 'package:smartduan/api/sales.dart' show fetchNotificationsProvider;
import 'package:smartduan/ui/brand_splash.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/screens/auth/login.dart';
import 'package:smartduan/screens/auth/register.dart';
import 'package:smartduan/screens/auth/forgot_password.dart';
import 'package:smartduan/screens/public/home.dart';
import 'package:smartduan/screens/public/explore.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/screens/public/post.dart';
import 'package:smartduan/screens/public/developer.dart';
import 'package:smartduan/screens/public/loan.dart';
import 'package:smartduan/screens/public/privacy_policy.dart';
import 'package:smartduan/screens/public/viewer.dart';
import 'package:smartduan/screens/public/tour_360.dart';
import 'package:smartduan/screens/public/project_compare.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'api/fake_http.dart';
import 'auth/token_store_test.dart' show MemoryStorage;
import 'screens/auth/fakes.dart';
import 'realtime/fakes.dart' show BoardSocket;

class FakeSession extends Session {
  FakeSession(this.initial, {this.initialRoles = const []});
  final SessionStatus initial;
  final List<String> initialRoles;
  int retries = 0;
  @override
  SessionState build() => SessionState(initial, me: {'roles': initialRoles});
  void setStatus(SessionStatus value) => state = SessionState(value);
  @override
  Future<void> retry() async {
    retries++;
    setStatus(SessionStatus.loading);
  }
}

// Literal paths/titles from the RN layouts, independent of the router table.
const authRoutes = {
  '/dang-nhap': 'Đăng nhập',
  '/dang-ky': 'Đăng ký',
  '/quen-mat-khau': 'Quên mật khẩu',
};
const publicRoutes = {
  '/so-sanh-du-an': 'So sánh dự án',
  '/kham-pha': 'Tất cả dự án',
  '/cong-khai/abc': 'Dự án',
  '/bai-viet/abc': 'Bài viết',
  '/chu-dau-tu/abc': 'Chủ đầu tư',
  '/tinh-lai-vay': 'Tính lãi vay',
  '/xem': 'Xem',
  '/chinh-sach-bao-mat': 'Chính sách bảo mật',
  '/tour-360': 'Tour 360°',
};
const appRoutes = {
  '/du-an': 'Dự án',
  '/tim-can': 'Tìm căn',
  '/thong-bao': 'Thông báo',
  '/menu': 'Menu',
  '/du-an/1': 'Dự án',
  '/bang-hang/1': 'Bảng hàng',
  '/can/1': 'Chi tiết căn',
  '/lai-vay': 'Tính lãi vay',
  '/so-sanh': 'So sánh căn',
  '/bang-tin': 'Bảng tin',
  '/bang-tin/1': 'Bảng tin',
  '/doi-cua-toi': 'Đội của tôi',
  '/quan-tam': 'Dự án quan tâm',
  '/da-luu': 'Dự án yêu thích',
  '/len-sale': 'Đăng ký làm sale',
  '/quy-trinh': 'Quy trình & đào tạo',
  '/quy-trinh/abc': 'Quy trình',
  '/tu-van': 'Yêu cầu tư vấn',
  '/top-can/1': 'Top căn',
  '/chia-se/1': 'Chia sẻ cho khách',
  '/trinh-chieu/1': 'Trình chiếu',
  '/bien-dong/1': 'Biến động',
  '/bao-cao': 'Báo cáo',
  '/duyet-thiet-bi': 'Duyệt thiết bị',
  '/duyet-tai-khoan': 'Duyệt tài khoản',
  '/ro-hang': 'Rổ hàng',
  '/ho-so': 'Hồ sơ',
};

Future<({ProviderContainer container, FakeSession session, GoRouter router})>
mount(
  WidgetTester tester,
  SessionStatus status,
  String path, {
  List<String> roles = const [],
  int unread = 0,
  FakeHttp? http,
}) async {
  final session = FakeSession(status, initialRoles: roles);
  final client = ApiClient(
    tokens: SecureValue('test', storage: MemoryStorage()),
    adapter:
        http ??
        FakeHttp(
          (r) => r.path == '/sales/notifications'
              ? Reply(200, {'data': <Object?>[], 'unread': unread})
              : const Reply(404),
        ),
  );
  addTearDown(client.close);
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      sessionProvider.overrideWith(() => session),
      apiClientProvider.overrideWithValue(client),
      inventorySocketProvider('1').overrideWithValue(BoardSocket()),
    ],
  );
  final router = container.read(routerProvider);
  router.go(path);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pump();
  return (container: container, session: session, router: router);
}

const screenTypes = <String, Type>{
  '/so-sanh-du-an': ProjectCompareScreen,
  '/': PublicHome,
  '/dang-nhap': LoginScreen,
  '/dang-ky': RegisterScreen,
  '/quen-mat-khau': ForgotPasswordScreen,
  '/kham-pha': PublicExplore,
  '/cong-khai/abc': ProjectDetailScreen,
  '/bai-viet/abc': PostScreen,
  '/chu-dau-tu/abc': DeveloperScreen,
  '/tinh-lai-vay': LoanScreen,
  '/xem': ViewerScreen,
  '/chinh-sach-bao-mat': PrivacyPolicyScreen,
  '/tour-360': Tour360Screen,
  '/du-an': ProjectsTab,
  '/tim-can': SearchUnitsScreen,
  '/thong-bao': NotificationsScreen,
  '/menu': MenuTab,
  '/du-an/1': ProjectScreen,
  '/bang-hang/1': BoardScreen,
  '/can/1': UnitScreen,
  '/lai-vay': app.LoanScreen,
  '/so-sanh': CompareUnitsScreen,
  '/top-can/1': TopUnitsScreen,
  '/bien-dong/1': ProjectHistoryScreen,
  '/ro-hang': BasketScreen,
  '/trinh-chieu/1': PresentationScreen,
  '/chia-se/1': ShareLinksScreen,
  '/ho-so': ProfileScreen,
  '/da-luu': SavedProjectsScreen,
  '/quan-tam': InterestsScreen,
  '/doi-cua-toi': TeamScreen,
  '/len-sale': BecomeSalesScreen,
  '/tu-van': ConsultScreen,
  '/quy-trinh': ProcessPagesScreen,
  '/quy-trinh/abc': ProcessPageScreen,
  '/bang-tin': AnnouncementsScreen,
  '/bang-tin/1': AnnouncementScreen,
  '/bao-cao': ReportsScreen,
  '/duyet-tai-khoan': ApproveAccountsScreen,
  '/duyet-thiet-bi': ApproveDevicesScreen,
};

void expectScreen(
  WidgetTester tester,
  String path,
  String title,
  SessionStatus status,
) {
  final screen = path == '/' && status == SessionStatus.signedIn
      ? HomeScreen
      : screenTypes[path];
  expect(screen, isNotNull, reason: path);
  expect(find.byType(screen!), findsOneWidget, reason: path);
  expect(find.byType(Placeholder), findsNothing, reason: path);
}

void main() {
  testWidgets('navigation clears tab input focus on push, pop and tab switch', (
    tester,
  ) async {
    final app = await mount(
      tester,
      SessionStatus.signedIn,
      '/du-an',
      roles: ['agent'],
    );
    await tester.pumpAndSettle();
    final field = find.byType(EditableText).first;
    await tester.showKeyboard(field);
    final node = tester.widget<EditableText>(field).focusNode;
    expect(node.hasFocus, isTrue);
    app.router.push('/kham-pha?q=test');
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    app.router.pop();
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.showKeyboard(field);
    app.router.go('/menu');
    await tester.pumpAndSettle();
    app.router.go('/du-an');
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('real router preserves deliberate explore autofocus', (
    tester,
  ) async {
    final app = await mount(
      tester,
      SessionStatus.signedIn,
      '/du-an',
      roles: ['agent'],
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(EditableText).first);
    app.router.push('/kham-pha');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
    app.router.pop();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isFalse,
    );
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'closing root and nested sheets and dialogs does not restore input focus',
    (tester) async {
      await mount(tester, SessionStatus.signedIn, '/du-an', roles: ['agent']);
      await tester.pumpAndSettle();
      final field = find.byType(EditableText).first;
      final node = tester.widget<EditableText>(field).focusNode;
      for (final root in [true, false]) {
        for (final sheet in [true, false]) {
          await tester.showKeyboard(field);
          final context = tester.element(field);
          final navigator = Navigator.of(context, rootNavigator: root);
          if (sheet) {
            showModalBottomSheet<void>(
              context: context,
              useRootNavigator: root,
              builder: (_) => const TextField(autofocus: true),
            );
          } else {
            showDialog<void>(
              context: context,
              useRootNavigator: root,
              builder: (_) => const Dialog(child: TextField(autofocus: true)),
            );
          }
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).last)
                .focusNode
                .hasFocus,
            isTrue,
          );
          navigator.pop();
          await tester.pumpAndSettle();
          expect(node.hasFocus, isFalse);
          expect(tester.testTextInput.isVisible, isFalse);
        }
      }
    },
  );

  testWidgets(
    'root and shell pushes preserve entry autofocus without restoring old focus',
    (tester) async {
      final app = await mount(
        tester,
        SessionStatus.signedIn,
        '/du-an',
        roles: ['agent'],
      );
      await tester.pumpAndSettle();
      final field = find.byType(EditableText).first;
      final node = tester.widget<EditableText>(field).focusNode;
      for (final root in [true, false]) {
        await tester.showKeyboard(field);
        final context = tester.element(field);
        final navigator = Navigator.of(context, rootNavigator: root);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: TextField(autofocus: true)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).last)
              .focusNode
              .hasFocus,
          isTrue,
        );
        navigator.pop();
        await tester.pumpAndSettle();
        expect(node.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      }
      expect(app.router.state.uri.path, '/du-an');
    },
  );

  for (final path in ['/du-an', '/tim-can', '/thong-bao']) {
    testWidgets('tab app bar paints the status area on $path', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      await mount(tester, SessionStatus.signedIn, path);
      await tester.pumpAndSettle();
      final bar = find.byType(AppBar);
      expect(tester.getTopLeft(bar).dy, 0);
      expect(tester.getSize(bar).height, kToolbarHeight + 24);
      final material = tester
          .widgetList<Material>(
            find.descendant(of: bar, matching: find.byType(Material)),
          )
          .firstWhere((m) => m.color != null);
      expect(material.color, Colors.white);
      expect(tester.takeException(), isNull);
    });
  }
  for (final scale in [1.3, 2.0]) {
    testWidgets('tab shell respects safe area and large text $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final env = await mount(tester, SessionStatus.signedIn, '/menu');
      await tester.pumpAndSettle();
      expect(find.byType(TabsShell), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MenuTab)).dy,
        greaterThanOrEqualTo(24),
      );
      expect(tester.takeException(), isNull);
      final overlays = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        overlays.any((o) => o.value.statusBarIconBrightness == Brightness.dark),
        isTrue,
      );
      env.router.go('/tim-can');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('no registered route renders Placeholder', (tester) async {
    final env = await mount(tester, SessionStatus.guest, '/');
    for (final path in ['/', ...authRoutes.keys, ...publicRoutes.keys]) {
      env.router.go(path);
      await tester.pumpAndSettle();
      expectScreen(tester, path, '', SessionStatus.guest);
      expect(env.router.state.error, isNull, reason: path);
    }
    env.session.setStatus(SessionStatus.signedIn);
    for (final path in ['/', ...appRoutes.keys]) {
      env.router.go(path);
      await tester.pumpAndSettle();
      expectScreen(tester, path, '', SessionStatus.signedIn);
      expect(env.router.state.error, isNull, reason: path);
    }
  });
  testWidgets('all visible menu destinations are registered for every role', (
    tester,
  ) async {
    final env = await mount(tester, SessionStatus.signedIn, '/');
    for (final roles in <List<String>>[
      [],
      ['agent'],
      ['manager'],
      ['admin'],
      ['superadmin'],
      ['sales_free'],
      ['sales_partner'],
    ]) {
      for (final item in menuGroups(roles).expand((g) => g.items)) {
        expect([
          '/tao-tin',
          '/booking',
          '/ket-noi',
        ], isNot(contains(item.href)));
        env.router.go(item.href);
        await tester.pumpAndSettle();
        expect(env.router.state.error, isNull, reason: '$roles: ${item.href}');
        expectScreen(tester, item.href, item.label, SessionStatus.signedIn);
      }
    }
  });
  testWidgets('M4 routes pass RN path and query parameters to real screens', (
    tester,
  ) async {
    final env = await mount(tester, SessionStatus.signedIn, '/');
    for (final path in [
      '/ro-hang?project=p1&url=https%3A%2F%2Fbasket.example%2Fembed%3Fa%3Db',
      '/chia-se/p1?name=An%20Ph%C3%BA&blockId=b1',
      '/trinh-chieu/p1',
      '/quy-trinh/quy-trinh-moi',
      '/bang-tin/a1',
      '/tu-van?projectId=p1&name=An%20Ph%C3%BA',
      '/duyet-thiet-bi?userId=u1&name=Nguy%E1%BB%85n%20An',
    ]) {
      env.router.go(path);
      await tester.pumpAndSettle();
      expect(env.router.state.error, isNull, reason: path);
      switch (Uri.parse(path).path) {
        case '/ro-hang':
          final screen = tester.widget<BasketScreen>(find.byType(BasketScreen));
          expect(screen.projectId, 'p1');
          expect(screen.url, 'https://basket.example/embed?a=b');
        case '/chia-se/p1':
          final screen = tester.widget<ShareLinksScreen>(
            find.byType(ShareLinksScreen),
          );
          expect(screen.projectId, 'p1');
          expect(screen.name, 'An Phú');
          expect(screen.blockId, 'b1');
        case '/trinh-chieu/p1':
          expect(
            tester
                .widget<PresentationScreen>(find.byType(PresentationScreen))
                .projectId,
            'p1',
          );
        case '/quy-trinh/quy-trinh-moi':
          expect(
            tester
                .widget<ProcessPageScreen>(find.byType(ProcessPageScreen))
                .slug,
            'quy-trinh-moi',
          );
        case '/bang-tin/a1':
          expect(
            tester
                .widget<AnnouncementScreen>(find.byType(AnnouncementScreen))
                .id,
            'a1',
          );
        case '/tu-van':
          final screen = tester.widget<ConsultScreen>(
            find.byType(ConsultScreen),
          );
          expect(screen.projectId, 'p1');
          expect(screen.name, 'An Phú');
        case '/duyet-thiet-bi':
          final screen = tester.widget<ApproveDevicesScreen>(
            find.byType(ApproveDevicesScreen),
          );
          expect(screen.userId, 'u1');
          expect(screen.name, 'Nguyễn An');
      }
    }
  });
  testWidgets('M4 registries render real screens through protected routes', (
    tester,
  ) async {
    expect(appShareScreens, hasLength(3));
    expect(appAccountScreens, hasLength(10));
    expect(appAdminScreens, hasLength(3));
    final env = await mount(tester, SessionStatus.signedIn, '/chia-se/1');
    await tester.pumpAndSettle();
    expect(find.byType(ShareLinksScreen), findsOneWidget);
    env.router.go('/ho-so');
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    env.router.go('/bao-cao');
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    env.router.go('/ro-hang');
    await tester.pumpAndSettle();
    expect(
      ModalRoute.of(tester.element(find.byType(BasketScreen)))!
          .fullscreenDialog,
      true,
    );
    env.session.setStatus(SessionStatus.guest);
    await tester.pumpAndSettle();
    for (final path in ['/chia-se/1', '/ho-so', '/bao-cao', '/ro-hang']) {
      env.router.go(path);
      await tester.pumpAndSettle();
      expect(env.router.state.uri.path, '/');
    }
  });
  setUp(() => WebViewPlatform.instance = FakeWebViewPlatform());
  for (final role in [
    '',
    'agent',
    'manager',
    'admin',
    'superadmin',
    'sales_partner',
    'sales_free',
  ]) {
    testWidgets('tabs role gate for $role', (tester) async {
      await mount(
        tester,
        SessionStatus.signedIn,
        '/',
        roles: role.isEmpty ? [] : [role],
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabsShell), findsOneWidget);
      Finder tab(Finder matching) =>
          find.descendant(of: find.byType(GuestBar), matching: matching);
      expect(tab(find.text('Trang chủ')), findsOneWidget);
      expect(
        tab(find.text('Dự án')),
        role.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        tab(find.text('Tìm căn')),
        role.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(tab(find.text('Thông báo')), findsOneWidget);
      expect(
        tab(find.bySemanticsLabel('Menu — bảng điều khiển của bạn')),
        findsOneWidget,
      );
    });
  }
  for (final unread in [0, 8, 100]) {
    testWidgets('unread badge $unread', (tester) async {
      await mount(tester, SessionStatus.signedIn, '/', unread: unread);
      await tester.pumpAndSettle();
      expect(
        find.text(unread > 99 ? '99+' : '$unread'),
        unread == 0 ? findsNothing : findsOneWidget,
      );
    });
  }
  for (final all in [false, true]) {
    testWidgets('tab badge updates after mark-read all=$all', (tester) async {
      var unread = 2;
      final http = FakeHttp((r) {
        if (r.path == '/sales/notifications/read') {
          unread = all ? 0 : 1;
          return const Reply(200);
        }
        if (r.path == '/sales/notifications') {
          return Reply(200, {
            'data': [
              {
                'id': 'n1',
                'title': 'Chính sách mới',
                'read_at': unread < 2 ? '2026-11-12' : null,
              },
              {
                'id': 'n2',
                'title': 'Tài liệu mới',
                'read_at': unread == 0 ? '2026-11-12' : null,
              },
            ],
            'unread': unread,
          });
        }
        return const Reply(404);
      });
      await mount(tester, SessionStatus.signedIn, '/', http: http);
      await tester.pumpAndSettle();
      Finder badge(String value) => find.descendant(
        of: find.byType(GuestBar),
        matching: find.text(value),
      );
      expect(badge('2'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(GuestBar),
          matching: find.text('Thông báo'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(all ? 'Đánh dấu đã đọc tất cả' : 'Chính sách mới'),
      );
      await tester.pumpAndSettle();
      expect(badge('2'), findsNothing);
      expect(badge('1'), all ? findsNothing : findsOneWidget);
      expect(badge('0'), findsNothing);
      expect(
        http.seen.where((r) => r.method == 'POST').single.data,
        all
            ? <String, Object?>{}
            : {
                'ids': ['n1'],
              },
      );
    });
  }
  testWidgets('M3 routes pass RN path and query parameters to real screens', (
    tester,
  ) async {
    final env = await mount(tester, SessionStatus.signedIn, '/');
    await tester.pumpAndSettle();
    for (final path in [
      '/du-an/1',
      '/can/1',
      '/so-sanh',
      '/du-an?q=An%20Ph%C3%BA&at=123',
      '/lai-vay?unitId=u1&code=P-A101',
      '/top-can/1?name=An%20Ph%C3%BA',
      '/bang-hang/1?name=An%20Ph%C3%BA&blockId=b1',
      '/bien-dong/1?name=An%20Ph%C3%BA',
    ]) {
      env.router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(Placeholder), findsNothing, reason: path);
      switch (Uri.parse(path).path) {
        case '/du-an/1':
          expect(
            tester.widget<ProjectScreen>(find.byType(ProjectScreen)).id,
            '1',
          );
        case '/can/1':
          expect(tester.widget<UnitScreen>(find.byType(UnitScreen)).id, '1');
        case '/so-sanh':
          expect(find.byType(CompareUnitsScreen), findsOneWidget);
        case '/du-an':
          final screen = tester.widget<ProjectsTab>(find.byType(ProjectsTab));
          expect(screen.q, 'An Phú');
          expect(screen.at, '123');
        case '/lai-vay':
          final screen = tester.widget<app.LoanScreen>(
            find.byType(app.LoanScreen),
          );
          expect(screen.unitId, 'u1');
          expect(screen.code, 'P-A101');
        case '/top-can/1':
          final screen = tester.widget<TopUnitsScreen>(
            find.byType(TopUnitsScreen),
          );
          expect(screen.projectId, '1');
          expect(screen.name, 'An Phú');
        case '/bang-hang/1':
          final screen = tester.widget<BoardScreen>(find.byType(BoardScreen));
          expect(screen.projectId, '1');
          expect(screen.name, 'An Phú');
          expect(screen.blockId, 'b1');
        case '/bien-dong/1':
          final screen = tester.widget<ProjectHistoryScreen>(
            find.byType(ProjectHistoryScreen),
          );
          expect(screen.projectId, '1');
          expect(screen.name, 'An Phú');
      }
    }
  });
  testWidgets(
    'unread badge polls at 60 seconds and refreshes when invalidated',
    (tester) async {
      final env = await mount(tester, SessionStatus.signedIn, '/', unread: 8);
      await tester.pumpAndSettle();
      final http = FakeHttp(
        (_) => const Reply(200, {'data': <Object?>[], 'unread': 1}),
      );
      final client = ApiClient(
        adapter: http,
        tokens: SecureValue('poll', storage: MemoryStorage()),
      );
      addTearDown(client.close);
      env.container.updateOverrides([
        sessionProvider.overrideWith(() => env.session),
        apiClientProvider.overrideWithValue(client),
        inventorySocketProvider(
          '1',
        ).overrideWithValue(env.container.read(inventorySocketProvider('1'))),
      ]);
      await tester.pumpAndSettle();
      http.seen.clear();
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(
        http.seen.where((r) => r.path == '/sales/notifications'),
        hasLength(1),
      );
      expect(find.text('1'), findsOneWidget);
      http.respond = (_) =>
          const Reply(200, {'data': <Object?>[], 'unread': 0});
      env.container.invalidate(fetchNotificationsProvider);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
    },
  );
  testWidgets(
    'registries dispatch app screens and tabs retain their local state',
    (tester) async {
      final tabs = Map.of(appTabScreens);
      final projects = Map.of(appProjectScreens);
      final boards = Map.of(appBoardScreens);
      appTabScreens['/'] = (_, _) => const Scaffold(body: TextField());
      appTabScreens['/du-an'] = (_, _) =>
          const Scaffold(body: Text('Projects registered'));
      appProjectScreens['/du-an/:id'] = (_, state) =>
          Scaffold(body: Text('Project ${state.pathParameters['id']}'));
      appBoardScreens['/bang-hang/:projectId'] = (_, state) =>
          Scaffold(body: Text('Board ${state.pathParameters['projectId']}'));
      addTearDown(() {
        appTabScreens.clear();
        appTabScreens.addAll(tabs);
        appProjectScreens.clear();
        appProjectScreens.addAll(projects);
        appBoardScreens.clear();
        appBoardScreens.addAll(boards);
      });
      final env = await mount(
        tester,
        SessionStatus.signedIn,
        '/',
        roles: ['agent'],
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'retained');
      await tester.tap(find.text('Dự án'));
      await tester.pumpAndSettle();
      expect(env.router.state.uri.path, '/du-an');
      expect(find.text('Projects registered'), findsOneWidget);
      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();
      expect(find.text('retained'), findsOneWidget);
      env.router.go('/du-an/p1');
      await tester.pumpAndSettle();
      expect(find.text('Project p1'), findsOneWidget);
      expect(find.byType(TabsShell), findsNothing);
      env.router.go('/bang-hang/p2');
      await tester.pumpAndSettle();
      expect(find.text('Board p2'), findsOneWidget);
    },
  );
  testWidgets(
    'registries dispatch guest home auth and parameterized public screens',
    (tester) async {
      final env = await mount(tester, SessionStatus.guest, '/');
      await tester.pumpAndSettle();
      expect(find.byType(PublicHome), findsOneWidget);
      env.router.go('/dang-nhap?notice=Hello');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        tester.widget<LoginScreen>(find.byType(LoginScreen)).notice,
        'Hello',
      );
      env.router.go('/cong-khai/SKY?from=home');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProjectDetailScreen>(find.byType(ProjectDetailScreen))
            .code,
        'SKY',
      );
      env.router.go('/bai-viet/news');
      await tester.pumpAndSettle();
      expect(tester.widget<PostScreen>(find.byType(PostScreen)).slug, 'news');
      env.router.go('/chu-dau-tu/developer');
      await tester.pumpAndSettle();
      expect(
        tester.widget<DeveloperScreen>(find.byType(DeveloperScreen)).slug,
        'developer',
      );
      env.router.go('/kham-pha?q=home');
      await tester.pumpAndSettle();
      expect(
        tester.widget<PublicExplore>(find.byType(PublicExplore)).params['q'],
        'home',
      );
      env.session.setStatus(SessionStatus.signedIn);
      env.router.go('/');
      await tester.pumpAndSettle();
      expectScreen(tester, '/', 'Tổng quan', SessionStatus.signedIn);
    },
  );
  for (final status in SessionStatus.values) {
    testWidgets('$status gates every registered route', (tester) async {
      final env = await mount(tester, status, '/');
      final routes = {
        '/': status == SessionStatus.signedIn ? 'Tổng quan' : 'Trang chủ',
        ...authRoutes,
        ...publicRoutes,
        ...appRoutes,
      };
      for (final MapEntry(:key, :value) in routes.entries) {
        env.router.go(key);
        await tester.pump();
        if (status == SessionStatus.loading) {
          expect(find.byType(BrandSplash), findsOneWidget, reason: key);
          expect(
            find.image(const AssetImage('assets/splash-bg.jpg')),
            findsOneWidget,
          );
          expect(find.byType(Placeholder), findsNothing);
        } else if (status == SessionStatus.offline) {
          expect(
            find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
            findsOneWidget,
            reason: key,
          );
          expect(find.byType(Placeholder), findsNothing);
        } else {
          try {
            await tester.pumpAndSettle();
          } catch (error) {
            fail('$status at $key: $error');
          }
          final blocked = status == SessionStatus.guest
              ? appRoutes.containsKey(key)
              : authRoutes.containsKey(key);
          expect(
            env.router.routeInformationProvider.value.uri.path,
            blocked ? '/' : key,
          );
          expectScreen(
            tester,
            blocked ? '/' : key,
            blocked
                ? (status == SessionStatus.guest ? 'Trang chủ' : 'Tổng quan')
                : value,
            status,
          );
        }
      }
    });
  }
  testWidgets('offline retry calls session retry and shows loading', (
    tester,
  ) async {
    final env = await mount(tester, SessionStatus.offline, '/');
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(env.session.retries, 1);
    expect(find.byType(BrandSplash), findsOneWidget);
  });
  for (final (status, path, label) in [
    (SessionStatus.loading, '/', 'Smart Dự Án'),
    (
      SessionStatus.offline,
      '/',
      'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
    ),
    (SessionStatus.guest, '/missing-page', 'Không tìm thấy trang.'),
  ]) {
    testWidgets('$status router fallback resolves the theme font', (
      tester,
    ) async {
      await mount(tester, status, path);
      final text = find.text(label);
      final rendered = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      final family = Theme.of(tester.element(text))
          .textTheme
          .bodyMedium!
          .fontFamily;
      expect(family, isNotNull);
      expect(rendered.text.style!.fontFamily, family);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('boot preserves public deep link and gates auth when signed in', (
    tester,
  ) async {
    final env = await mount(
      tester,
      SessionStatus.loading,
      '/bai-viet/deep-link',
    );
    env.session.setStatus(SessionStatus.guest);
    await tester.pumpAndSettle();
    expect(
      env.router.routeInformationProvider.value.uri.path,
      '/bai-viet/deep-link',
    );
    env.router.go('/dang-nhap');
    await tester.pumpAndSettle();
    env.session.setStatus(SessionStatus.signedIn);
    await tester.pumpAndSettle();
    expect(env.router.routeInformationProvider.value.uri.path, '/');
    expectScreen(tester, '/', 'Tổng quan', SessionStatus.signedIn);
  });
  testWidgets('sign out drops protected page and history to public home', (
    tester,
  ) async {
    final env = await mount(tester, SessionStatus.signedIn, '/');
    env.router.push('/ho-so');
    await tester.pumpAndSettle();
    env.session.setStatus(SessionStatus.guest);
    await tester.pumpAndSettle();
    expect(env.router.routeInformationProvider.value.uri.path, '/');
    expectScreen(tester, '/', 'Trang chủ', SessionStatus.guest);
    expect(env.router.canPop(), isFalse);
  });
  testWidgets('public page remains when session changes', (tester) async {
    final env = await mount(tester, SessionStatus.guest, '/kham-pha');
    env.session.setStatus(SessionStatus.signedIn);
    await tester.pumpAndSettle();
    expect(env.router.routeInformationProvider.value.uri.path, '/kham-pha');
  });
  testWidgets('route guards cover trailing slashes and query strings', (
    tester,
  ) async {
    final env = await mount(tester, SessionStatus.guest, '/ho-so/?tab=account');
    await tester.pumpAndSettle();
    expectScreen(tester, '/', 'Trang chủ', SessionStatus.guest);
    env.session.setStatus(SessionStatus.signedIn);
    await tester.pumpAndSettle();
    env.router.go('/dang-nhap/?returnTo=ho-so');
    await tester.pumpAndSettle();
    expectScreen(tester, '/', 'Tổng quan', SessionStatus.signedIn);
  });
  for (final path in ['/ro-hang', '/tour-360']) {
    testWidgets('$path uses fullscreen dialog', (tester) async {
      final env = await mount(tester, SessionStatus.signedIn, path);
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byType(path == '/tour-360' ? Tour360Screen : BasketScreen),
      );
      expect(ModalRoute.of(context)!.fullscreenDialog, isTrue);
      expect(env.router.routeInformationProvider.value.uri.path, path);
    });
  }
  for (final path in ['/tao-tin', '/booking', '/ket-noi']) {
    testWidgets('hidden $path is not registered', (tester) async {
      final env = await mount(tester, SessionStatus.signedIn, path);
      await tester.pumpAndSettle();
      expect(find.byType(Placeholder), findsNothing);
      expect(find.text('Không tìm thấy trang.'), findsOneWidget);
      expect(
        env.router.routerDelegate.currentConfiguration.error,
        isA<GoException>(),
      );
    });
  }
}
