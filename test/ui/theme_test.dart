import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/theme.dart';

void main() {
  test(
    'switch uses RN track colors, white thumb and no outline in every state',
    () {
      final theme = lightTheme.switchTheme;
      for (final states in <Set<WidgetState>>[
        {},
        {WidgetState.selected},
        {WidgetState.disabled},
        {WidgetState.disabled, WidgetState.selected},
        {WidgetState.hovered},
        {WidgetState.focused, WidgetState.selected},
      ]) {
        expect(
          theme.trackColor?.resolve(states),
          states.contains(WidgetState.selected) ? primary : border,
        );
        expect(theme.thumbColor?.resolve(states), Colors.white);
        expect(theme.trackOutlineColor?.resolve(states), Colors.transparent);
        expect(theme.trackOutlineWidth?.resolve(states), 0);
      }
    },
  );
  test('preserves every kit color role, shadow and the system light theme', () {
    expect(
      [
        bg,
        card,
        text,
        muted,
        subtle,
        border,
        line,
        primary,
        primaryPressed,
        brand,
        brandSoft,
        brandDeep,
        gold,
        goldSoft,
        goldDeep,
        link,
        quiet,
        danger,
        success,
        warn,
        info,
      ],
      const [
        Color(0xFFF7F7F7),
        Color(0xFFFFFFFF),
        Color(0xFF131313),
        Color(0xFF52525B),
        Color(0xFF767676),
        Color(0xFFE6E6E6),
        Color(0xFFEFEFEF),
        Color(0xFFB31E22),
        Color(0xFF8F171B),
        Color(0xFFB31E22),
        Color(0xFFF9EDED),
        Color(0xFF6E1520),
        Color(0xFFE6C28F),
        Color(0xFFFBF4E8),
        Color(0xFF7A5A1F),
        Color(0xFFB31E22),
        Color(0xFFF0F0F0),
        Color(0xFFC0262D),
        Color(0xFF187544),
        Color(0xFFA94B00),
        Color(0xFF3F3F46),
      ],
    );
    expect(cardShadow, const [
      BoxShadow(
        color: Color.fromRGBO(19, 19, 19, 0.04),
        offset: Offset(0, 1),
        blurRadius: 2,
      ),
      BoxShadow(
        color: Color.fromRGBO(19, 19, 19, 0.06),
        offset: Offset(0, 8),
        blurRadius: 24,
      ),
    ]);
    expect(floatShadow, const [
      BoxShadow(
        color: Color.fromRGBO(19, 19, 19, 0.08),
        offset: Offset(0, 4),
        blurRadius: 12,
      ),
      BoxShadow(
        color: Color.fromRGBO(19, 19, 19, 0.14),
        offset: Offset(0, 16),
        blurRadius: 40,
      ),
    ]);
    expect(brandShadow, const [
      BoxShadow(
        color: Color.fromRGBO(179, 30, 34, 0.32),
        offset: Offset(0, 8),
        blurRadius: 20,
      ),
    ]);
    expect(lightTheme.brightness, Brightness.light);
    expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF7F7F7));
    expect(lightTheme.colorScheme.primary, const Color(0xFFB31E22));
    expect(
      lightTheme.textTheme.bodyMedium?.fontFamily,
      ThemeData(brightness: Brightness.light).textTheme.bodyMedium?.fontFamily,
    );
  });
}
