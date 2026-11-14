import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/ui/brand_splash.dart';
import 'package:smartduan/ui/theme.dart' as c;

Future<void> mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
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
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  // Same screen as RN main (aa6bc54): Smartland city photo, logo and app name only.
  testWidgets('chỉ có logo và tên app trên ảnh nền thành phố', (tester) async {
    await mount(tester);
    expect(find.bySemanticsLabel('Đang mở Smart Dự Án'), findsOneWidget);
    expect(find.text('Smart Dự Án'), findsOneWidget);
    expect(find.text('SMARTLAND'), findsNothing);
    expect(find.textContaining('Bảng hàng'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final photo = tester.widget<Image>(
      find.image(const AssetImage('assets/splash-bg.jpg')),
    );
    expect(photo.fit, BoxFit.cover);
    // Bottom-anchored: the red/gold wave and skyline stay whole, only sky is cropped.
    expect(photo.alignment, Alignment.bottomCenter);

    final logo = tester.widget<Image>(
      find.image(const AssetImage('assets/smartland-mark.png')),
    );
    expect(logo.color, isNull, reason: 'logo đỏ giữ nguyên màu');
    expect(logo.width, 96);

    final title = tester.widget<Text>(find.text('Smart Dự Án'));
    expect(title.style!.color, c.brandDeep);
    expect(title.style!.fontSize, 36);
    expect(title.style!.fontWeight, FontWeight.w800);
  });

  testWidgets('nền trắng, chữ thanh trạng thái tối', (tester) async {
    await mount(tester);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
    );
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    final material = tester.widget<Material>(
      find
          .ancestor(
            of: find.image(const AssetImage('assets/splash-bg.jpg')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, Colors.white);
  });

  testWidgets('logo và tên nằm ở khoảng trời, khoảng 26% chiều cao', (
    tester,
  ) async {
    await mount(tester);
    final top = tester.getTopLeft(
      find.image(const AssetImage('assets/smartland-mark.png')),
    );
    expect(top.dy, closeTo(844 * .26, 1));
  });

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(844, 390), 1.3),
  ]) {
    testWidgets('không lỗi layout ở $size, chữ x$scale', (tester) async {
      await mount(tester, size: size, scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('Smart Dự Án'), findsOneWidget);
    });
  }
}
