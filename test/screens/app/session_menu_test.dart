import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/client.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/auth/token_store.dart';
import 'package:smartduan/main.dart';
import 'package:smartduan/router.dart';
import 'package:smartduan/ui/kit.dart' show Button, Tile;

import '../../api/fake_http.dart';
import '../../auth/token_store_test.dart' show MemoryStorage;

void main() {
  for (final f2 in [false, true]) {
    testWidgets(
      '${f2 ? 'F2' : 'become-sales'} refreshes /me and role-gated menu',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var updated = false;
        final http = FakeHttp(
          (r) => switch (r.path) {
            '/me' => Reply(200, {
              'id': 'me',
              'email': 'sale@example.com',
              'roles': updated
                  ? [f2 ? 'sales_partner' : 'sales_free']
                  : f2
                  ? ['sales_free']
                  : <String>[],
              'full_name': 'Nguyễn An',
              'address': 'Hà Nội',
              'phone_verified_at': '2026-11-13T00:00:00Z',
              'referred_manager_id': 'm',
            }),
            '/sales/become-sales' || '/sales/request-f2' => (() {
              updated = true;
              return const Reply(200);
            })(),
            '/sales/managers' => const Reply(200, {
              'data': [
                {'id': 'm', 'full_name': 'Quản lý An'},
              ],
            }),
            _ => const Reply(200, {'data': <Object?>[], 'unread': 0}),
          },
        );
        final tokens = SecureValue('menu-session', storage: MemoryStorage());
        await tokens.set('opaque');
        final client = ApiClient(tokens: tokens, adapter: http);
        addTearDown(client.close);
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [apiClientProvider.overrideWithValue(client)],
        );
        final router = container.read(routerProvider);
        router.go('/menu');
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(Tile, 'Dự án của tôi'),
          f2 ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(f2 ? 'Xin xác nhận F2' : 'Đăng ký làm sale'),
          findsWidgets,
        );
        router.go('/len-sale');
        await tester.pumpAndSettle();
        final submit = find.widgetWithText(
          Button,
          f2 ? 'Gửi yêu cầu F2' : 'Đăng ký làm sale',
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(http.seen.where((r) => r.method == 'POST'), hasLength(1));
        expect(http.seen.where((r) => r.path == '/me'), hasLength(2));
        expect(container.read(sessionProvider).roles, [
          f2 ? 'sales_partner' : 'sales_free',
        ]);
        router.go('/menu');
        await tester.pumpAndSettle();
        expect(find.widgetWithText(Tile, 'Dự án của tôi'), findsOneWidget);
        expect(find.text('Đăng ký làm sale'), findsNothing);
        expect(find.text('Xin xác nhận F2'), f2 ? findsNothing : findsWidgets);
      },
    );
  }
}
