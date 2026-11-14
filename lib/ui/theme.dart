import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

// Color roles from C in legacy-rn/src/ui/kit.tsx.
const bg = Color(0xFFF7F7F7);
const card = Color(0xFFFFFFFF);
const text = Color(0xFF131313);
const muted = Color(0xFF52525B);
const subtle = Color(0xFF767676);
const border = Color(0xFFE6E6E6);
const line = Color(0xFFEFEFEF);
const primary = Color(0xFFB31E22);
const primaryPressed = Color(0xFF8F171B);
const brand = Color(0xFFB31E22);
const brandSoft = Color(0xFFF9EDED);
const brandDeep = Color(0xFF6E1520);
const gold = Color(0xFFE6C28F);
const goldSoft = Color(0xFFFBF4E8);
const goldDeep = Color(0xFF7A5A1F);
const link = Color(0xFFB31E22);
const quiet = Color(0xFFF0F0F0);
const danger = Color(0xFFC0262D);
const success = Color(0xFF187544);
const warn = Color(0xFFA94B00);
const info = Color(0xFF3F3F46);
const dangerSoft = Color(0xFFFBECEB);
const dangerBorder = Color(0xFFF0C9C7);
const successSoft = Color(0xFFE8F4ED);
const warnSoft = Color(0xFFFBF0E4);
const infoSoft = Color(0xFFF2F2F3);
const brandBorder = Color(0xFFF0D4D5);
const onBrandMuted = Color(0xFFF1DCDC);
const onImageMuted = Color(0xFFF0F0F2);

// Hidden inventory keeps its RN background; its text needs a dark foreground.
Color solidForeground(Color background) =>
    background == const Color(0xFF9CA3AF) ? text : card;

// GRADIENT in the RN kit (CSS angles mapped to Flutter alignments).
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFCF2A2F), primary, primaryPressed],
  stops: [0, 0.5, 1],
);
const wineGradient = LinearGradient(
  begin: Alignment(-0.7, -1),
  end: Alignment(0.7, 1),
  colors: [Color(0xFF8F1C25), brandDeep, Color(0xFF45101A)],
  stops: [0, 0.52, 1],
);
const goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF3DCB6), gold],
);

// HEADER from legacy-rn/src/ui/nav.ts.
const headerTheme = AppBarThemeData(
  systemOverlayStyle: SystemUiOverlayStyle.dark,
  backgroundColor: card,
  foregroundColor: brand,
  elevation: 0,
  scrolledUnderElevation: 0,
  shadowColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  titleTextStyle: TextStyle(
    color: text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  ),
);

// SHADOW entries, suffixed to distinguish them from the color roles.
const List<BoxShadow> cardShadow = [
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
];
const List<BoxShadow> floatShadow = [
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
];
const List<BoxShadow> brandShadow = [
  BoxShadow(
    color: Color.fromRGBO(179, 30, 34, 0.32),
    offset: Offset(0, 8),
    blurRadius: 20,
  ),
];

final lightTheme = ThemeData(
  appBarTheme: headerTheme,
  switchTheme: SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? primary : border,
    ),
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    trackOutlineWidth: const WidgetStatePropertyAll(0),
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: bg,
  colorScheme: const ColorScheme.light(
    primary: primary,
    onPrimary: card,
    surface: card,
    onSurface: text,
    error: danger,
    onError: card,
  ),
);
