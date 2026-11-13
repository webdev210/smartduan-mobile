import 'package:ionicons/ionicons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/projects.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/search.dart';

const topModes = [
  (key: 'cheap', label: 'Giá tốt', count: null),
  (key: 'nice', label: 'Căn đẹp', count: null),
  (key: 'corner', label: 'Căn góc', count: null),
  (key: 'manual', label: 'Sàn chọn', count: null),
];
String topGroupName(TopUnitGroup g) => [
  g.unitType ?? 'Khác',
  if (g.bedrooms != null) '${g.bedrooms}PN',
].join(' · ');

class TopUnitsScreen extends ConsumerStatefulWidget {
  const TopUnitsScreen({super.key, required this.projectId, this.name});
  final String projectId;
  final String? name;
  @override
  ConsumerState<TopUnitsScreen> createState() => _TopUnitsScreenState();
}

class _TopUnitsScreenState extends ConsumerState<TopUnitsScreen> {
  String mode = 'cheap', q = '';
  String? only;
  @override
  Widget build(BuildContext context) {
    final provider = fetchTopUnitsProvider((
      projectId: widget.projectId,
      params: ApiParams({'mode': mode}),
    ));
    final top = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.name == null ? 'Top căn' : 'Top căn · ${widget.name}',
        ),
      ),
      body: kit.Screen(
        onRefresh: () => ref.refresh(provider.future),
        children: [
          kit.Segmented(
            value: mode,
            options: topModes,
            onChange: (s) => setState(() => mode = s),
          ),
          kit.SearchBar(
            value: q,
            onChangeText: (s) => setState(() => q = s),
            placeholder: 'Tìm mã căn, toà, tầng…',
            autoCapitalize: TextCapitalization.characters,
          ),
          kit.AsyncView(
            value: top,
            onRetry: () => ref.invalidate(provider),
            builder: (data) {
              if (data.groups.isEmpty) {
                return kit.Empty(
                  icon: Ionicons.trophyOutline,
                  text: mode == 'manual'
                      ? 'Sàn chưa chọn căn nổi bật cho dự án này.'
                      : 'Dự án chưa có căn còn hàng.',
                );
              }
              final groups = [
                for (final g in data.groups)
                  if (only == null || topGroupName(g) == only)
                    (
                      group: g,
                      units: smartFilter(
                        g.units,
                        q,
                        (u) => [
                          u.publicCode ?? u.code,
                          u.code,
                          u.blockName,
                          if (u.floor != null) 'Tầng ${u.floor}',
                          u.why.where((s) => s.isNotEmpty).join(' · '),
                        ],
                      ),
                    ),
              ].where((g) => q.trim().isEmpty || g.units.isNotEmpty).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (data.groups.length > 1)
                    kit.ChipRail(
                      children: [
                        kit.Chip(
                          label: 'Tất cả loại',
                          active: only == null,
                          onPress: () => setState(() => only = null),
                        ),
                        for (final g in data.groups)
                          kit.Chip(
                            label: '${topGroupName(g)} · ${g.available}',
                            active: only == topGroupName(g),
                            onPress: () => setState(
                              () => only = only == topGroupName(g)
                                  ? null
                                  : topGroupName(g),
                            ),
                          ),
                      ],
                    ),
                  if (groups.isEmpty)
                    kit.Empty(
                      icon: Ionicons.searchOutline,
                      text: 'Không có căn nào khớp.',
                      action: (
                        label: 'Xoá tìm kiếm & bộ lọc',
                        onPress: () => setState(() {
                          q = '';
                          only = null;
                        }),
                      ),
                    ),
                  for (final g in groups)
                    kit.Section(
                      title: topGroupName(g.group),
                      eyebrow: '${g.group.available} căn còn hàng',
                      child: kit.Card(
                        children: [
                          if (g.units.isEmpty)
                            const kit.Muted('Chưa có căn phù hợp.'),
                          for (final u in g.units)
                            kit.ListItem(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              title:
                                  '${u.publicCode ?? u.code} · ${u.priceMinLabel ?? fmtPrice(u.priceMin)}',
                              subtitle:
                                  [
                                        u.blockName,
                                        if (u.floor != null) 'Tầng ${u.floor}',
                                        if (u.area != null && u.area != '')
                                          fmtArea(u.area),
                                        ...u.why,
                                      ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                              onPress: () => context.push(
                                '/can/${Uri.encodeComponent(u.id)}',
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
