import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/network_image.dart';
import 'package:smartduan/ui/project_facts.dart';
import 'package:smartduan/ui/post_body.dart';

import '../screens/app/task_h_fakes.dart';
import '../screens/public/detail_screens_test.dart' show project, DetailSession;

Future<void> mount(
  WidgetTester tester,
  Widget child,
  double width,
  double scale,
) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('article links show pressed feedback and still open', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: PostBody(
              html: '<p><a href="https://smartland.vn/project">Mở liên kết</a></p>',
            ),
          ),
        ),
        GoRoute(path: '/xem', builder: (_, _) => const Text('Đã mở')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final link = find.text('Mở liên kết', findRichText: true);
    final gesture = await tester.startGesture(
      tester.getTopLeft(link) + const Offset(24, 12),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final paragraph = tester.renderObject<RenderParagraph>(link);
    expect(
      paragraph.text
          .getSpanForPosition(const TextPosition(offset: 1))!
          .style!
          .backgroundColor,
      isNotNull,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Đã mở'), findsOneWidget);
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('compact definitions at $width / $scale', (tester) async {
        await mount(
          tester,
          const ProjectFacts(
            entries: [
              (
                'Quy mô',
                'Một giá trị dài cần xuống dòng trong ô mà không mất nội dung',
              ),
              ('Bàn giao', 'Năm 2027'),
              ('Pháp lý', 'Sở hữu lâu dài'),
            ],
          ),
          width,
          scale,
        );
        expect(find.byType(kit.Card), findsOneWidget);
        final first = tester.getTopLeft(find.text('Quy mô'));
        final second = tester.getTopLeft(find.text('Bàn giao'));
        if (width - 40 >= 340 && scale <= 1.3) {
          expect(second.dy, first.dy);
          expect(second.dx, greaterThan(first.dx));
        } else {
          expect(second.dy, greaterThan(first.dy));
        }
        expect(tester.takeException(), isNull);
      });

      for (final cover in [null, 'https://example.vn/cover.jpg']) {
        testWidgets('source preview $cover at $width / $scale', (tester) async {
          await mount(
            tester,
            ProjectSourcePreview(
              name: 'Dự án A',
              source: 'https://smartland.vn/du-an/a?ref=app',
              cover: cover,
            ),
            width,
            scale,
          );
          expect(find.text('smartland.vn'), findsOneWidget);
          expect(find.textContaining('?ref='), findsNothing);
          expect(
            find.byType(AppNetworkImage),
            cover == null ? findsNothing : findsOneWidget,
          );
          if (cover != null) {
            expect(
              tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
              16 / 9,
            );
          }
          expect(
            find.bySemanticsLabel(
              'Mở trang giới thiệu dự án Dự án A trên smartland.vn',
            ),
            findsOneWidget,
          );
          expect(
            tester.getSize(find.byType(kit.Card)).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('public project hierarchy at $width / $scale', (
        tester,
      ) async {
        final container = ProviderContainer.test(
          overrides: [
            sessionProvider.overrideWith(
              () => DetailSession(SessionStatus.guest),
            ),
            fetchPublicProjectProvider('SKY')
                .overrideWith((_) async => project),
          ],
        );
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const ProjectDetailScreen(code: 'SKY'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final buttons = tester.widgetList<kit.Button>(find.byType(kit.Button));
        expect(buttons.where((b) => b.kind == 'primary').map((b) => b.title), [
          'Xem bảng hàng',
        ]);
        for (final button in find.byType(kit.Button).evaluate()) {
          expect(
            tester.getSize(find.byWidget(button.widget)).height,
            greaterThanOrEqualTo(52),
          );
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('signed-in project hierarchy at $width / $scale', (
        tester,
      ) async {
        final env = HEnv();
        env.http.respond = (r) => switch (r.path) {
          '/projects/p/contacts' => const Reply(200, {
            'data': [
              {
                'full_name': 'Nguyễn An',
                'role_label': 'Quản lý dự án',
                'phone': '0901234567',
              },
            ],
          }),
          '/content/projects/p/documents' => const Reply(200, {
            'data': [
              {
                'id': 'doc',
                'title': 'Tài liệu giới thiệu dự án và chính sách bán hàng',
              },
            ],
          }),
          '/content/projects/p/policies/current-scopes' => const Reply(200, {
            'data': [
              {
                'id': 'policy',
                'title': 'Chính sách chung',
                'summary': 'Ưu đãi dành cho khách hàng',
                'effective_from': '2026-01-01',
                'file_url': 'https://smartduan.vn/policy.pdf',
              },
            ],
          }),
          '/projects/p/subdivisions' => const Reply(200, {
            'data': [
              {
                'id': 'sub',
                'block_id': 'b',
                'code': 'A',
                'name': 'Phân khu ven sông',
                'description': 'Không gian sống gần thiên nhiên',
                'total_units': 2,
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
          '/content/projects/p/faqs' => const Reply(200, {
            'data': [
              {
                'id': 'faq',
                'question': 'Khi nào bàn giao?',
                'answer': 'Năm 2027',
              },
            ],
          }),
          _ => hReply(r.path),
        };
        await env.mount(
          tester,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const ProjectScreen(id: 'p'),
          ),
        );
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<kit.Button>(find.byType(kit.Button))
              .where((b) => b.kind == 'primary')
              .map((b) => b.title),
          ['Mở bảng hàng'],
        );
        expect(find.byType(ProjectFacts), findsOneWidget);
        for (final title in [
          'Phân khu (1)',
          'Chính sách bán hàng (1)',
          'Đầu mối dự án',
          'Tài liệu (1)',
          'Tiến độ (1)',
          'Đào tạo (1)',
          'Hỏi đáp',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        await tester.ensureVisible(find.text('Khi nào bàn giao?'));
        await tester.tap(find.text('Khi nào bàn giao?'));
        await tester.pumpAndSettle();
        expect(find.text('Năm 2027'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('buttons stay equal and single-line at $width / $scale', (
        tester,
      ) async {
        await mount(
          tester,
          kit.ButtonGroup(
            children: [
              kit.Button(title: 'Mở bảng hàng', onPress: () {}),
              kit.Button(
                title: 'Đăng ký sale',
                kind: 'secondary',
                onPress: () {},
              ),
            ],
          ),
          width,
          scale,
        );
        final buttons = find.byType(kit.Button);
        expect(
          tester.getSize(buttons.at(0)).height,
          tester.getSize(buttons.at(1)).height,
        );
        expect(tester.getSize(buttons.at(0)).height, greaterThanOrEqualTo(52));
        for (final title in ['Mở bảng hàng', 'Đăng ký sale']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(title),
          );
          expect(paragraph.maxLines, 1);
          if (scale == 1) expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('source preview opens the existing in-app route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: ProjectSourcePreview(
              name: 'A',
              source: 'https://smartland.vn/project',
            ),
          ),
        ),
        GoRoute(
          path: '/xem',
          builder: (_, state) => Text(state.uri.queryParameters['url'] ?? ''),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Xem trang giới thiệu dự án'));
    await tester.pumpAndSettle();
    expect(find.text('https://smartland.vn/project'), findsOneWidget);
  });

  for (final size in ['md', 'sm']) {
    testWidgets('all button kinds have the same $size height', (tester) async {
      await mount(
        tester,
        Column(
          children: [
            for (final kind in [
              'primary',
              'secondary',
              'soft',
              'link',
              'danger',
            ])
              kit.Button(title: kind, kind: kind, size: size, onPress: () {}),
          ],
        ),
        390,
        1,
      );
      for (final finder in find.byType(kit.Button).evaluate()) {
        expect(
          tester.getSize(find.byWidget(finder.widget)).height,
          size == 'sm' ? 48 : 52,
        );
        final surface = find.descendant(
          of: find.byWidget(finder.widget),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.minHeight == (size == 'sm' ? 44 : 52),
          ),
        );
        expect(tester.getSize(surface).height, size == 'sm' ? 44 : 52);
      }
    });
  }
}
