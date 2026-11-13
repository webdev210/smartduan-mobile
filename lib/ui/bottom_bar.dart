import 'package:material_ui/material_ui.dart';

import 'theme.dart' as c;

class TabIcon extends StatelessWidget {
  const TabIcon({
    super.key,
    required this.name,
    required this.focused,
    required this.color,
  });
  final IconData name;
  final bool focused;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 30,
    decoration: BoxDecoration(
      color: focused ? c.brandSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
    ),
    alignment: Alignment.center,
    child: Icon(name, size: 22, color: color),
  );
}

({BoxDecoration decoration, double height, EdgeInsets padding}) tabBarStyle(
  double bottom,
) => (
  decoration: const BoxDecoration(
    color: c.card,
    boxShadow: [
      BoxShadow(
        color: Color.fromRGBO(19, 19, 19, 0.07),
        offset: Offset(0, -6),
        blurRadius: 24,
      ),
    ],
  ),
  height: 62 + bottom,
  padding: const EdgeInsets.only(top: 6),
);

class BarItem {
  const BarItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.iconOn,
    required this.onPress,
    this.active = false,
    this.badge,
    this.accessibilityLabel,
  });
  final String key, label;
  final IconData icon, iconOn;
  final VoidCallback onPress;
  final bool active;
  final String? badge, accessibilityLabel;
}

class GuestBar extends StatelessWidget {
  const GuestBar({super.key, required this.items});
  final List<BarItem> items;
  @override
  Widget build(BuildContext context) {
    final style = tabBarStyle(MediaQuery.paddingOf(context).bottom);
    return Container(
      decoration: style.decoration,
      padding: style.padding,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: item.active,
                  label: item.accessibilityLabel ?? item.label,
                  excludeSemantics: true,
                  onTap: item.onPress,
                  child: InkWell(
                    onTap: item.onPress,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 3,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              TabIcon(
                                name: item.active ? item.iconOn : item.icon,
                                focused: item.active,
                                color: item.active ? c.primary : c.subtle,
                              ),
                              if (item.badge != null)
                                Positioned(
                                  top: -3,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.brand,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item.badge!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.active ? c.primary : c.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
