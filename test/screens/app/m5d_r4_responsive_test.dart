import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/realtime/inventory_channel.dart';
import 'package:smartduan/screens/app/notifications.dart';
import 'package:smartduan/screens/app/presentation.dart';
import 'package:smartduan/screens/app/process_page.dart';
import 'package:smartduan/screens/app/process_pages.dart';
import 'package:smartduan/screens/app/profile.dart';
import 'package:smartduan/screens/app/project_history.dart';
import 'package:smartduan/screens/app/reports.dart';
import 'package:smartduan/screens/app/saved_projects.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/share_links.dart';
import 'package:smartduan/screens/app/tabs_shell.dart';
import 'package:smartduan/screens/app/team.dart';
import 'package:smartduan/screens/app/top_units.dart';
import 'package:smartduan/screens/app/unit.dart';

import '../../support/responsive.dart';
import '../../realtime/fakes.dart' show BoardSocket;
import 'task_h_fakes.dart';
import 'presentation_test.dart' show board, plan;

const longName =
    'Nguyễn Thị Hoàng Anh — Khu đô thị ven sông Thành phố Hồ Chí Minh';
final longUnit = {
  ...hUnit,
  'title': longName,
  'bedrooms': 2,
  'direction': 'east',
  'price_min': '3999999999',
  'price_min_label': 'Giá thanh toán theo tiến độ chưa bao gồm phí bảo trì',
  'project': {'id': 'p', 'name': longName, 'code': 'P'},
  'block': {'id': 'b', 'name': longName},
};

Reply r4Reply(String path, {bool empty = false}) {
  final row = {
    'id': 'r',
    'title': longName,
    'slug': 'demo',
    'summary': longName,
  };
  final list = empty ? <Object?>[] : [row];
  if (path == '/inventory/enums') {
    return const Reply(200, {
      'direction': ['east'],
      'direction_labels': {'east': 'Đông'},
    });
  }
  if (path.endsWith('/presentation-board')) {
    return Reply(200, {
      ...board,
      'project': {...hProject, 'name': longName},
    });
  }
  if (path.endsWith('/stack-plan')) return const Reply(200, plan);
  if (path.endsWith('/units/u/detail')) return Reply(200, longUnit);
  if (path == '/process-pages/demo') {
    return Reply(200, {...row, 'status': 'approved'});
  }
  if (path == '/sales/profile') {
    return const Reply(200, {
      'id': 'me',
      'email': 'nguyenthihoanganh@example.com',
      'full_name': longName,
    });
  }
  if (path == '/me/devices') {
    return Reply(200, {
      'data': empty
          ? <Object?>[]
          : [
              {'id': 'd', 'label': longName, 'status': 'approved'},
            ],
    });
  }
  if (path == '/sales/profile/downloads') {
    return Reply(200, {
      'data': empty
          ? <Object?>[]
          : [
              {'id': 'd', 'document_title': longName},
            ],
    });
  }
  if (path == '/sales/team') {
    return Reply(200, {
      'sales_unit': {'id': 's', 'name': longName},
      'data': empty
          ? <Object?>[]
          : [
              {
                'id': 'm',
                'full_name': longName,
                'status': 'active',
                'roles': ['agent'],
              },
            ],
    });
  }
  if (path == '/sales/units/search') {
    return Reply(200, {
      'data': empty ? <Object?>[] : [longUnit],
      'total': empty ? 0 : 60,
      'page': 1,
      'per_page': 30,
    });
  }
  if (path == '/sales/notifications') {
    return Reply(200, {
      'data': empty
          ? <Object?>[]
          : [
              {...row, 'href': '/unsupported'},
            ],
      'unread': empty ? 0 : 1,
    });
  }
  if (path == '/process-pages') return Reply(200, {'data': list});
  if (path == '/me/saved-projects') {
    return Reply(200, {
      'codes': empty ? <Object?>[] : ['P'],
    });
  }
  if (path == '/public/projects/P') {
    return Reply(200, {...hProject, 'name': longName});
  }
  if (path.endsWith('/units/top')) {
    return Reply(200, {
      'groups': empty
          ? <Object?>[]
          : [
              {
                'unit_type': longName,
                'available': 1,
                'units': [
                  {
                    ...longUnit,
                    'why': [longName],
                  },
                ],
              },
            ],
    });
  }
  if (path.endsWith('/share-links')) {
    return Reply(200, {
      'data': empty
          ? <Object?>[]
          : [
              {
                'id': 'link',
                'url_path': '/s/sample',
                'created_by_name': longName,
              },
            ],
    });
  }
  if (path.endsWith('/policies/current-scopes')) {
    return Reply(200, {
      'data': empty
          ? <Object?>[]
          : [
              {
                'id': 'policy',
                'title': longName,
                'summary': longName,
                'file_url': 'https://example.com/policy.pdf',
              },
            ],
    });
  }
  if (path == '/reports/inventory') {
    return Reply(200, {
      'data': empty
          ? <Object?>[]
          : [
              {
                'project': longName,
                'total': 999999,
                'counts': {'available': 999999},
              },
            ],
    });
  }
  if (path.endsWith('/units/history')) {
    return Reply(200, {
      'data': empty
          ? <Object?>[]
          : [
              {
                'id': 'h',
                'unit_id': 'u',
                'field': 'price_min',
                'old_value': '3900000000',
                'new_value': '3999999999',
                'source': 'manual',
              },
            ],
      'total': empty ? 0 : 1,
    });
  }
  return hReply(path);
}

Future<GoRouter> mountR4(
  WidgetTester t,
  HEnv env,
  Widget screen, {
  bool shell = false,
  bool loading = false,
  List<RouteBase> destinations = const [],
}) async {
  final router = GoRouter(
    routes: shell
        ? [
            StatefulShellRoute.indexedStack(
              builder: (_, _, child) => TabsShell(child: child),
              branches: [
                for (var i = 0; i < 5; i++)
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: i == 0 ? '/' : '/tab$i',
                        builder: (_, _) => const Scaffold(body: Text(longName)),
                      ),
                    ],
                  ),
              ],
            ),
          ]
        : [GoRoute(path: '/', builder: (_, _) => screen), ...destinations],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: env.container,
      child: ProviderScope(
        overrides: [
          publicApiProvider.overrideWithValue(PublicApi(env.client)),
          inventorySocketProvider('p').overrideWithValue(BoardSocket()),
          sendShareLinkProvider.overrideWithValue(
            (_, _) async => throw StateError('Share unavailable'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  if (loading) {
    await t.pump(const Duration(milliseconds: 100));
  } else {
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 1));
    await t.pumpAndSettle();
  }
  return router;
}

Finder get verticalR4 => find.byWidgetPredicate(
  (w) =>
      w is Scrollable &&
      (w.axisDirection == AxisDirection.down ||
          w.axisDirection == AxisDirection.up),
);

Future<void> scrollR4(WidgetTester t) async {
  final scrollables = verticalR4;
  if (scrollables.evaluate().isEmpty) return;
  final state = t.state<ScrollableState>(scrollables.first);
  if (state.position.axis != Axis.vertical) return;
  for (
    var i = 0;
    i < 12 && state.position.pixels < state.position.maxScrollExtent;
    i++
  ) {
    state.position.jumpTo(state.position.maxScrollExtent);
    await t.pump();
  }
}

void main() {
  const screens = <String, Widget>{
    'notifications': NotificationsScreen(),
    'presentation': PresentationScreen(projectId: 'p'),
    'process page': ProcessPageScreen(slug: 'demo'),
    'process pages': ProcessPagesScreen(),
    'profile': ProfileScreen(),
    'history': ProjectHistoryScreen(projectId: 'p', name: longName),
    'reports': ReportsScreen(),
    'saved projects': SavedProjectsScreen(),
    'search': SearchUnitsScreen(),
    'share links': ShareLinksScreen(projectId: 'p', name: longName),
    'team': TeamScreen(),
    'top units': TopUnitsScreen(projectId: 'p'),
    'unit': UnitScreen(id: 'u'),
    'tabs': SizedBox(),
  };
  for (final entry in screens.entries) {
    for (final state in ['data', 'empty', 'error', 'loading']) {
      testWidgets('${entry.key} $state responsive matrix', (t) async {
        await expectResponsive(t, () async {
          final env = HEnv(roles: ['manager']);
          final pending = Completer<Reply>();
          env.http.respond = (r) => switch (state) {
            'loading' => pending.future,
            'error' => const Reply(503, {
              'message': 'Chưa tải được dữ liệu. Vui lòng thử lại.',
            }),
            _ => r4Reply(r.path, empty: state == 'empty'),
          };
          final router = await mountR4(
            t,
            env,
            entry.value,
            shell: entry.key == 'tabs',
            loading: state == 'loading',
          );
          await scrollR4(t);
          await t.pumpWidget(const SizedBox());
          router.dispose();
          env.container.dispose();
          await t.pump();
        });
      });
    }
  }
}
