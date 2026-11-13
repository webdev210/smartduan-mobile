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
    final groups = [
      for (final g in top.value?.groups ?? <TopUnitGroup>[])
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
    final entries = <({TopUnitGroup group, TopUnit? unit})>[
      for (final g in groups) ...[
        (group: g.group, unit: null),
        for (final u in g.units) (group: g.group, unit: u),
      ],
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.name == null ? 'Top căn' : 'Top căn · ${widget.name}',
        ),
      ),
      body: kit.Screen(
        onRefresh: () => ref.refresh(provider.future),
        slivers: [
          if (entries.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final u = entry.unit;
                  return u == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              kit.H2(topGroupName(entry.group)),
                              kit.Muted(
                                '${entry.group.available} căn còn hàng',
                              ),
                              if (entry.group.units.isEmpty)
                                const kit.Muted('Chưa có căn phù hợp.'),
                            ],
                          ),
                        )
                      : kit.Card(
                          key: ValueKey(u.id),
                          padding: EdgeInsets.zero,
                          child: kit.ListItem(
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
                        );
                },
              ),
            ),
        ],
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
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
