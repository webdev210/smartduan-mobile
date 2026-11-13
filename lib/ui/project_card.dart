import 'dart:math' as math;

import 'network_image.dart';

import 'package:material_ui/material_ui.dart' hide Card, Divider, Row;
import 'package:material_ui/material_ui.dart' as m show Row;
import 'package:ionicons/ionicons.dart';

import 'catalog.dart';
import 'format.dart';
import 'kit.dart' show Card, Muted, Pill, Skeleton, initials, EqualHeightGrid;
import 'project_filter.dart';
import 'theme.dart';
import 'favorite_button.dart';
import 'project_compare_kit.dart';

export 'project_filter.dart' show projectStatus;

typedef ProjectCardData = Browsable;

class ProjectCardSkeleton extends StatelessWidget {
  const ProjectCardSkeleton({super.key, this.width});
  final double? width;
  @override
  Widget build(BuildContext context) {
    Widget line(TextStyle style, {int lines = 1}) => Stack(
      children: [
        Opacity(
          opacity: 0,
          child: Text(List.filled(lines, '\u00a0').join('\n'), style: style),
        ),
        const Positioned.fill(child: Skeleton(height: 0)),
      ],
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: Card(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AspectRatio(
                aspectRatio: 16 / 10,
                child: Skeleton(height: 0),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 6,
                      children: [
                        line(
                          const TextStyle(
                            fontSize: 18,
                            height: 23 / 18,
                            fontWeight: FontWeight.w700,
                          ),
                          lines: 2,
                        ),
                        line(const TextStyle(fontSize: 14)),
                        line(const TextStyle(fontSize: 14)),
                      ],
                    ),
                    m.Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: line(
                            const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(child: line(const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectMedia extends StatelessWidget {
  const ProjectMedia({
    super.key,
    required this.name,
    this.uri,
    this.status,
    this.tour = false,
    this.compact = false,
    this.actionsWidth = 0,
  });
  final String name;
  final String? uri, status;
  final bool tour, compact;
  final double actionsWidth;
  @override
  Widget build(BuildContext context) {
    final src = mediaUrl(uri), st = projectStatus[status];
    final fallback = ColoredBox(
      color: quiet,
      child: Center(
        child: Text(
          initials(name),
          style: TextStyle(
            fontSize: compact ? 20 : 34,
            fontWeight: FontWeight.w800,
            color: subtle,
            letterSpacing: 1,
          ),
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: compact ? 1 : 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          if (src != null)
            AppNetworkImage(
              src,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          if (st != null && !compact)
            Positioned(
              top: 12,
              left: 12,
              right: 12 + actionsWidth,
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Pill(
                  label: st.label,
                  color: Color(
                    int.parse(st.color.replaceFirst('#', 'ff'), radix: 16),
                  ),
                ),
              ),
            ),
          if (tour && !compact)
            Positioned(
              bottom: 12,
              right: 12,
              child: Semantics(
                label: 'Có tour 360 độ',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const m.Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(Ionicons.cubeOutline, size: 13, color: Colors.white),
                      Text(
                        '360°',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _placeOf(Browsable p) => [
  p.district,
  p.province,
].whereType<String>().where((s) => s.isNotEmpty).join(', ');
String? _publicCode(Browsable p) =>
    p.code?.isNotEmpty == true && p.isPublic != false ? p.code : null;
String _a11y(Browsable p) => [
  p.name,
  projectStatus[p.status]?.label,
  _placeOf(p),
  priceLabel(p.priceFrom),
].whereType<String>().where((s) => s.isNotEmpty).join(', ');
Widget _line(IconData icon, String value, [Color color = muted]) => m.Row(
  spacing: 6,
  children: [
    Icon(icon, size: 15, color: color),
    Expanded(
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, color: color),
      ),
    ),
  ],
);

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.p,
    required this.onPress,
    this.width,
    this.action,
  });
  final Widget? action;
  final Browsable p;
  final VoidCallback onPress;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final code = _publicCode(p);
    final place = _placeOf(p).isNotEmpty ? _placeOf(p) : p.address;
    final developer = developerOf(p);
    final activity = p.inventoryUpdatedAt != null
        ? _line(
            Ionicons.timeOutline,
            'Bảng hàng cập nhật ${fmtDate(p.inventoryUpdatedAt, true)}',
          )
        : p.activity7d != 0
        ? _line(
            Ionicons.flameOutline,
            '${p.activity7d} giao dịch trong 7 ngày qua',
            brand,
          )
        : null;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          p.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            height: 23 / 18,
            fontWeight: FontWeight.w700,
            color: text,
            letterSpacing: -0.3,
          ),
        ),
        if (place != null && place.isNotEmpty)
          _line(Ionicons.locationOutline, place),
        if (developer != null && developer.isNotEmpty)
          _line(Ionicons.businessOutline, developer),
        ?activity,
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          heading,
          LayoutBuilder(
            builder: (context, constraints) {
              final price = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (priceLabel(p.priceFrom) != 'Liên hệ')
                    const Muted('Giá từ', style: TextStyle(fontSize: 12)),
                  Text(
                    priceLabel(p.priceFrom).replaceFirst('Giá từ ', ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: brand,
                    ),
                  ),
                ],
              );
              final type = Text(
                typeLabel[p.projectType] ?? p.projectType ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: muted),
              );
              if (constraints.maxWidth + 32 < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) >= 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [price, type],
                );
              }
              return m.Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 12,
                children: [
                  Expanded(child: price),
                  Flexible(child: type),
                ],
              );
            },
          ),
        ],
      ),
    );
    final content = Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => _ProjectHit(
            label: _a11y(p),
            onPress: onPress,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProjectMedia(
                  name: p.name,
                  uri: p.coverUrl,
                  status: p.status,
                  tour: p.hasTour360,
                  actionsWidth: code == null ? 0 : 112,
                ),
                if (constraints.hasBoundedHeight)
                  Expanded(child: body)
                else
                  body,
              ],
            ),
          ),
        ),
        if (code != null)
          Positioned(
            top: 12,
            right: 12,
            child: m.Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                CompareChip(code: code, name: p.name, overlay: true),
                IconButtonTheme(
                  data: IconButtonThemeData(
                    style: IconButton.styleFrom(
                      fixedSize: const Size(44, 44),
                      minimumSize: const Size(44, 44),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: const CircleBorder(),
                    ),
                  ),
                  child: FavoriteButton(
                    code: code,
                    name: p.name,
                    overlay: true,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return SizedBox(
      width: width,
      child: Card(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: action == null
              ? content
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    content,
                    if (action != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: action,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class ProjectRow extends StatelessWidget {
  const ProjectRow({
    super.key,
    required this.p,
    required this.onPress,
    this.action,
  });
  final Widget? action;
  final Browsable p;
  final VoidCallback onPress;
  @override
  Widget build(BuildContext context) {
    final code = _publicCode(p);
    final st = projectStatus[p.status];
    final place = [
      _placeOf(p),
      developerOf(p),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Card(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          m.Row(
            spacing: 10,
            children: [
              Expanded(
                child: _ProjectHit(
                  label: _a11y(p),
                  onPress: onPress,
                  child: m.Row(
                    spacing: 14,
                    children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ProjectMedia(
                            compact: true,
                            name: p.name,
                            uri: p.coverUrl,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 4,
                          children: [
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                            ),
                            if (place.isNotEmpty)
                              Muted(
                                place,
                                style: const TextStyle(fontSize: 13),
                                numberOfLines: 1,
                              ),
                            m.Row(
                              spacing: 8,
                              children: [
                                Expanded(
                                  child: Text(
                                    priceLabel(p.priceFrom),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: brand,
                                    ),
                                  ),
                                ),
                                if (st != null)
                                  Flexible(
                                    child: Text(
                                      st.label,
                                      style: TextStyle(
                                        color: Color(
                                          int.parse(
                                            st.color.replaceFirst('#', 'ff'),
                                            radix: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (code != null) FavoriteButton(code: code, name: p.name),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}

// Keep the open action and the favourite/compare actions as semantic siblings.
class _ProjectHit extends StatelessWidget {
  const _ProjectHit({
    required this.label,
    required this.onPress,
    required this.child,
  });
  final String label;
  final VoidCallback onPress;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onPress,
    excludeSemantics: true,
    child: InkWell(onTap: onPress, child: child),
  );
}

// Keep project rails on the same measured-height layout as quick-access tiles.
class ProjectRailRow extends StatelessWidget {
  const ProjectRailRow({
    super.key,
    required this.cardWidth,
    required this.children,
  });
  final double cardWidth;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => EqualHeightGrid(
    cellWidth: cardWidth,
    columns: math.max(1, children.length),
    spacing: 12,
    children: children,
  );
}
