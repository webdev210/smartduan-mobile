import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/screens/app/presentation.dart';
import 'package:smartduan/screens/app/profile.dart';
import 'package:smartduan/screens/app/search_units.dart';
import 'package:smartduan/screens/app/share_links.dart';
import 'package:smartduan/screens/app/unit.dart';
import 'package:smartduan/ui/kit.dart' as kit;

import '../../support/responsive.dart';
import 'm5d_r4_responsive_test.dart';
import 'task_h_fakes.dart';

Future<void> pressR4(WidgetTester t, String title) async {
  final button = find.text(title);
  if (button.evaluate().isEmpty) {
    await t.scrollUntilVisible(button, 200, scrollable: verticalR4.first);
  }
  await t.ensureVisible(button);
  await t.pumpAndSettle();
  await t.tap(button);
  await t.pumpAndSettle();
}

void main() {
  final overlays = <(String, Widget, Future<void> Function(WidgetTester))>[
    (
      'presentation readable list',
      const PresentationScreen(projectId: 'p'),
      (t) async {
        await pressR4(t, 'Danh sách giá');
        await scrollR4(t);
      },
    ),
    (
      'search keyboard',
      const SearchUnitsScreen(),
      (t) async {
        t.widget<kit.SearchBar>(find.byType(kit.SearchBar)).onFilter!();
        await t.pumpAndSettle();
        t.view.viewInsets = const FakeViewPadding(bottom: 200);
        await t.pumpAndSettle();
        final input = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is kit.Field && w.label == 'Giá tối đa (tỷ đồng)',
          ),
          matching: find.byType(TextField),
        );
        await t.ensureVisible(input);
        await t.pumpAndSettle();
        await t.showKeyboard(input);
        await t.ensureVisible(input);
        await t.pumpAndSettle();
        expect(
          t.getBottomRight(input).dy,
          lessThanOrEqualTo(t.view.physicalSize.height - 200),
        );
        await pressR4(t, 'Xem kết quả');
        expect(find.text('Lọc & sắp xếp'), findsNothing);
      },
    ),
    (
      'search filters',
      const SearchUnitsScreen(),
      (t) async {
        t.widget<kit.SearchBar>(find.byType(kit.SearchBar)).onFilter!();
        await t.pumpAndSettle();
        await t.ensureVisible(
          find.byWidgetPredicate((w) => w is kit.Section && w.title == 'Hướng'),
        );
      },
    ),
    (
      'save filter',
      const SearchUnitsScreen(),
      (t) => pressR4(t, 'Lưu bộ lọc này'),
    ),
    (
      'remove filter',
      const SearchUnitsScreen(),
      (t) async {
        await pressR4(t, 'Lưu bộ lọc này');
        await pressR4(t, 'Xoá');
      },
    ),
    ('remove device', const ProfileScreen(), (t) => pressR4(t, 'Gỡ')),
    (
      'sign out devices',
      const ProfileScreen(),
      (t) => pressR4(t, 'Đăng xuất mọi thiết bị'),
    ),
    (
      'revoke share',
      const ShareLinksScreen(projectId: 'p'),
      (t) => pressR4(t, 'Thu hồi'),
    ),
    (
      'presentation detail',
      const PresentationScreen(projectId: 'p'),
      (t) => pressR4(t, 'A101'),
    ),
    (
      'presentation exit',
      const PresentationScreen(projectId: 'p'),
      (t) async {
        await t.tap(find.byTooltip('Kết thúc trình chiếu'));
        await t.pumpAndSettle();
      },
    ),
    (
      'unit policies',
      const UnitScreen(id: 'u'),
      (t) => pressR4(t, 'Chính sách dự án'),
    ),
  ];
  for (final (name, screen, open) in overlays) {
    testWidgets('$name responsive matrix', (t) async {
      await expectResponsive(t, () async {
        final e = HEnv(roles: ['manager']);
        e.http.respond = (r) => r.path == '/sales/units/search/saved'
            ? const Reply(200, {
                'data': [
                  {
                    'id': 's',
                    'name': longName,
                    'params': {'status': 'available'},
                  },
                ],
              })
            : r4Reply(r.path);
        final router = await mountR4(t, e, screen);
        await open(t);
        await t.pumpWidget(const SizedBox());
        router.dispose();
        e.container.dispose();
        t.view.resetViewInsets();
        await t.pump();
      });
    });
  }
}
