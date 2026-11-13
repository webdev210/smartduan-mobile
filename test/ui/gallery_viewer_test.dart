import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/gallery_viewer.dart';
import 'package:smartduan/ui/network_image.dart';
import 'package:smartduan/ui/post_body.dart';

import '../support/responsive.dart';

const images = <GalleryImage>[
  (url: 'https://smartduan.vn/one.jpg', caption: 'Mặt tiền'),
  (url: 'https://smartduan.vn/two.jpg', caption: 'Phòng khách'),
  (url: 'https://smartduan.vn/three.jpg', caption: null),
];

Future<void> mount(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openGallery(context, images, initialIndex: 1),
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('article images share one gallery at the tapped index', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PostBody(
            html: '<img src="https://smartduan.vn/1.jpg"><img src="https://smartduan.vn/2.jpg">',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(AppNetworkImage).last);
    await t.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets(
    'pinch zoom locks paging and reduced motion removes route fade time',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openGallery(context, images),
                  child: const Text('Mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Mở'));
      await t.pumpAndSettle();
      final route = ModalRoute.of(t.element(find.byType(GalleryViewer)))!;
      expect(route.transitionDuration, Duration.zero);
      final center = t.getCenter(find.byType(InteractiveViewer).first);
      final first = await t.startGesture(
        center - const Offset(30, 0),
        pointer: 1,
      );
      final second = await t.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      await t.pump();
      await first.moveBy(const Offset(-50, 0));
      await second.moveBy(const Offset(50, 0));
      await t.pump();
      await first.up();
      await second.up();
      await t.pumpAndSettle();
      expect(
        t.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
    },
  );

  testWidgets('image loading placeholder is visible and centered', (t) async {
    await mount(t);
    final image = t.widget<AppNetworkImage>(find.byType(AppNetworkImage).first);
    final placeholder = image.loadingBuilder!(
      t.element(find.byType(AppNetworkImage).first),
      const SizedBox(),
      const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 10),
    );
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(MaterialApp(home: Scaffold(body: placeholder)));
    expect(find.text('Đang tải ảnh…'), findsOneWidget);
    expect(find.byType(Center), findsOneWidget);
  });
  testWidgets('opens tapped image, swipes, announces index and closes', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await mount(t);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Phòng khách'), findsOneWidget);
    expect(find.bySemanticsLabel('Ảnh 2 trên 3'), findsOneWidget);
    expect(
      t.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
      Colors.black,
    );
    expect(
      t.widget<AppNetworkImage>(find.byType(AppNetworkImage).first).fit,
      BoxFit.contain,
    );
    await t.drag(find.byType(PageView), const Offset(-700, 0));
    await t.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await t.tap(find.byTooltip('Đóng'));
    await t.pumpAndSettle();
    expect(find.byType(GalleryViewer), findsNothing);
    semantics.dispose();
  });

  testWidgets('double tap zoom disables swipe until reset; back closes', (
    t,
  ) async {
    await mount(t);
    final point = t.getCenter(find.byType(InteractiveViewer).first);
    await t.tapAt(point);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(point);
    await t.pumpAndSettle();
    expect(
      t.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    await t.drag(find.byType(PageView), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await t.tapAt(point);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(point);
    await t.pumpAndSettle();
    expect(t.widget<PageView>(find.byType(PageView)).physics, isNull);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(GalleryViewer), findsNothing);
  });

  testWidgets('gallery error and retry remain responsive', (t) async {
    await expectResponsive(t, () async {
      await mount(t);
      expect(find.text('Không tải được ảnh.'), findsWidgets);
      await t.tap(find.text('Thử lại').first);
      await t.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    });
  });
}
