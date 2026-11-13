import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'auth/session.dart';
import 'screens/auth/routes.dart';
import 'screens/public/routes.dart';
import 'screens/public/detail_routes.dart';
import 'screens/app/tabs_shell.dart';
import 'screens/app/tab_routes.dart';
import 'screens/app/project_routes.dart';
import 'screens/app/board_routes.dart';
import 'screens/app/share_routes.dart';
import 'screens/app/account_routes.dart';
import 'screens/app/admin_routes.dart';
import 'ui/kit.dart' show Body, Button, Empty;
import 'ui/brand_splash.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Listen without recreating the router: boot/retry must retain deep links.
  final router = GoRouter(
    observers: [_NavigationFocusObserver()],
    redirect: (context, state) {
      final status = ref.read(sessionProvider).status;
      if (status == SessionStatus.loading || status == SessionStatus.offline) {
        return null;
      }
      if (_blocked(status, state.uri.path)) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        observers: [_NavigationFocusObserver()],
        builder: (_, _, child) => _SessionGate(child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => Consumer(
              builder: (_, ref, _) =>
                  ref.watch(sessionProvider).status == SessionStatus.signedIn
                  ? TabsShell(child: shell)
                  : shell,
            ),
            branches: [
              for (final path in appTabPaths)
                StatefulShellBranch(
                  observers: [_NavigationFocusObserver()],
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (context, state) => Consumer(
                        builder: (context, ref, _) {
                          if (path == '/' &&
                              ref.watch(sessionProvider).status !=
                                  SessionStatus.signedIn) {
                            return publicHomeScreens['/']!(context, state);
                          }
                          return appTabScreens[path]!(context, state);
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
          for (final key in {
            ..._authRoutes,
            ..._publicRoutes,
            ..._appRoutes,
          }.keys.where((key) => !appTabPaths.contains(key)))
            GoRoute(
              path: key,
              pageBuilder: (context, state) => MaterialPage<void>(
                key: state.pageKey,
                fullscreenDialog: key == '/ro-hang' || key == '/tour-360',
                child: {
                  ...authScreens,
                  ...publicHomeScreens,
                  ...publicDetailScreens,
                  ...appProjectScreens,
                  ...appBoardScreens,
                  ...appShareScreens,
                  ...appAccountScreens,
                  ...appAdminScreens,
                }[key]!(context, state),
              ),
            ),
        ],
      ),
    ],
    errorBuilder: (_, _) => const _SessionGate(
      child: Scaffold(body: Empty(text: 'Không tìm thấy trang.')),
    ),
  );
  // Branch changes can reuse an existing Navigator without pushing a route.
  router.routerDelegate.addListener(_dismissNavigationFocus);
  ref.listen(sessionProvider, (previous, next) {
    if (previous?.status == next.status) return;
    if (next.status == SessionStatus.guest ||
        next.status == SessionStatus.signedIn) {
      // The top page can be an imperative push whose URL differs from the
      // route-information URL. Replace history, as Stack.Protected does.
      final uri = router.state.uri;
      router.go(_blocked(next.status, uri.path) ? '/' : uri.toString());
    }
  });
  ref.onDispose(router.dispose);
  return router;
});

void _dismissNavigationFocus() => FocusManager.instance.primaryFocus?.unfocus();

class _NavigationFocusObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismissNavigationFocus();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dismissNavigationFocus();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _dismissNavigationFocus();
}

bool _blocked(SessionStatus status, String path) =>
    (status == SessionStatus.signedIn && _authRoutes.containsKey(path)) ||
    (status == SessionStatus.guest &&
        _appRoutes.keys.any((pattern) => _matches(pattern, path)));

bool _matches(String pattern, String path) {
  final expected = pattern.split('/');
  final actual = path.split('/');
  if (expected.length != actual.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (expected[i].startsWith(':')) {
      if (actual[i].isEmpty) return false;
    } else if (expected[i] != actual[i]) {
      return false;
    }
  }
  return true;
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intro = ref.watch(
      introDelayProvider(
        Duration(
          milliseconds: Platform.environment.containsKey('FLUTTER_TEST')
              ? 0
              : 1400,
        ),
      ),
    );
    final status = ref.watch(sessionProvider).status;
    if (status == SessionStatus.loading || intro) return const BrandSplash();
    return switch (status) {
      SessionStatus.loading => const BrandSplash(),
      SessionStatus.offline => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                const Body(
                  'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
                ),
                Button(
                  title: 'Thử lại',
                  onPress: () => ref.read(sessionProvider.notifier).retry(),
                ),
              ],
            ),
          ),
        ),
      ),
      SessionStatus.guest || SessionStatus.signedIn => child,
    };
  }
}

const _authRoutes = {
  '/dang-nhap': 'Đăng nhập',
  '/dang-ky': 'Đăng ký',
  '/quen-mat-khau': 'Quên mật khẩu',
};
const _publicRoutes = {
  '/so-sanh-du-an': 'So sánh dự án',
  '/kham-pha': 'Tất cả dự án',
  '/cong-khai/:code': 'Dự án',
  '/bai-viet/:slug': 'Bài viết',
  '/chu-dau-tu/:slug': 'Chủ đầu tư',
  '/tinh-lai-vay': 'Tính lãi vay',
  '/xem': 'Xem',
  '/chinh-sach-bao-mat': 'Chính sách bảo mật',
  '/tour-360': 'Tour 360°',
};
const _appRoutes = {
  '/du-an': 'Dự án',
  '/tim-can': 'Tìm căn',
  '/thong-bao': 'Thông báo',
  '/menu': 'Menu',
  '/du-an/:id': 'Dự án',
  '/bang-hang/:projectId': 'Bảng hàng',
  '/can/:id': 'Chi tiết căn',
  '/lai-vay': 'Tính lãi vay',
  '/so-sanh': 'So sánh căn',
  '/bang-tin': 'Bảng tin',
  '/bang-tin/:id': 'Bảng tin',
  '/doi-cua-toi': 'Đội của tôi',
  '/quan-tam': 'Dự án quan tâm',
  '/da-luu': 'Dự án yêu thích',
  '/len-sale': 'Đăng ký làm sale',
  '/quy-trinh': 'Quy trình & đào tạo',
  '/quy-trinh/:slug': 'Quy trình',
  '/tu-van': 'Yêu cầu tư vấn',
  '/top-can/:projectId': 'Top căn',
  '/chia-se/:projectId': 'Chia sẻ cho khách',
  '/trinh-chieu/:projectId': 'Trình chiếu',
  '/bien-dong/:projectId': 'Biến động',
  '/bao-cao': 'Báo cáo',
  '/duyet-thiet-bi': 'Duyệt thiết bị',
  '/duyet-tai-khoan': 'Duyệt tài khoản',
  '/ro-hang': 'Rổ hàng',
  '/ho-so': 'Hồ sơ',
};
