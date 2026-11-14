import 'package:material_ui/material_ui.dart';
import 'package:ionicons/ionicons.dart';

import '../api/public.dart';
import 'kit.dart' show Empty, Section, Segmented;
import 'project_card.dart';
import 'regions.dart';

String firstProjectRegion(List<PublicProject> projects) => regions
    .firstWhere(
      (r) => projects.any((p) => inRegion(p.province, r.key)),
      orElse: () => regions.first,
    )
    .key;

class ProjectRegionSection extends StatelessWidget {
  const ProjectRegionSection({
    super.key,
    required this.projects,
    required this.region,
    required this.onRegionChanged,
    required this.onOpen,
    required this.cardWidth,
    required this.loading,
    this.limit,
    this.inset = 20,
  });

  final List<PublicProject> projects;
  final String region;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<PublicProject> onOpen;
  final double cardWidth, inset;
  final bool loading;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final matching = projects.where((p) => inRegion(p.province, region));
    return Column(
      spacing: 12,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Section(
            title: 'Dự án theo khu vực',
            child: Segmented(
              value: region,
              onChange: onRegionChanged,
              options: [
                for (final r in regions)
                  (key: r.key, label: r.label, count: null),
              ],
            ),
          ),
        ),
        ProjectRail(
          items: (limit == null ? matching : matching.take(limit!)).toList(),
          cardWidth: cardWidth,
          loading: loading,
          empty: 'Chưa có dự án tại khu vực này.',
          onOpen: onOpen,
          inset: inset,
        ),
      ],
    );
  }
}

class ProjectRail extends StatelessWidget {
  const ProjectRail({
    super.key,
    required this.items,
    required this.cardWidth,
    required this.loading,
    required this.empty,
    required this.onOpen,
    this.inset = 20,
  });

  final List<PublicProject> items;
  final double cardWidth, inset;
  final bool loading;
  final String empty;
  final ValueChanged<PublicProject> onOpen;

  @override
  Widget build(BuildContext context) {
    if (!loading && items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Empty(icon: Ionicons.businessOutline, text: empty),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
      child: ProjectRailRow(
        cardWidth: cardWidth,
        children: loading
            ? [
                for (var i = 0; i < 2; i++)
                  ProjectCardSkeleton(width: cardWidth),
              ]
            : [
                for (final p in items)
                  ProjectCard(
                    key: ValueKey(p.id),
                    width: cardWidth,
                    p: p,
                    onPress: () => onOpen(p),
                  ),
              ],
      ),
    );
  }
}
