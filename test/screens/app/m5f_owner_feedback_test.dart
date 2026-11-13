import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/api/public.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/app/home.dart';
import 'package:smartduan/screens/app/project.dart';
import 'package:smartduan/screens/app/unit.dart';
import 'package:smartduan/screens/public/project_detail.dart';
import 'package:smartduan/ui/gallery_viewer.dart';
import 'package:smartduan/ui/kit.dart' as kit;
import 'package:smartduan/ui/network_image.dart';
import 'package:smartduan/ui/project_card.dart';

import '../../support/responsive.dart';
import 'm5d_r5_project_test.dart' show mount;
import 'task_h_fakes.dart';

void main() {
  testWidgets('basket and app-bar sharing retain their routes', (t) async {
    final env = HEnv();
    env.http.respond = (r) => r.path == '/projects/p'
        ? const Reply(200, {
            ...hProject,
            'basket_embed_url': 'https://smartduan.vn/basket',
          })
        : hReply(r.path);
    final router = await mount(t, env.container, const ProjectScreen(id: 'p'));
    await t.tap(find.byTooltip('Chia sẻ dự án'));
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/chia-se/p');
    router.pop();
    await t.pumpAndSettle();
    await t.tap(find.text('Mở rổ hàng ngoài'));
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/ro-hang');
    expect(router.state.uri.queryParameters, {
      'project': 'p',
      'url': 'https://smartduan.vn/basket',
    });
  });

  for (final source in ['project', 'unit', 'public']) {
    testWidgets('$source image opens the shared gallery', (t) async {
      final env = HEnv();
      env.http.respond = (r) => switch (r.path) {
        '/content/projects/p/media' => const Reply(200, {
          'data': [
            {
              'id': '1',
              'media_type': 'image',
              'url': 'https://smartduan.vn/1.jpg',
            },
            {
              'id': '2',
              'media_type': 'image',
              'url': 'https://smartduan.vn/2.jpg',
            },
          ],
        }),
        '/units/u/images' => const Reply(200, {
          'data': [
            {'id': '1', 'url': 'https://smartduan.vn/1.jpg'},
            {'id': '2', 'url': 'https://smartduan.vn/2.jpg'},
          ],
        }),
        '/public/projects/P' => const Reply(200, {
          'id': 'p',
          'code': 'P',
          'name': 'Dự án',
          'media': [
            {
              'id': '1',
              'media_type': 'image',
              'url': 'https://smartduan.vn/1.jpg',
            },
            {
              'id': '2',
              'media_type': 'image',
              'url': 'https://smartduan.vn/2.jpg',
            },
          ],
        }),
        _ => hReply(r.path),
      };
      await mount(t, env.container, switch (source) {
        'unit' => const UnitScreen(id: 'u'),
        'public' => const ProjectDetailScreen(code: 'P'),
        _ => const ProjectScreen(id: 'p'),
      });
      await t.scrollUntilVisible(
        find.byType(AppNetworkImage).first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        t.element(find.byType(AppNetworkImage).first),
        alignment: .5,
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(AppNetworkImage).first);
      await t.pumpAndSettle();
      expect(find.byType(GalleryViewer), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });
  }

  for (final basket in [false, true]) {
    testWidgets('project bar responsive basket=$basket', (t) async {
      await expectResponsive(t, () async {
        final env = HEnv();
        env.http.respond = (r) => r.path == '/projects/p'
            ? Reply(200, {
                ...hProject,
                if (basket) 'basket_embed_url': 'https://smartduan.vn/basket',
              })
            : hReply(r.path);
        await mount(t, env.container, const ProjectScreen(id: 'p'));
        final bar = find.byKey(const ValueKey('project-actions'));
        expect(
          find.descendant(of: bar, matching: find.text('Bảng hàng')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bar, matching: find.text('Mở rổ hàng ngoài')),
          basket ? findsOneWidget : findsNothing,
        );
        expect(
          find.descendant(of: bar, matching: find.text('Chia sẻ')),
          findsNothing,
        );
        expect(
          find.descendant(of: bar, matching: find.text('Liên hệ')),
          findsNothing,
        );
        expect(find.byTooltip('Chia sẻ dự án'), findsOneWidget);
        if (basket) {
          final board = find.ancestor(
            of: find.text('Bảng hàng'),
            matching: find.byType(kit.Pressable),
          );
          final external = find.ancestor(
            of: find.text('Mở rổ hàng ngoài'),
            matching: find.byType(kit.Pressable),
          );
          final a = t.getRect(board), b = t.getRect(external);
          if (a.top == b.top) {
            expect(a.height, b.height);
          } else {
            expect(b.top, greaterThanOrEqualTo(a.bottom));
          }
        }
        env.container.dispose();
      });
    });
  }

  for (final state in ['logo', 'missing', 'loading', 'error']) {
    testWidgets('developer $state keeps reserved logo space and name', (
      t,
    ) async {
      final env = HEnv();
      env.http.respond = (r) => r.path == '/projects/p'
          ? const Reply(200, {
              ...hProject,
              'developer_id': 'd',
              'developer_name': 'Nhà phát triển',
            })
          : hReply(r.path);
      final container = ProviderContainer.test(
        overrides: [
          apiClientProvider.overrideWithValue(env.client),
          // Reuse the signed-in session and public list, without an extra endpoint.
          sessionProvider.overrideWith(() => HSession(['agent'])),
          listPublicDevelopersProvider.overrideWith(
            (_) => switch (state) {
              'loading' => Completer<List<PublicDeveloper>>().future,
              'error' => Future<List<PublicDeveloper>>.error(
                StateError('offline'),
              ),
              _ => Future.value([
                PublicDeveloper(
                  id: 'd',
                  name: 'Nhà phát triển',
                  slug: 'developer',
                  logoUrl: state == 'logo'
                      ? 'https://smartduan.vn/logo.png'
                      : null,
                ),
              ]),
            },
          ),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      final router = await mount(t, container, const ProjectScreen(id: 'p'));
      expect(find.text('Nhà phát triển'), findsOneWidget);
      final logo = find.byWidgetPredicate(
        (w) => w is AppNetworkImage && w.semanticLabel == 'Logo Nhà phát triển',
      );
      expect(logo, state == 'logo' ? findsOneWidget : findsNothing);
      final reserved = find.descendant(
        of: find.byWidgetPredicate(
          (w) =>
              w is kit.Pressable &&
              w.label == 'Chủ đầu tư Nhà phát triển, xem các dự án khác',
        ),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 40 && w.height == 40,
        ),
      );
      expect(reserved, findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.tap(find.text('Nhà phát triển'));
      await t.pumpAndSettle();
      expect(
        router.state.uri.path,
        state == 'logo' || state == 'missing'
            ? '/chu-dau-tu/developer'
            : '/kham-pha',
      );
    });
  }

  testWidgets(
    'Home restores RN section order, cards, tiles and allocated count',
    (t) async {
      final env = HEnv();
      await mount(t, env.container, const Scaffold(body: HomeScreen()));
      final sections = t
          .widgetList<kit.Section>(find.byType(kit.Section))
          .toList();
      expect(sections.map((s) => s.title), [
        'Dự án của bạn',
        'Truy cập nhanh',
        'Bảng tin mới',
      ]);
      expect(sections.first.eyebrow, '1 dự án được phân bổ');
      expect(find.byType(ProjectCard), findsOneWidget);
      expect(find.byType(kit.TileGrid), findsOneWidget);
      expect(find.text('Yêu thích'), findsNothing);
      expect(find.text('Biến động'), findsNothing);
      expect(find.text('Thông báo'), findsNothing);
    },
  );
}
