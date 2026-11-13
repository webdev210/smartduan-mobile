import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Card, Chip;
import 'package:smartduan/screens/app/approve_accounts.dart';
import 'package:smartduan/screens/app/approve_devices.dart';
import 'package:smartduan/screens/app/reports.dart';
import 'package:smartduan/ui/kit.dart' show Button, Chip;
import 'package:smartduan/ui/theme.dart' as c;

import 'task_h_fakes.dart';

const user = {
  'id': 'u',
  'email': 'sale@example.com',
  'status': 'pending',
  'phone_verified_at': '2026-01-01',
  'roles': ['agent'],
};
const device = {
  'id': 'd',
  'status': 'pending',
  'kind': 'mobile',
  'user': {'id': 'u', 'email': 'sale@example.com'},
};

void main() {
  for (final devices in [false, true]) {
    testWidgets(
      'busy ${devices ? 'device' : 'account'} actions disable callbacks and retain card',
      (tester) async {
        final env = HEnv(roles: ['superadmin']);
        final pending = Completer<Reply>();
        env.http.respond = (r) => r.method == 'GET'
            ? Reply(200, {
                'data': [
                  devices
                      ? {...device, 'status': 'revoked', 'rejected': true}
                      : {...user, 'status': 'locked'},
                ],
              })
            : pending.future;
        await env.mount(
          tester,
          devices
              ? const ApproveDevicesScreen()
              : const ApproveAccountsScreen(),
        );
        final action = find.text(devices ? 'Mở lại' : 'Mở khoá');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
          tester
              .widget<Chip>(
                find.ancestor(of: action, matching: find.byType(Chip)),
              )
              .onPress,
          isNull,
        );
        expect(find.text('sale@example.com'), findsWidgets);
        pending.complete(const Reply(200));
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('device cards beyond the viewport mount only when scrolled to', (
    tester,
  ) async {
    final env = HEnv(roles: ['superadmin']);
    env.http.respond = (_) => Reply(200, {
      'data': List.generate(
        100,
        (i) => {...device, 'id': '$i', 'label': 'Device $i'},
      ),
    });
    await env.mount(tester, const ApproveDevicesScreen());
    expect(find.textContaining('Device 99'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('Device 99'),
      600,
      maxScrolls: 200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Device 99'), findsOneWidget);
  });
  for (final status in ['pending', 'active', 'locked', 'rejected']) {
    for (final role in ['manager', 'admin', 'superadmin']) {
      testWidgets('account actions $status/$role', (tester) async {
        final env = HEnv(roles: [role]);
        env.http.respond = (_) => Reply(200, {
          'data': [
            {...user, 'status': status},
          ],
        });
        await env.mount(tester, const ApproveAccountsScreen());
        final labels = tester
            .widgetList<Chip>(find.byType(Chip))
            .map((c) => c.label)
            .toList();
        expect(
          labels.contains('Duyệt'),
          status == 'pending' || status == 'rejected',
        );
        expect(
          labels.contains('Từ chối'),
          status == 'pending' || status == 'active',
        );
        expect(
          labels.contains('Khoá'),
          status == 'active' && role != 'manager',
        );
        expect(
          labels.contains('Mở khoá'),
          status == 'locked' && role != 'manager',
        );
      });
    }
  }

  testWidgets('admin cannot edit superadmin or approve unverified account', (
    tester,
  ) async {
    final env = HEnv(roles: ['admin']);
    env.http.respond = (_) => Reply(200, {
      'data': [
        {
          ...user,
          'roles': ['superadmin'],
        },
        {...user, 'id': 'unverified', 'phone_verified_at': null},
      ],
    });
    await env.mount(tester, const ApproveAccountsScreen());
    expect(find.text('Duyệt'), findsNothing);
    expect(find.text('Chỉ quản trị sàn sửa được.'), findsOneWidget);
    expect(find.text('Người dùng chưa nhập mã OTP.'), findsOneWidget);
  });

  testWidgets('account filters send selected status', (tester) async {
    final env = HEnv(roles: ['admin']);
    await env.mount(tester, const ApproveAccountsScreen());
    await tester.ensureVisible(find.text('Đang hoạt động'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang hoạt động'));
    await tester.pumpAndSettle();
    expect(env.http.seen.last.queryParameters['status'], 'active');
    await tester.ensureVisible(find.text('Xin lên F2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xin lên F2'));
    await tester.pumpAndSettle();
    expect(env.http.seen.last.queryParameters, {
      'status': 'all',
      'f2_requested': 'true',
    });
  });

  testWidgets('F2 reject sends reason and version', (tester) async {
    final env = HEnv(roles: ['manager']);
    env.http.respond = (r) => r.method == 'GET'
        ? const Reply(200, {
            'data': [
              {
                ...user,
                'f2_requested_at': '2026-11-01',
                'f2_request_version': 9,
              },
            ],
          })
        : const Reply(200);
    await env.mount(tester, const ApproveAccountsScreen());
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'thiếu hồ sơ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Từ chối hồ sơ F2'));
    await tester.tap(find.text('Từ chối hồ sơ F2'));
    await tester.pumpAndSettle();
    expect(env.http.seen.where((r) => r.method == 'POST').single.data, {
      'reason': 'thiếu hồ sơ',
      'f2_request_version': 9,
    });
  });

  testWidgets(
    'device revoke confirms without reason; stale response does not retry',
    (tester) async {
      final env = HEnv(roles: ['admin']);
      env.http.respond = (r) => r.method == 'GET'
          ? Reply(200, {
              'data': [
                {...device, 'status': 'approved'},
              ],
            })
          : const Reply(409, {'error': 'invalid_transition'});
      await env.mount(tester, const ApproveDevicesScreen());
      await tester.tap(find.text('Thu hồi'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(tester.widget<AlertDialog>(dialog).title, isA<Text>());
      expect(
        find.descendant(of: dialog, matching: find.text('Thu hồi')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        findsNothing,
      );
      expect(find.text('Lý do thu hồi'), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Thu hồi'))
            .style!
            .foregroundColor!
            .resolve({}),
        c.danger,
      );
      expect(
        find.text('Các phiên trên thiết bị này sẽ kết thúc ngay.'),
        findsOneWidget,
      );
      expect(env.http.seen.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(env.http.seen.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.text('Thu hồi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Thu hồi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Thiết bị đã đổi trạng thái — kéo xuống để làm mới.'),
        findsOneWidget,
      );
      final write = env.http.seen.where((r) => r.method == 'POST').single;
      expect(write.path, '/admin/devices/d/revoke');
      expect(write.data, isEmpty);
    },
  );

  for (final (action, label, status, body) in [
    ('approve', 'Duyệt và thay thế', 'pending', <String, Object?>{}),
    ('revoke', 'Thu hồi', 'approved', <String, Object?>{}),
    ('reopen', 'Mở lại', 'revoked', <String, Object?>{}),
    ('kind', 'Đổi loại', 'pending', <String, Object?>{'kind': 'desktop'}),
    (
      'allow_until',
      'Cho thêm tạm thời đến…',
      'approved',
      <String, Object?>{'expires_at': '2026-12-31'},
    ),
  ]) {
    testWidgets('device $action submits once and reloads', (tester) async {
      final env = HEnv(roles: ['superadmin']);
      env.http.respond = (r) => r.method == 'GET'
          ? Reply(200, {
              'data': [
                {...device, 'status': status, 'rejected': true},
              ],
            })
          : const Reply(200, device);
      await env.mount(tester, const ApproveDevicesScreen());
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      if (action == 'approve' || action == 'revoke') {
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(env.http.seen.where((r) => r.method == 'POST'), isEmpty);
        await tester.tap(find.text(label).last);
      } else if (action == 'kind') {
        await tester.ensureVisible(find.text('Máy tính'));
        await tester.tap(find.text('Máy tính'));
      } else if (action == 'allow_until') {
        expect(
          tester
              .widget<Button>(find.widgetWithText(Button, 'Cho phép tạm thời'))
              .disabled,
          isTrue,
        );
        await tester.ensureVisible(
          find.text('Chọn ngày hết hạn (tối đa 90 ngày)'),
        );
        await tester.tap(find.text('Chọn ngày hết hạn (tối đa 90 ngày)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cho phép tạm thời'));
        await tester.tap(find.text('Cho phép tạm thời'));
      }
      await tester.pumpAndSettle();
      final write = env.http.seen.where((r) => r.method == 'POST').single;
      expect(write.path, '/admin/devices/d/$action');
      if (action == 'allow_until') {
        final today = DateTime.now();
        expect(write.data, {
          'expires_at':
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        });
      } else {
        expect(write.data, body);
      }
      expect(env.http.seen.where((r) => r.method == 'GET'), hasLength(2));
    });
  }

  testWidgets('device anomalies are lazy, refresh only active block', (
    tester,
  ) async {
    final env = HEnv(roles: ['manager']);
    env.http.respond = (r) => r.path.endsWith('/anomalies')
        ? const Reply(200, {
            'shared_devices': <Object?>[],
            'ip_networks': <Object?>[],
          })
        : const Reply(200, {'data': <Object?>[]});
    await env.mount(tester, const ApproveDevicesScreen());
    expect(env.http.seen, hasLength(1));
    await tester.ensureVisible(find.text('Bất thường'));
    await tester.tap(find.text('Bất thường'));
    await tester.pumpAndSettle();
    expect(find.text('Không có dấu hiệu bất thường.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(
      env.http.seen.where((r) => r.path.endsWith('/anomalies')),
      hasLength(2),
    );
    expect(
      env.http.seen.where((r) => r.path == '/admin/devices'),
      hasLength(1),
    );
  });

  testWidgets('user device view uses user endpoint and omits filters', (
    tester,
  ) async {
    final env = HEnv(roles: ['admin']);
    await env.mount(
      tester,
      const ApproveDevicesScreen(userId: 'u', name: 'Sale'),
    );
    expect(env.http.seen.single.path, '/admin/users/u/devices');
    expect(find.text('Thiết bị · Sale'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'reports render source order and filter Vietnamese project names',
    (tester) async {
      final env = HEnv(roles: ['superadmin']);
      env.http.respond = (r) => switch (r.path) {
        '/reports/inventory' => const Reply(200, {
          'data': [
            {
              'project_id': 'p',
              'project': 'Dự án Đà Nẵng',
              'counts': {'available': 8},
              'total': 10,
            },
          ],
        }),
        '/reports/recent_activity' ||
        '/reports/project_views' => const Reply(200, {'data': <Object?>[]}),
        _ => const Reply(200),
      };
      await env.mount(tester, const ReportsScreen());
      expect(find.text('8 còn hàng / 10'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Cần chú ý')).dy,
        lessThan(tester.getTopLeft(find.text('Tồn kho theo dự án')).dy),
      );
      expect(env.http.seen.any((r) => r.path.endsWith('/survey')), isTrue);
      expect(
        env.http.seen.any((r) => r.path.endsWith('/project_views')),
        isTrue,
      );
      expect(
        env.http.seen.any(
          (r) =>
              r.path.endsWith('/bookings_weekly') ||
              r.path.endsWith('/listings'),
        ),
        isFalse,
      );
      await tester.enterText(find.byType(TextField), 'da nang');
      await tester.pumpAndSettle();
      expect(find.text('Dự án Đà Nẵng'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'không khớp');
      await tester.pumpAndSettle();
      expect(find.text('Không có dòng nào khớp từ khoá.'), findsOneWidget);
    },
  );

  testWidgets('manager requests only F2; search is trimmed', (tester) async {
    final env = HEnv(roles: ['manager']);
    await env.mount(tester, const ApproveAccountsScreen());
    expect(env.http.seen.single.queryParameters['f2_requested'], 'true');
    expect(
      find.text('Hồ sơ xin lên cộng tác viên (F2) vào đại lý của bạn.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '  sale  ');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(env.http.seen.last.queryParameters['q'], 'sale');
  });

  testWidgets('account reason required; stale mutation shown without retry', (
    tester,
  ) async {
    final env = HEnv(roles: ['admin']);
    env.http.respond = (r) => r.method == 'GET'
        ? const Reply(200, {
            'data': [user],
          })
        : const Reply(409, {'error': 'invalid_transition'});
    await env.mount(tester, const ApproveAccountsScreen());
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Button>(find.widgetWithText(Button, 'Từ chối tài khoản'))
          .disabled,
      isTrue,
    );
    await tester.enterText(find.byType(TextField).last, '  Không hợp lệ  ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Từ chối tài khoản'));
    await tester.tap(find.text('Từ chối tài khoản'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Trạng thái tài khoản đã thay đổi. Kéo xuống để tải lại danh sách.',
      ),
      findsOneWidget,
    );
    final writes = env.http.seen.where((r) => r.method == 'POST').toList();
    expect(writes, hasLength(1));
    expect(writes.single.data, {'reason': 'Không hợp lệ'});
  });

  testWidgets('F2 approval sends version and reloads list', (tester) async {
    final env = HEnv(roles: ['admin']);
    env.http.respond = (r) => r.method == 'GET'
        ? const Reply(200, {
            'data': [
              {
                ...user,
                'f2_requested_at': '2026-11-01',
                'f2_request_version': 7,
              },
            ],
          })
        : const Reply(200);
    await env.mount(tester, const ApproveAccountsScreen());
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duyệt').last);
    await tester.pumpAndSettle();
    expect(env.http.seen.where((r) => r.method == 'POST').single.data, {
      'f2_request_version': 7,
    });
    expect(env.http.seen.where((r) => r.method == 'GET'), hasLength(2));
  });

  testWidgets('device reject requires reason and reloads after success', (
    tester,
  ) async {
    final env = HEnv(roles: ['admin']);
    env.http.respond = (r) => r.method == 'GET'
        ? const Reply(200, {
            'data': [device],
          })
        : const Reply(200, device);
    await env.mount(tester, const ApproveDevicesScreen());
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Button>(find.widgetWithText(Button, 'Từ chối thiết bị'))
          .disabled,
      isTrue,
    );
    await tester.enterText(find.byType(TextField).last, '  Máy lạ  ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Từ chối thiết bị'));
    await tester.tap(find.text('Từ chối thiết bị'));
    await tester.pumpAndSettle();
    expect(env.http.seen.where((r) => r.method == 'POST').single.data, {
      'reason': 'Máy lạ',
    });
    expect(env.http.seen.where((r) => r.method == 'GET'), hasLength(2));
  });

  for (final status in ['pending', 'approved', 'revoked']) {
    for (final role in ['manager', 'admin', 'superadmin']) {
      testWidgets('device actions $status/$role', (tester) async {
        final env = HEnv(roles: [role]);
        env.http.respond = (_) => Reply(200, {
          'data': [
            {...device, 'status': status, 'rejected': status == 'revoked'},
          ],
        });
        await env.mount(tester, const ApproveDevicesScreen());
        final labels = tester
            .widgetList<Chip>(find.byType(Chip))
            .map((c) => c.label)
            .toList();
        expect(labels.contains('Duyệt và thay thế'), status == 'pending');
        expect(labels.contains('Mở lại'), status == 'revoked');
        expect(labels.contains('Thu hồi'), status == 'approved');
        expect(
          labels.contains('Cho thêm tạm thời đến…'),
          status == 'approved' && role == 'superadmin',
        );
      });
    }
  }

  for (final code in [403, 404]) {
    testWidgets(
      'reports hide denied $code blocks and skip role restricted calls',
      (tester) async {
        final env = HEnv();
        env.http.respond = (_) => Reply(code, const {'error': 'forbidden'});
        await env.mount(tester, const ReportsScreen());
        expect(find.text('Cần chú ý'), findsNothing);
        expect(find.text('Tồn kho theo dự án'), findsNothing);
        expect(
          env.http.seen.any(
            (r) =>
                r.path.endsWith('/survey') || r.path.endsWith('/project_views'),
          ),
          isFalse,
        );
        expect(
          find.text('Số liệu chi tiết, xuất file: xem trên web quản trị.'),
          findsOneWidget,
        );
      },
    );
  }
}
