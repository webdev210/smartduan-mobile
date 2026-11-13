import 'dart:async';

import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import '../../support/responsive.dart';
import '../public/detail_screens_test.dart' show project, DetailSession;
import 'task_h_fakes.dart';

const longName = 'Khu đô thị ven sông Nguyễn Hữu Cảnh và đại lộ Thăng Long';
const longText = 'Thông tin chính sách và tiến độ dành cho khách hàng. ';

Reply populated(String path) => switch (path) {
  '/projects/p' => Reply(200, {
    ...hProject,
    'name': longName,
    'price_from': '1234567890123',
    'description': longText * 30,
    'address': longName,
  }),
  '/projects/p/contacts' => const Reply(200, {
    'data': [
      {
        'full_name': longName,
        'role_label': 'Quản lý kinh doanh dự án',
        'phone': '0901234567',
      },
      {
        'full_name': 'Đầu mối giới hạn',
        'role_label': 'Chuyên viên',
        'phone': '090***4567',
      },
    ],
  }),
  '/content/projects/p/faqs' => Reply(200, {
    'data': [
      {'id': 'faq', 'question': longName, 'answer': longText * 20},
    ],
  }),
  '/content/projects/p/documents' => Reply(200, {
    'data': List.generate(8, (i) => {'id': 'doc$i', 'title': '$longName $i'}),
  }),
  '/content/projects/p/media' => Reply(200, {
    'data': List.generate(
      12,
      (i) => {
        'id': 'image$i',
        'media_type': 'image',
        'url': 'https://smartduan.vn/$i.jpg',
        'caption': longName,
      },
    ),
  }),
  '/content/projects/p/policies/current-scopes' => Reply(200, {
    'data': [
      {
        'id': 'policy',
        'title': longName,
        'summary': longText * 20,
        'effective_from': '2026-01-01',
      },
    ],
  }),
  _ => hReply(path),
};

Future<GoRouter> mount(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  bool settle = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      for (final path in [
        '/bang-hang/:id',
        '/du-an/:id',
        '/chia-se/:id',
        '/dang-nhap',
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
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
  return router;
}

Future<void> scrollToEnd(WidgetTester tester, {bool sheet = false}) async {
  final scroll = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) => s.position.axis == Axis.vertical)
      .toList();
  final target = sheet ? scroll.last : scroll.first;
  for (var i = 0; i < 40; i++) {
    final position = target.position;
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo((position.pixels + 400).clamp(0, position.maxScrollExtent));
    await tester.pump();
  }
  await tester.pump();
}

void main() {
  for (final state in ['populated', 'empty', 'error', 'loading']) {
    testWidgets('internal project responsive $state', (tester) async {
      await expectResponsive(tester, () async {
        final env = HEnv();
        env.http.respond = (r) => switch (state) {
          'loading' => Completer<Reply>().future,
          'error' => const Reply(503, {'message': longName}),
          'empty' => hReply(r.path),
          _ => populated(r.path),
        };
        await mount(
          tester,
          env.container,
          const ProjectScreen(id: 'p'),
          settle: state != 'loading',
        );
        if (state == 'populated') {
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .viewportDimension,
            greaterThan(80),
          );
          final actions = find.byKey(const ValueKey('project-actions'));
          final before = tester.getTopLeft(actions);
          for (final label in ['Bảng hàng', 'Chia sẻ', 'Liên hệ']) {
            final text = find.descendant(
              of: actions,
              matching: find.text(label),
            );
            expect(
              tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
              isFalse,
            );
          }
          await scrollToEnd(tester);
          expect(tester.getTopLeft(actions), before);
        }
        await scrollToEnd(tester);
        if (state == 'populated') {
          final faq = find.byType(kit.FaqItem);
          await tester.ensureVisible(faq);
          await tester.pumpAndSettle();
          final tile = find.descendant(
            of: faq,
            matching: find.byType(ListTile),
          );
          // A long question can exceed the visible body above the pinned actions.
          await tester.tapAt(tester.getTopLeft(tile) + const Offset(24, 16));
          await tester.pumpAndSettle();
          await scrollToEnd(tester);
        }
      });
    });
    testWidgets('public project responsive $state', (tester) async {
      await expectResponsive(tester, () async {
        final env = HEnv(roles: []);
        final container = ProviderContainer.test(
          overrides: [
            apiClientProvider.overrideWithValue(env.client),
            sessionProvider.overrideWith(
              () => DetailSession(SessionStatus.guest),
            ),
            fetchPublicProjectProvider('SKY').overrideWith(
              (_) => switch (state) {
                'loading' => Completer<PublicProject>().future,
                'error' => Future<PublicProject>.error(StateError(longName)),
                'empty' => Future.value(
                  PublicProject(
                    id: 'p',
                    code: 'SKY',
                    name: longName,
                    status: '',
                  ),
                ),
                _ => Future.value(
                  PublicProject.fromJson({
                    'id': 'p',
                    'code': 'SKY',
                    'name': longName,
                    'price_from': '1234567890123',
                    'overview_json': {
                      'summary': longText * 30,
                      'source_url': 'https://smartland.vn/du-an/SKY',
                      'floor_plans': [
                        {
                          'name': longName,
                          'url': 'https://smartduan.vn/plan.jpg',
                        },
                      ],
                    },
                    'developer': {'id': 'dev', 'name': longName, 'slug': 'dev'},
                    'media': List.generate(
                      6,
                      (i) => {
                        'id': 'image$i',
                        'media_type': 'image',
                        'url': 'https://smartduan.vn/$i.jpg',
                        'caption': longName,
                      },
                    ),
                    'progress': [
                      {
                        'title': longName,
                        'occurred_on': '2026-01-01',
                        'body': longText * 10,
                      },
                    ],
                    'subdivisions': [
                      {'name': longName, 'description': longText * 10},
                    ],
                    'documents': [
                      {'name': longName, 'url': 'https://smartduan.vn/a.pdf'},
                    ],
                    'faqs': [
                      {
                        'id': 'faq',
                        'question': longName,
                        'answer': longText * 20,
                      },
                    ],
                  }),
                ),
              },
            ),
          ],
        );
        await mount(
          tester,
          container,
          const ProjectDetailScreen(code: 'SKY'),
          settle: state != 'loading',
        );
        if (state == 'populated') {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text('Xem bảng hàng'))
                .didExceedMaxLines,
            isFalse,
          );
        }
        await scrollToEnd(tester);
        if (state == 'populated') {
          final faq = find.byType(kit.FaqItem);
          await tester.ensureVisible(faq);
          await tester.pumpAndSettle();
          final tile = find.descendant(
            of: faq,
            matching: find.byType(ListTile),
          );
          // A long question can exceed the visible body above the pinned actions.
          await tester.tapAt(tester.getTopLeft(tile) + const Offset(24, 16));
          await tester.pumpAndSettle();
          await scrollToEnd(tester);
        }
        env.container.dispose();
      });
    });
  }

  testWidgets('signed-in public project responsive with direct board action', (
    tester,
  ) async {
    await expectResponsive(tester, () async {
      final env = HEnv();
      final container = ProviderContainer.test(
        overrides: [
          apiClientProvider.overrideWithValue(env.client),
          sessionProvider.overrideWith(() => HSession(['agent'])),
          fetchPublicProjectProvider('SKY').overrideWith((_) async => project),
        ],
      );
      await mount(tester, container, const ProjectDetailScreen(code: 'SKY'));
      final before = tester.getTopLeft(find.text('Bảng hàng'));
      await scrollToEnd(tester);
      expect(tester.getTopLeft(find.text('Bảng hàng')), before);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Bảng hàng'))
            .didExceedMaxLines,
        isFalse,
      );
    });
  });

  testWidgets('contact sheet responsive with authorized and masked numbers', (
    tester,
  ) async {
    await expectResponsive(tester, () async {
      final env = HEnv();
      env.http.respond = (r) => populated(r.path);
      await mount(tester, env.container, const ProjectScreen(id: 'p'));
      await tester.tap(find.text('Liên hệ'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester, sheet: true);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('090***4567'),
        ),
        findsOneWidget,
      );
      expect(find.text('Gọi'), findsOneWidget);
      expect(find.text('Nhắn SMS'), findsOneWidget);
      expect(find.text('Sao chép'), findsOneWidget);
    });
  });

  for (final state in ['empty', 'error', 'loading']) {
    testWidgets('contact sheet responsive $state', (tester) async {
      await expectResponsive(tester, () async {
        final env = HEnv();
        env.http.respond = (r) => r.path.endsWith('/contacts')
            ? switch (state) {
                'error' => const Reply(503, {'message': longName}),
                'loading' => Completer<Reply>().future,
                _ => const Reply(200, {'data': <Object?>[]}),
              }
            : hReply(r.path);
        await mount(
          tester,
          env.container,
          const ProjectScreen(id: 'p'),
          settle: state != 'loading',
        );
        await tester.tap(find.text('Liên hệ'));
        if (state == 'loading') {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        } else {
          await tester.pumpAndSettle();
        }
        await scrollToEnd(tester, sheet: true);
      });
    });
  }

  testWidgets('contacts denied by server offer no fixed contact action', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) =>
        r.path.endsWith('/contacts') ? const Reply(403) : hReply(r.path);
    await mount(tester, env.container, const ProjectScreen(id: 'p'));
    expect(find.text('Liên hệ'), findsNothing);
  });

  testWidgets('search remains visible above keyboard', (tester) async {
    final env = HEnv();
    await mount(tester, env.container, const ProjectScreen(id: 'p'));
    await tester.scrollUntilVisible(
      find.byType(TextField),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('project-actions')), findsNothing);
    expect(
      tester.getBottomRight(find.byType(TextField)).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height - 300),
    );
    expect(tester.takeException(), isNull);
  });

  for (final role in ['', 'sales_free', 'agent']) {
    testWidgets('fixed project actions preserve gates for $role', (
      tester,
    ) async {
      final env = HEnv(roles: role.isEmpty ? [] : [role]);
      final router = await mount(
        tester,
        env.container,
        const ProjectScreen(id: 'p'),
      );
      final fixed = find.byKey(const ValueKey('project-actions'));
      expect(fixed, findsOneWidget);
      expect(
        find.descendant(of: fixed, matching: find.text('Bảng hàng')),
        role.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        find.descendant(of: fixed, matching: find.text('Chia sẻ')),
        role == 'agent' ? findsOneWidget : findsNothing,
      );
      if (role.isNotEmpty) {
        await tester.tap(find.text('Bảng hàng'));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/bang-hang/p');
      }
    });
  }

  testWidgets('eligible public project has direct board shortcut', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(() => HSession(['agent'])),
        fetchPublicProjectProvider('SKY').overrideWith((_) async => project),
      ],
    );
    final router = await mount(
      tester,
      container,
      const ProjectDetailScreen(code: 'SKY'),
    );
    await tester.tap(find.text('Bảng hàng'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/bang-hang/id');
  });

  for (final failed in [false, true]) {
    testWidgets(
      'public project sharing ${failed ? 'recovers from failure' : 'uses established public URL'}',
      (tester) async {
        final calls = <MethodCall>[];
        const channel = MethodChannel('dev.fluttercommunity.plus/share');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            if (failed) throw PlatformException(code: 'unavailable');
            return 'success';
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final env = HEnv();
        final container = ProviderContainer.test(
          overrides: [
            apiClientProvider.overrideWithValue(env.client),
            sessionProvider.overrideWith(() => HSession(['agent'])),
            fetchPublicProjectProvider('SKY')
                .overrideWith((_) async => project),
          ],
        );
        await mount(tester, container, const ProjectDetailScreen(code: 'SKY'));
        await tester.tap(find.bySemanticsLabel('Chia sẻ trang dự án'));
        await tester.pumpAndSettle();
        expect(calls, hasLength(1));
        expect((calls.single.arguments as Map)['text'], endsWith('/du-an/SKY'));
        expect(
          (calls.single.arguments as Map)['originWidth'],
          greaterThanOrEqualTo(48),
        );
        expect(
          find.text('Không mở được chia sẻ. Vui lòng thử lại.'),
          failed ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets('unavailable public project cannot be shared', (tester) async {
    final container = ProviderContainer.test(
      overrides: [
        sessionProvider.overrideWith(() => HSession([])),
        fetchPublicProjectProvider(
          'PRIVATE',
        ).overrideWith((_) async => throw StateError('Không tìm thấy dự án')),
      ],
    );
    await mount(tester, container, const ProjectDetailScreen(code: 'PRIVATE'));
    expect(find.bySemanticsLabel('Chia sẻ trang dự án'), findsNothing);
  });

  testWidgets('contacts call and SMS launch the authorized number', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final env = HEnv();
    env.http.respond = (r) => populated(r.path);
    await mount(tester, env.container, const ProjectScreen(id: 'p'));
    await tester.tap(find.text('Liên hệ'));
    await tester.pumpAndSettle();
    for (final label in ['Gọi', 'Nhắn SMS']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(calls.map((call) => (call.arguments as Map)['url']), [
      'tel:0901234567',
      'sms:0901234567',
    ]);
    expect(
      env.http.seen.where((r) => r.path.endsWith('/contacts')),
      hasLength(1),
    );
  });

  testWidgets('contact copy uses only the unmasked number without refetch', (
    tester,
  ) async {
    final env = HEnv();
    env.http.respond = (r) => populated(r.path);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
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
    await mount(tester, env.container, const ProjectScreen(id: 'p'));
    await tester.tap(find.text('Liên hệ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sao chép'));
    await tester.tap(find.text('Sao chép'));
    await tester.pumpAndSettle();
    expect(copied, '0901234567');
    expect(
      env.http.seen.where((r) => r.path.endsWith('/contacts')),
      hasLength(1),
    );
    expect(find.text('Đã sao chép số điện thoại'), findsOneWidget);
    expect(find.byType(kit.Sheet), findsOneWidget);
  });
}
