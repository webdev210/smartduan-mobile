// ignore_for_file: depend_on_referenced_packages
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:smartduan/auth/session.dart';
import 'package:smartduan/screens/public/tour_360.dart';
import 'package:smartduan/screens/public/viewer.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/project_card.dart';
import 'package:smartduan/ui/project_compare.dart';
import 'package:smartduan/ui/theme.dart' as c;
import 'package:smartduan/ui/tour360.dart';
import 'package:smartduan/ui/tour_frame.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../screens/auth/auth_fakes.dart' show TestSession;
import 'detail_webview_fake.dart';

const _tour = 'https://360.smartrealtors.vn/share/collection/7H1b3';
const _sample = Browsable(
  code: 'A',
  name: 'Artisan Park',
  status: 'selling',
  province: 'Bình Dương',
  developerName: 'Gamuda Land',
  projectType: 'mixed',
  priceFrom: '2500000000',
  activity7d: 3,
);
const _insets = EdgeInsets.fromLTRB(44, 48, 20, 34);

void _inside(WidgetTester tester, Finder finder, Rect safe) {
  expect(finder, findsWidgets);
  for (final element in finder.evaluate()) {
    final rect = tester.getRect(find.byElementPredicate((e) => e == element));
    expect(
      rect.left,
      greaterThanOrEqualTo(safe.left),
      reason: '$finder: $rect',
    );
    expect(rect.top, greaterThanOrEqualTo(safe.top), reason: '$finder: $rect');
    expect(rect.right, lessThanOrEqualTo(safe.right), reason: '$finder: $rect');
    expect(
      rect.bottom,
      lessThanOrEqualTo(safe.bottom),
      reason: '$finder: $rect',
    );
  }
}

Future<void> _card(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  bool carousel = false,
  Browsable p = _sample,
  VoidCallback? onPress,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(TestSession.new)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                height: carousel ? width * 10 / 16 + 310 * scale : null,
                child: ProjectCard(
                  p: p,
                  width: carousel ? width : null,
                  onPress: onPress ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => WebViewPlatform.instance = DetailWebViewPlatform());

  testWidgets('390dp sample card height and compact natural facts', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await _card(tester);
    final height = tester.getSize(find.byType(ProjectCard)).height;
    debugPrint('390dp Artisan Park list card: ${height.toStringAsFixed(2)}dp');
    expect(height, lessThan(450));
    expect(find.text('Loại hình'), findsNothing);
    expect(find.text('So sánh'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final carousel in [false, true]) {
    testWidgets(
      'compare and heart share the cover with 48dp targets carousel $carousel',
      (tester) async {
        addTearDown(tester.view.reset);
        await _card(tester, width: 320, scale: 2, carousel: carousel);
        final compare = find.bySemanticsLabel('So sánh Artisan Park');
        final heart = find.bySemanticsLabel('Yêu thích Artisan Park');
        final cr = tester.getRect(compare), hr = tester.getRect(heart);
        final cover = tester.getRect(find.byType(ProjectMedia));
        expect(cr.top, hr.top);
        expect(hr.left - cr.right, 8);
        for (final rect in [cr, hr]) {
          expect(rect.width, 48);
          expect(rect.height, 48);
          expect(cover.contains(rect.topLeft), isTrue);
          expect(cover.contains(rect.bottomRight), isTrue);
        }
        final badge = tester.getRect(find.text('Đang bán'));
        expect(badge.right, lessThanOrEqualTo(cr.left - 8));
        expect(
          DefaultTextStyle.of(tester.element(find.text('Đang bán'))).overflow,
          TextOverflow.ellipsis,
        );
        final visuals = find.descendant(
          of: compare,
          matching: find.byType(Material),
        );
        expect(tester.getSize(visuals), const Size(44, 44));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProjectCard)),
        );
        await tester.tapAt(cr.topLeft + const Offset(1, 1));
        await tester.pump();
        expect(container.read(projectCompareProvider), ['A']);
        expect(tester.widget<Material>(visuals).color, c.brand);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('list cards omit absent detail and activity lines', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await _card(
      tester,
      p: const Browsable(name: 'A', status: 'selling'),
    );
    expect(find.byIcon(Ionicons.locationOutline), findsNothing);
    expect(find.byIcon(Ionicons.businessOutline), findsNothing);
    expect(find.byIcon(Ionicons.timeOutline), findsNothing);
    expect(find.byIcon(Ionicons.flameOutline), findsNothing);
    expect(find.byType(Visibility), findsNothing);
    expect(find.text('Liên hệ'), findsOneWidget);
    expect(
      tester.getRect(find.text('Giá từ')).top -
          tester.getRect(find.text('A').last).bottom,
      12,
    );
  });

  testWidgets('narrow carousel puts type below price', (tester) async {
    addTearDown(tester.view.reset);
    await _card(tester, width: 280, carousel: true);
    expect(
      tester.getRect(find.text('Cao tầng & thấp tầng')).top,
      greaterThanOrEqualTo(tester.getRect(find.text('2,5 tỷ')).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cover compare keeps the maximum-three feedback', (tester) async {
    addTearDown(tester.view.reset);
    await _card(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProjectCard)),
    );
    final basket = container.read(projectCompareProvider.notifier);
    for (final code in ['B', 'C', 'D']) {
      basket.add(code);
    }
    await tester.tap(find.bySemanticsLabel('So sánh Artisan Park'));
    await tester.pump();
    expect(container.read(projectCompareProvider), ['B', 'C', 'D']);
    expect(find.text('Tối đa 3 dự án'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('compare tap toggles and 350ms hold adds and opens picker', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var opened = 0;
    await _card(tester, onPress: () => opened++);
    final compare = find.bySemanticsLabel('So sánh Artisan Park');
    final context = tester.element(find.byType(ProjectCard));
    final container = ProviderScope.containerOf(context);
    await tester.tap(compare);
    await tester.pump();
    expect(container.read(projectCompareProvider), ['A']);
    final selected = tester.widget<Semantics>(compare).properties.selected;
    expect(selected, isTrue);
    final icon = tester.widget<Icon>(find.byIcon(Ionicons.gitCompareOutline));
    expect(icon.color, Colors.white);
    await tester.tap(compare);
    await tester.pump();
    expect(container.read(projectCompareProvider), isEmpty);
    final gesture = await tester.startGesture(tester.getCenter(compare));
    await tester.pump(const Duration(milliseconds: 351));
    await gesture.up();
    await tester.pump();
    expect(container.read(projectCompareProvider), ['A']);
    expect(find.text('So sánh dự án'), findsOneWidget);
    expect(opened, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('compact row $width scale $scale has no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionProvider.overrideWith(TestSession.new)],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ProjectRow(p: _sample, onPress: () {}),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
      for (final carousel in [false, true]) {
        testWidgets('$width scale $scale carousel $carousel has no overflow', (
          tester,
        ) async {
          addTearDown(tester.view.reset);
          await _card(
            tester,
            width: width,
            scale: scale,
            carousel: carousel,
            p: const Browsable(
              code: 'A',
              name: 'Dự án tên dài xuống hai dòng để kiểm tra',
              status: 'upcoming',
              province: 'Thành phố Hồ Chí Minh',
              developerName: 'Chủ đầu tư tên rất dài',
              projectType: 'mixed',
              priceFrom: '2500000000',
              activity7d: 20,
            ),
          );
          expect(tester.takeException(), isNull);
          final price = tester.getRect(find.text('2,5 tỷ'));
          final type = tester.getRect(find.text('Cao tầng & thấp tầng'));
          if (scale >= 1.5) {
            expect(type.top, greaterThanOrEqualTo(price.bottom));
          }
          final card = tester.getRect(find.byType(ProjectCard));
          expect(price.bottom, lessThanOrEqualTo(card.bottom));
          expect(type.bottom, lessThanOrEqualTo(card.bottom));
        });
      }
    }
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final immersive in [false, true]) {
      testWidgets('viewer back target safe in $size immersive $immersive', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: immersive ? EdgeInsets.zero : _insets,
                viewPadding: _insets,
              ),
              child: child!,
            ),
            home: const SizedBox(),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const ViewerScreen(url: _tour, title: 'Artisan Park'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final back = find.byType(BackButton);
        _inside(
          tester,
          back,
          Rect.fromLTRB(44, 48, size.width - 20, size.height - 34),
        );
        expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(ViewerScreen), findsNothing);
      });
      for (final surface in ['tour screen', 'viewer', 'tour widget', 'frame']) {
        testWidgets('$surface safe in $size immersive $immersive', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final widget = switch (surface) {
            'tour screen' => const Tour360Screen(
              url: _tour,
              name: 'Artisan Park',
            ),
            'viewer' => const ViewerScreen(url: _tour, title: 'Artisan Park'),
            'tour widget' => const Scaffold(
              body: SingleChildScrollView(
                child: Tour360(url: _tour, name: 'Artisan Park', cover: null),
              ),
            ),
            _ => const Scaffold(
              body: TourFrame(url: _tour, title: 'Artisan Park'),
            ),
          };
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: immersive ? EdgeInsets.zero : _insets,
                  viewPadding: _insets,
                ),
                child: widget,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          final safe = Rect.fromLTRB(44, 48, size.width - 20, size.height - 34);
          if (surface == 'tour screen') {
            final close = find.bySemanticsLabel('Đóng tour 360°');
            _inside(tester, close, safe);
            expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
            _inside(tester, find.text('Artisan Park'), safe);
            expect(
              tester
                  .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                    find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
                  )
                  .value
                  .statusBarIconBrightness,
              Brightness.light,
            );
          } else if (surface == 'viewer') {
            _inside(tester, find.text('Artisan Park'), safe);
          } else if (surface == 'tour widget') {
            _inside(
              tester,
              find.bySemanticsLabel('Xem tour 360° toàn màn hình'),
              safe,
            );
            _inside(tester, find.text('360°'), safe);
            final play = find.bySemanticsLabel('Xem tour 360° Artisan Park');
            _inside(tester, play, safe);
            await tester.tap(play);
            await tester.pump();
            await tester.pump();
            for (final label in [
              'Xem tour 360° toàn màn hình',
              'Đóng tour 360°',
            ]) {
              final button = find.bySemanticsLabel(label);
              await tester.ensureVisible(button);
              await tester.pump();
              _inside(tester, button, safe);
            }
          }
          if (surface != 'tour widget') {
            _inside(tester, find.byType(WebViewWidget), safe);
            expect(tester.getRect(find.byType(WebViewWidget)).left, safe.left);
            expect(
              tester.getRect(find.byType(WebViewWidget)).right,
              safe.right,
            );
            final platform = WebViewPlatform.instance! as DetailWebViewPlatform;
            platform.controllers.single.navigation!.error!(
              const WebResourceError(
                errorCode: -1,
                description: 'offline',
                isForMainFrame: true,
              ),
            );
            await tester.pump();
            for (final title in [
              'Thử lại',
              if (surface != 'viewer') 'Mở trang tour',
            ]) {
              final button = find
                  .ancestor(
                    of: find.text(title),
                    matching: find.byType(GestureDetector),
                  )
                  .first;
              await tester.ensureVisible(find.text(title));
              await tester.pump();
              _inside(tester, button, safe);
              expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
