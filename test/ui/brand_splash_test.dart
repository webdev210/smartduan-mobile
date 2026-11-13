import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/ui/brand_splash.dart';
import 'package:smartduan/ui/theme.dart' as c;

Future<void> mount(
  WidgetTester tester,
  double width, {
  double height = 844,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: c.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 24, bottom: 20),
        ),
        child: child!,
      ),
      // Like the router's loading gate: no Scaffold around the splash.
      home: const BrandSplash(),
    ),
  );
  // Start Appear's zero-delay timer and its first ticker frame, then settle.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

RenderParagraph paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );

LinearGradient scrimOf(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((box) => box.gradient)
    .whereType<LinearGradient>()
    .single;

Color overlayAt(LinearGradient scrim, double position) {
  final stops = scrim.stops!;
  for (var i = 1; i < stops.length; i++) {
    if (position <= stops[i]) {
      return Color.lerp(
        scrim.colors[i - 1],
        scrim.colors[i],
        (position - stops[i - 1]) / (stops[i] - stops[i - 1]),
      )!;
    }
  }
  return scrim.colors.last;
}

void main() {
  setUpAll(() async {
    // Use the SDK's phone font so wrapping is measured with real glyph widths.
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final font = File('${artifacts.path}/material_fonts/roboto-regular.ttf');
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
  });
  testWidgets('standalone splash resolves all text to the theme font', (
    tester,
  ) async {
    await mount(tester, 360);
    final title = find.text('Smart Dự Án');
    expect(
      find.ancestor(of: title, matching: find.byType(Scaffold)),
      findsNothing,
    );
    final family = Theme.of(tester.element(title))
        .textTheme
        .bodyMedium!
        .fontFamily;
    expect(family, isNotNull);
    for (final text in find.byType(Text).evaluate()) {
      final style = paragraph(tester, find.byWidget(text.widget)).text.style!;
      expect(style.fontFamily, family);
    }
    final titleStyle = paragraph(tester, title).text.style!;
    expect(titleStyle.fontSize, 32);
    expect(titleStyle.fontWeight, FontWeight.w600);
    expect(titleStyle.letterSpacing, -.5);
    final brandStyle = paragraph(tester, find.text('SMARTLAND')).text.style!;
    expect(brandStyle.fontSize, 11);
    expect(brandStyle.fontWeight, FontWeight.w600);
    expect(brandStyle.letterSpacing, 4);
  });

  for (final width in [360.0, 412.0]) {
    testWidgets('tagline has no single-word last line at $width dp', (
      tester,
    ) async {
      await mount(tester, width);
      final tagline = find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Bảng hàng') ?? false),
      );
      final rendered = paragraph(tester, tagline);
      final text = rendered.text.toPlainText();
      expect(
        text.replaceAll('\u00a0', ' '),
        'Bảng hàng & dự án bất động sản trong tay bạn',
      );
      final lastWords = rendered.getBoxesForSelection(
        TextSelection(
          baseOffset: text.lastIndexOf('tay'),
          extentOffset: text.length,
        ),
      );
      expect(lastWords, isNotEmpty);
      expect(lastWords.map((box) => box.top).toSet(), hasLength(1));
      expect(rendered.text.style!.fontSize, 15);
      expect(rendered.text.style!.fontWeight, FontWeight.w400);
      expect(rendered.textAlign, TextAlign.center);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('splash fills the screen with the project photo', (tester) async {
    await mount(tester, 360);
    final photo = find.image(const AssetImage('assets/splash.webp'));
    expect(photo, findsOneWidget);
    final image = tester.widget<Image>(photo);
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
    expect(tester.getSize(photo), const Size(360, 844));
    expect(
      tester.widget<Material>(find.byType(Material).first).color,
      const Color(0xff0a0f1c),
    );
    final mark = tester.widget<Image>(
      find.image(const AssetImage('assets/smartland-mark.png')),
    );
    expect(mark.color, c.gold);
  });

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(1024, 768), 1.0),
    (const Size(1024, 768), 2.0),
    (const Size(568, 320), 2.0),
  ]) {
    testWidgets('splash fits $size at text scale $scale', (tester) async {
      await mount(tester, size.width, height: size.height, scale: scale);
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Smart Dự Án'));
      final tagline = tester.getRect(
        find.text('Bảng hàng & dự án bất động sản trong tay\u00a0bạn'),
      );
      final footer = tester.getRect(find.text('SMARTLAND'));
      expect(title.top, greaterThanOrEqualTo(24));
      expect(tagline.top, greaterThanOrEqualTo(title.bottom));
      expect(footer.top, greaterThan(tagline.bottom));
      if (size.height < 400) {
        // Short landscape windows can scroll without shrinking accessible text.
        await tester.ensureVisible(find.text('SMARTLAND'));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(
        tester.getBottomLeft(find.text('SMARTLAND')).dy,
        lessThanOrEqualTo(size.height - 20),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.image(const AssetImage('assets/splash.webp')),
        findsOneWidget,
      );
    });
  }

  testWidgets('photo fades only after decode including cached frames', (
    tester,
  ) async {
    await mount(tester, 360);
    final photo = tester.widget<Image>(
      find.image(const AssetImage('assets/splash.webp')),
    );
    final context = tester.element(find.byType(BrandSplash));
    final waiting = photo.frameBuilder!(
      context,
      const SizedBox(),
      null,
      false,
    ) as TweenAnimationBuilder<double>;
    final decoded = photo.frameBuilder!(
      context,
      const SizedBox(),
      0,
      false,
    ) as TweenAnimationBuilder<double>;
    final cached = photo.frameBuilder!(
      context,
      const SizedBox(),
      0,
      true,
    ) as TweenAnimationBuilder<double>;
    expect(waiting.tween.end, 0);
    expect(decoded.tween.begin, 0);
    expect(decoded.tween.end, 1);
    expect(cached.tween.begin, 0);
    expect(cached.tween.end, 1);
    expect(decoded.duration, const Duration(milliseconds: 260));
    await tester.runAsync(() => precacheImage(photo.image, context));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final raw = tester.widget<RawImage>(
      find.descendant(
        of: find.image(const AssetImage('assets/splash.webp')),
        matching: find.byType(RawImage),
      ),
    );
    expect(raw.image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrim leaves the tower band clear and darkens text regions', (
    tester,
  ) async {
    await mount(tester, 360);
    final scrim = scrimOf(tester);
    for (var percent = 45; percent <= 75; percent++) {
      expect(overlayAt(scrim, percent / 100).a, lessThanOrEqualTo(.15));
    }
    for (final (position, opacity) in [
      (0.0, .85),
      (.3, .55),
      (.5, .12),
      (1.0, .88),
    ]) {
      expect(overlayAt(scrim, position).a, closeTo(opacity, .01));
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 844),
    const Size(1080 / 2.625, 2400 / 2.625),
  ]) {
    testWidgets('brand sits in the upper sky on $size phones', (tester) async {
      await mount(tester, size.width, height: size.height);
      final mark = tester.getRect(
        find.image(const AssetImage('assets/smartland-mark.png')),
      );
      final tagline = tester.getRect(
        find.text('Bảng hàng & dự án bất động sản trong tay\u00a0bạn'),
      );
      final centre = (mark.top + tagline.bottom) / 2 / size.height;
      expect(centre, inInclusiveRange(.17, .20));
      expect(mark.top, greaterThanOrEqualTo(24));
      expect(
        tester.getRect(find.text('SMARTLAND')).top / size.height,
        greaterThan(.85),
      );
      expect(
        tester.getRect(find.byType(CircularProgressIndicator)).top /
            size.height,
        greaterThan(.8),
      );
    });
  }

  testWidgets('title and tagline have soft navy shadows', (tester) async {
    await mount(tester, 360);
    for (final label in [
      'Smart Dự Án',
      'Bảng hàng & dự án bất động sản trong tay\u00a0bạn',
    ]) {
      final shadows = paragraph(tester, find.text(label)).text.style!.shadows;
      expect(shadows, isNotEmpty);
      expect(shadows!.first.blurRadius, 12);
      expect(shadows.first.color, const Color(0x990a0f1c));
    }
  });

  for (final size in [
    const Size(1080 / 2.625, 2400 / 2.625),
    const Size(1024, 768),
  ]) {
    testWidgets('text meets AA over the actual photo regions at $size', (
      tester,
    ) async {
      await mount(tester, size.width, height: size.height);
      final image = await tester.runAsync(() async {
        final data = await rootBundle.load('assets/splash.webp');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      });
      final pixels = (await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final fitted = applyBoxFit(
        BoxFit.cover,
        Size(image!.width.toDouble(), image.height.toDouble()),
        size,
      );
      final source = Alignment.center.inscribe(
        fitted.source,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      );
      final scrim = scrimOf(tester);
      for (final label in [
        'Smart Dự Án',
        'Bảng hàng & dự án bất động sản trong tay\u00a0bạn',
        'SMARTLAND',
      ]) {
        final rect = tester.getRect(find.text(label));
        var lowestContrast = double.infinity;
        for (var y = rect.top.ceil(); y < rect.bottom; y++) {
          final overlay = overlayAt(scrim, y / size.height);
          for (var x = rect.left.ceil(); x < rect.right; x++) {
            final sourceX = (source.left + x / size.width * source.width)
                .floor();
            final sourceY = (source.top + y / size.height * source.height)
                .floor();
            final offset = (sourceY * image.width + sourceX) * 4;
            final background = Color.alphaBlend(
              overlay,
              Color.fromARGB(
                255,
                pixels.getUint8(offset),
                pixels.getUint8(offset + 1),
                pixels.getUint8(offset + 2),
              ),
            );
            final contrast = 1.05 / (background.computeLuminance() + .05);
            if (contrast < lowestContrast) lowestContrast = contrast;
          }
        }
        expect(lowestContrast, greaterThanOrEqualTo(4.5), reason: label);
      }
      image.dispose();
    });
  }
}
