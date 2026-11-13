import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/projects.dart';
import 'package:smartduan/auth/roles.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import 'task_h_fakes.dart';

void main() {
  testWidgets('project FAQ answers toggle from collapsed', (tester) async {
    final env = HEnv();
    env.http.respond = (r) => r.path.endsWith('/faqs')
        ? const Reply(200, {
            'data': [
              {
                'id': 'f',
                'question': 'Khi nào bàn giao?',
                'answer': 'Năm 2027',
              },
            ],
          })
        : hReply(r.path);
    await env.mount(tester, const ProjectScreen(id: 'p'));
    final question = find.text('Khi nào bàn giao?');
    expect(question, findsOneWidget);
    expect(find.text('Năm 2027'), findsNothing);
    await tester.ensureVisible(question);
    final row = find.ancestor(of: question, matching: find.byType(ListTile));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.text('Năm 2027'), findsOneWidget);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.text('Năm 2027'), findsNothing);
  });
  testWidgets(
    'failed project section retries without repeating audited contacts',
    (tester) async {
      final env = HEnv();
      var fail = true;
      env.http.respond = (r) => r.path.endsWith('/documents') && fail
          ? const Reply(503, {'message': 'Documents failed'})
          : hReply(r.path);
      await env.mount(tester, const ProjectScreen(id: 'p'));
      expect(find.text('Documents failed'), findsOneWidget);
      final before = env.http.seen
          .where((r) => r.path.endsWith('/contacts'))
          .length;
      fail = false;
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Documents failed'), findsNothing);
      expect(
        env.http.seen.where((r) => r.path.endsWith('/documents')),
        hasLength(2),
      );
      expect(
        env.http.seen.where((r) => r.path.endsWith('/contacts')),
        hasLength(before),
      );
    },
  );
  testWidgets('project action rows use one card inset', (tester) async {
    await HEnv().mount(tester, const ProjectScreen(id: 'p'));
    expect(
      find.byWidgetPredicate((w) => w is kit.Muted && w.data.isEmpty),
      findsNothing,
    );
    for (final title in [
      'Top căn',
      'Trình chiếu cho khách',
      'Chia sẻ cho khách',
    ]) {
      final label = find.text(title);
      final card = find
          .ancestor(of: label, matching: find.byType(kit.Card))
          .first;
      expect(
        tester.getTopLeft(label).dx - tester.getTopLeft(card).dx,
        closeTo(68, 1),
      );
    }
  });
  for (final role in [
    '',
    'agent',
    'manager',
    'admin',
    'superadmin',
    'sales_partner',
    'sales_free',
  ]) {
    testWidgets('project entry gates for $role', (tester) async {
      final env = HEnv(roles: role.isEmpty ? [] : [role]);
      await env.mount(tester, const ProjectScreen(id: 'p'));
      expect(
        find.text('Mở bảng hàng'),
        role.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Top căn'),
        role.isEmpty ? findsNothing : findsOneWidget,
      );
      final share = !['', 'sales_free'].contains(role);
      expect(find.text('Biến động'), findsNothing);
      expect(
        find.byIcon(Ionicons.gridOutline),
        role.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        find.byIcon(Ionicons.trophyOutline),
        role.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        find.byIcon(Ionicons.tvOutline),
        share ? findsOneWidget : findsNothing,
      );
      expect(
        find.byIcon(Ionicons.shareSocialOutline),
        share ? findsOneWidget : findsNothing,
      );
      expect(find.byIcon(Ionicons.chatbubblesOutline), findsOneWidget);
      expect(
        find.text('Chia sẻ cho khách'),
        share ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Trình chiếu cho khách'),
        share ? findsOneWidget : findsNothing,
      );
      expect(find.text('400 tr'), findsOneWidget);
      expect(env.http.seen.where((r) => r.path == '/activity'), hasLength(1));
    });
    testWidgets('project 404 text for $role', (tester) async {
      final roles = role.isEmpty ? <String>[] : [role];
      final env = HEnv(roles: roles);
      env.http.respond = (_) => const Reply(404);
      await env.mount(tester, const ProjectScreen(id: 'p'));
      expect(find.text(notAssignedText(roles)), findsOneWidget);
      expect(env.http.seen, hasLength(1));
    });
  }
  testWidgets('project 403 has the RN free-sales notice', (tester) async {
    final env = HEnv();
    env.http.respond = (_) => const Reply(403);
    await env.mount(tester, const ProjectScreen(id: 'p'));
    expect(
      find.textContaining('Xin xác nhận F2 để mở bảng hàng.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'policy scopes and upcoming policies; search and contacts cache survive refresh',
    (tester) async {
      final env = HEnv();
      env.http.respond = (r) => switch (r.path) {
        '/content/projects/p/policies/current-scopes' => const Reply(200, {
          'data': [
            {
              'id': 'current',
              'title': 'Chính sách chung',
              'effective_from': '2020-01-01',
            },
            {
              'id': 'fund',
              'fund': 'F2',
              'title': 'Chính sách quỹ',
              'effective_from': '2020-01-01',
            },
          ],
        }),
        '/content/projects/p/policies/history' => const Reply(200, {
          'data': [
            {
              'id': 'soon',
              'fund': 'F2',
              'title': 'Chính sách sắp tới',
              'effective_from': '2099-01-01',
            },
            {
              'id': 'past',
              'title': 'Chính sách cũ',
              'effective_from': '2019-01-01',
            },
          ],
        }),
        '/inventory/enums' => const Reply(200, {
          'fund_labels': {'F2': 'Quỹ đại lý'},
        }),
        '/projects/p/contacts' => const Reply(200, {
          'data': [
            {
              'full_name': 'Nguyễn An',
              'role_label': 'Quản lý',
              'phone': '09★★',
            },
          ],
        }),
        _ => hReply(r.path),
      };
      await env.mount(tester, const ProjectScreen(id: 'p'));
      expect(find.text('Chính sách chung'), findsOneWidget);
      expect(find.textContaining('CSBH chung · Hiệu lực'), findsOneWidget);
      expect(find.textContaining('Quỹ đại lý · Hiệu lực'), findsNWidgets(2));
      expect(find.textContaining('Sắp áp dụng · Quỹ đại lý'), findsOneWidget);
      expect(find.text('Chính sách cũ'), findsNothing);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Nguyen An');
      await tester.pumpAndSettle();
      expect(find.text('Chính sách chung'), findsNothing);
      expect(find.text('Nguyễn An · Quản lý'), findsOneWidget);
      env.container.invalidate(fetchProjectProvider('p'));
      await tester.pumpAndSettle();
      expect(
        env.http.seen.where((r) => r.path.endsWith('/contacts')),
        hasLength(1),
      );
      expect(env.http.seen.where((r) => r.path == '/activity'), hasLength(1));
    },
  );
  testWidgets('document IDs use signed download links and navigation', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => switch (r.path) {
      '/content/projects/p/documents' => const Reply(200, {
        'data': [
          {'id': 'doc', 'title': 'Tài liệu mẫu'},
        ],
      }),
      '/content/documents/doc/download-link' => const Reply(200, {
        'download_url': 'https://smartduan.vn/test.pdf',
      }),
      _ => hReply(r.path),
    };
    final router = await env.mount(tester, const ProjectScreen(id: 'p'));
    await tester.ensureVisible(find.text('Tải'));
    await tester.tap(find.text('Tải'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/xem');
    expect(router.state.uri.queryParameters['file'], '1');
    expect(
      env.http.seen.where(
        (r) => r.method == 'POST' && r.path.endsWith('download-link'),
      ),
      hasLength(1),
    );
  });
  testWidgets(
    'subsidiary denial is hidden; server error warns; empty search recovers',
    (tester) async {
      final env = HEnv();
      env.http.respond = (r) =>
          r.path.endsWith('/documents') ? const Reply(403) : hReply(r.path);
      await env.mount(tester, const ProjectScreen(id: 'p'));
      expect(
        find.text('Một số phần không tải được. Kéo xuống để thử lại.'),
        findsNothing,
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'không có');
      await tester.pumpAndSettle();
      expect(
        find.text('Không thấy “không có” trong dự án này.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Xoá từ khoá'));
      await tester.tap(find.text('Xoá từ khoá'));
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan mẫu'), findsOneWidget);
    },
  );
  testWidgets('project loading and general error can retry', (tester) async {
    final env = HEnv();
    final pending = Completer<Reply>();
    env.http.respond = (_) => pending.future;
    await env.mount(tester, const ProjectScreen(id: 'p'), settle: false);
    await tester.pump();
    expect(find.byType(kit.Loading), findsOneWidget);
    pending.complete(const Reply(500, {'message': 'Có lỗi, vui lòng thử lại'}));
    await tester.pumpAndSettle();
    expect(find.text('Có lỗi, vui lòng thử lại'), findsOneWidget);
    env.http.respond = (r) => hReply(r.path);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng quan mẫu'), findsOneWidget);
  });
  testWidgets(
    'progress, FAQs, training and subdivisions preserve source content and target',
    (tester) async {
      final env = HEnv();
      env.http.respond = (r) => switch (r.path) {
        '/projects/p/subdivisions' => const Reply(200, {
          'data': [
            {
              'block_id': 'b',
              'name': 'Phân khu A',
              'total_units': 2,
              'price_min': '400000000',
              'price_max': '500000000',
            },
          ],
        }),
        '/content/projects/p/progress' => const Reply(200, {
          'data': [
            {
              'id': 'pr',
              'title': 'Khởi công',
              'body': 'Đang xây',
              'occurred_on': '2026-11-12',
            },
          ],
        }),
        '/content/projects/p/faqs' => const Reply(200, {
          'data': [
            {'id': 'f', 'question': 'Khi nào bàn giao?', 'answer': 'Năm 2027'},
          ],
        }),
        '/content/projects/p/media' => const Reply(200, {
          'data': [
            {
              'id': 'training',
              'media_type': 'training',
              'caption': 'Đào tạo bán hàng',
              'url': 'https://smartduan.vn/training.pdf',
            },
          ],
        }),
        _ => hReply(r.path),
      };
      final router = await env.mount(tester, const ProjectScreen(id: 'p'));
      expect(find.text('12/11/2026 — Khởi công\nĐang xây'), findsOneWidget);
      expect(find.text('Khi nào bàn giao?'), findsOneWidget);
      await tester.ensureVisible(find.text('Khi nào bàn giao?'));
      await tester.tap(find.text('Khi nào bàn giao?'));
      await tester.pumpAndSettle();
      expect(find.text('Năm 2027'), findsOneWidget);
      expect(find.text('Đào tạo bán hàng'), findsOneWidget);
      expect(find.text('2 căn · 400 tr – 500 tr'), findsOneWidget);
      await tester.ensureVisible(find.text('Phân khu A'));
      await tester.tap(find.text('Phân khu A'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/bang-hang/p');
      expect(router.state.uri.queryParameters['blockId'], 'b');
    },
  );
  testWidgets('document-link failure is visible and never retried', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => switch (r.path) {
      '/content/projects/p/documents' => const Reply(200, {
        'data': [
          {'id': 'doc', 'title': 'Tài liệu mẫu'},
        ],
      }),
      '/content/documents/doc/download-link' => const Reply(429),
      _ => hReply(r.path),
    };
    await env.mount(tester, const ProjectScreen(id: 'p'));
    await tester.ensureVisible(find.text('Tải'));
    await tester.tap(find.text('Tải'));
    await tester.pumpAndSettle();
    expect(find.text('Quá nhiều yêu cầu, thử lại sau 60 giây'), findsOneWidget);
    expect(
      env.http.seen.where((r) => r.path.endsWith('download-link')),
      hasLength(1),
    );
  });
}
