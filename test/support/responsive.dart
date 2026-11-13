import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Device matrix for the M5d responsive pass: logical size, safe-area padding.
/// Phones small to large (Android + iOS), foldable/tablet, landscape.
const responsiveDevices = <(String, Size, EdgeInsets)>[
  ('iPhone SE 1st 320x568', Size(320, 568), EdgeInsets.only(top: 20)),
  ('Android small 360x640', Size(360, 640), EdgeInsets.only(top: 24)),
  (
    'Android tall 360x800',
    Size(360, 800),
    EdgeInsets.only(top: 32, bottom: 24),
  ),
  ('iPhone 15 393x852', Size(393, 852), EdgeInsets.only(top: 59, bottom: 34)),
  ('Pixel 8 412x915', Size(412, 915), EdgeInsets.only(top: 48, bottom: 24)),
  (
    'iPhone 15 Pro Max 430x932',
    Size(430, 932),
    EdgeInsets.only(top: 59, bottom: 34),
  ),
  ('Fold open 600x960', Size(600, 960), EdgeInsets.only(top: 24)),
  ('iPad 768x1024', Size(768, 1024), EdgeInsets.only(top: 24, bottom: 20)),
  (
    'iPhone landscape 852x393',
    Size(852, 393),
    EdgeInsets.only(left: 59, right: 59, bottom: 21),
  ),
  ('Android landscape 915x412', Size(915, 412), EdgeInsets.only(left: 48)),
];
const responsiveTextScales = <double>[1.0, 1.3, 2.0];

/// Pumps [mount] on every device × text scale and fails on any layout
/// exception (overflow, unbounded constraints, …). [mount] must pump the
/// screen itself (provider overrides, router, settle) and may scroll.
Future<void> expectResponsive(
  WidgetTester tester,
  Future<void> Function() mount, {
  List<double> textScales = responsiveTextScales,
}) async {
  final failures = <String>[];
  for (final (name, size, padding) in responsiveDevices) {
    for (final scale in textScales) {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size
        ..padding = FakeViewPadding(
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        );
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await mount();
      Object? error;
      while ((error = tester.takeException()) != null) {
        failures.add('$name @${scale}x: ${'$error'.split('\n').first}');
      }
      await tester.pumpWidget(const SizedBox());
    }
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  expect(failures, isEmpty, reason: failures.join('\n'));
}
