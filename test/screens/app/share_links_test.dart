import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/screens/app/share_links.dart';

import 'task_h_fakes.dart';

const live = {
  'id': 'l',
  'url_path': '/s/ticket',
  'view_count': 3,
  'lead_count': 2,
  'created_by_name': 'Người tạo mẫu',
  'inserted_at': '2026-01-01T10:00:00Z',
};

void main() {
  test('dead links match RN revoked/expired/invalid-date cases', () {
    final now = DateTime.utc(2026, 11, 12);
    expect(shareLinkIsDead(const ShareLink(id: 'a'), now), isFalse);
    expect(
      shareLinkIsDead(const ShareLink(id: 'a', revokedAt: 'yes'), now),
      isTrue,
    );
    expect(
      shareLinkIsDead(const ShareLink(id: 'a', expiresAt: '2026-11-11'), now),
      isTrue,
    );
    expect(
      shareLinkIsDead(const ShareLink(id: 'a', expiresAt: '2026-11-13'), now),
      isFalse,
    );
    expect(
      shareLinkIsDead(const ShareLink(id: 'a', expiresAt: '2026-11-12'), now),
      isFalse,
    );
    expect(
      shareLinkIsDead(const ShareLink(id: 'a', expiresAt: 'invalid'), now),
      isFalse,
    );
  });

  Future<void> mount(
    WidgetTester tester,
    HEnv env,
    List<String> sent, {
    String? blockId,
  }) async {
    final container = ProviderContainer.test(
      parent: env.container,
      overrides: [
        sendShareLinkProvider.overrideWithValue((message, origin) async {
          sent.add(message);
          expect(origin.width, greaterThan(0));
        }),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ShareLinksScreen(
            projectId: 'p',
            name: 'Dự án mẫu',
            blockId: blockId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty list creates once with optional block, refreshes and shares',
    (tester) async {
      final env = HEnv();
      var created = false;
      final sent = <String>[];
      env.http.respond = (r) {
        if (r.method == 'POST') {
          created = true;
          return const Reply(201, live);
        }
        return Reply(200, {
          'data': created ? [live] : <Object?>[],
        });
      };
      await mount(tester, env, sent, blockId: 'b');
      expect(find.text('Chưa có link chia sẻ nào.'), findsOneWidget);
      await tester.tap(find.text('Tạo link mới và gửi'));
      await tester.pumpAndSettle();
      expect(env.http.seen.where((r) => r.method == 'POST').single.data, {
        'block_id': 'b',
      });
      expect(sent.single, 'Dự án mẫu: https://smartduan.vn/s/ticket');
      expect(find.text('3 · 2'), findsOneWidget);
      expect(find.text('Người tạo mẫu'), findsOneWidget);
      await tester.ensureVisible(find.text('Gửi lại link'));
      await tester.tap(find.text('Gửi lại link'));
      await tester.pumpAndSettle();
      expect(sent.length, 2);
    },
  );

  testWidgets('copy URL, cancel revoke, confirm revoke then refresh', (
    tester,
  ) async {
    final env = HEnv();
    var revoked = false;
    env.http.respond = (r) {
      if (r.method == 'DELETE') {
        revoked = true;
        return const Reply(200);
      }
      return Reply(200, {
        'data': [
          {...live, if (revoked) 'revoked_at': '2026-11-12'},
        ],
      });
    };
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(tester, env, []);
    await tester.ensureVisible(find.text('Sao chép link'));
    await tester.tap(find.text('Sao chép link'));
    await tester.pumpAndSettle();
    expect(clipboard, 'https://smartduan.vn/s/ticket');
    expect(find.byIcon(Ionicons.checkmark), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Ionicons.checkmark), findsNothing);
    await tester.ensureVisible(find.text('Thu hồi'));
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Khách đang giữ link này sẽ không mở được nữa.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(env.http.seen.where((r) => r.method == 'DELETE'), isEmpty);
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Thu hồi'));
    await tester.pumpAndSettle();
    expect(
      env.http.seen.where((r) => r.method == 'DELETE').single.path,
      '/share-links/l',
    );
    expect(find.text('Gửi lại link'), findsNothing);
    expect(find.text('Đã thu hồi'), findsWidgets);
  });

  testWidgets(
    '403 free sales and create failure remain visible without write retry',
    (tester) async {
      final env = HEnv(roles: ['sales_free']);
      env.http.respond = (_) =>
          const Reply(403, {'message': 'Bạn không có quyền'});
      await mount(tester, env, []);
      expect(find.text('Bạn không có quyền'), findsOneWidget);
      await tester.tap(find.text('Tạo link mới và gửi'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Bạn không có quyền'), findsNWidgets(2));
      expect(env.http.seen.where((r) => r.method == 'POST').length, 1);
    },
  );

  testWidgets('revoke failure retains live link and is not retried', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => r.method == 'DELETE'
        ? const Reply(503, {'message': 'Chưa thu hồi được'})
        : const Reply(200, {
            'data': [live],
          });
    await mount(tester, env, []);
    await tester.ensureVisible(find.text('Thu hồi'));
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Thu hồi'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Chưa thu hồi được'), findsOneWidget);
    expect(find.text('Gửi lại link'), findsOneWidget);
    expect(find.byIcon(Ionicons.linkOutline), findsNothing);
    expect(env.http.seen.where((r) => r.method == 'DELETE').length, 1);
  });

  testWidgets('live/dead filters and their empty state use source texts', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (_) => const Reply(200, {
      'data': [live],
    });
    await mount(tester, env, []);
    await tester.tap(find.text('Đã hết · 0'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có link nào hết hạn hay bị thu hồi.'),
      findsOneWidget,
    );
    expect(find.byIcon(Ionicons.linkOutline), findsOneWidget);
    expect(find.text('Gửi lại link'), findsNothing);
    await tester.tap(find.text('Còn hiệu lực · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi lại link'), findsOneWidget);
  });
}
