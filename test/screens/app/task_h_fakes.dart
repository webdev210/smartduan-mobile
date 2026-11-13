import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';

import '../../api/fake_http.dart';
import '../../auth/token_store_test.dart' show MemoryStorage;
export '../../api/fake_http.dart';

class HSession extends Session {
  HSession(this.roles);
  final List<String> roles;
  @override
  SessionState build() =>
      SessionState(SessionStatus.signedIn, me: {'roles': roles});
  void endSession() => state = const SessionState(SessionStatus.guest);
}

const hProject = {
  'id': 'p',
  'code': 'P',
  'name': 'Dự án mẫu',
  'description': 'Tổng quan mẫu',
  'price_from': '400000000',
};
const hUnit = {
  'id': 'u',
  'code': 'A101',
  'public_code': 'P-A101',
  'project_id': 'p',
  'status': 'available',
  'price_min': '400000000',
  'area_net': '50.5',
};
Reply hReply(String path) {
  if (path == '/projects/p') return const Reply(200, hProject);
  if (path == '/projects') {
    return const Reply(200, {
      'data': [hProject],
      'total': 1,
    });
  }
  if (path == '/units/u/detail') return const Reply(200, hUnit);
  if (path == '/sales/me/compare') {
    return const Reply(200, {'units': <Object?>[], 'removed': <Object?>[]});
  }
  return const Reply(200, {'data': <Object?>[], 'total': 0});
}

class HEnv {
  HEnv({List<String> roles = const ['agent']}) {
    session = HSession(roles);
    http = FakeHttp((r) => hReply(r.path));
    client = ApiClient(
      adapter: http,
      tokens: SecureValue('h', storage: MemoryStorage()),
    );
    container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(() => session),
        apiClientProvider.overrideWithValue(client),
      ],
      retry: (_, _) => null,
    );
    addTearDown(client.close);
  }
  late final HSession session;
  late final FakeHttp http;
  late final ApiClient client;
  late final ProviderContainer container;
  Future<GoRouter> mount(
    WidgetTester tester,
    Widget child, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        for (final path in [
          '/xem',
          '/can/:id',
          '/bang-hang/:projectId',
          '/top-can/:projectId',
          '/lai-vay',
          '/so-sanh',
          '/chia-se/:projectId',
          '/trinh-chieu/:projectId',
          '/tu-van',
          '/ro-hang',
        ])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return router;
  }
}
