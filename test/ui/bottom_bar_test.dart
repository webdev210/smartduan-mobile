import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartduan/ui/bottom_bar.dart';

void main() {
  testWidgets(
    'bar renders active icon pill, badge, selection semantics and action',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GuestBar(
              items: [
                BarItem(
                  key: 'home',
                  label: 'Trang chủ',
                  icon: Icons.home_outlined,
                  iconOn: Icons.home,
                  active: true,
                  onPress: () => taps++,
                ),
                BarItem(
                  key: 'notifications',
                  label: 'Thông báo',
                  icon: Icons.notifications_outlined,
                  iconOn: Icons.notifications,
                  badge: '99+',
                  onPress: () => taps++,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(
        tester.widget<TabIcon>(find.byType(TabIcon).first).focused,
        isTrue,
      );
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Trang chủ')),
        matchesSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          label: 'Trang chủ',
        ),
      );
      await tester.tap(find.text('Thông báo'));
      expect(taps, 1);
      semantics.dispose();
    },
  );
  test(
    'tab bar height includes safe area',
    () => expect(tabBarStyle(24).height, 86),
  );
}
