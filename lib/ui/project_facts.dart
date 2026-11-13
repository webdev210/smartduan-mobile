import 'package:material_ui/material_ui.dart';

import 'kit.dart' as kit;
import 'theme.dart' as c;

/// Compact project definitions; cells grow with their content.
class ProjectFacts extends StatelessWidget {
  const ProjectFacts({
    super.key,
    required this.entries,
    this.valueWidgets = const {},
  });
  final List<(String, String)> entries;
  final Map<String, Widget> valueWidgets;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 340 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3
          ? 2
          : 1;
      return kit.Card(
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i += columns) ...[
              if (i > 0) const Divider(height: 1, thickness: 0, color: c.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    for (final (label, value) in entries.skip(i).take(columns))
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: c.muted,
                                fontSize: 13,
                              ),
                            ),
                            valueWidgets[label] ??
                                Text(
                                  value,
                                  style: const TextStyle(
                                    color: c.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
