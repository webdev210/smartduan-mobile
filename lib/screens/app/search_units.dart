import 'package:ionicons/ionicons.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart'
    hide Card, Chip, Divider, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/sales.dart';
import '../../api/units.dart' show fetchEnumsProvider;
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/theme.dart' as c;

const searchDebounce = Duration(milliseconds: 400);

Color _statusColor(String status) {
  final hex = statusColor[status];
  return hex == null
      ? const Color(0xff6b7280)
      : Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));
}

class UnitSearchFilters {
  const UnitSearchFilters({
    this.q = '',
    this.status = 'available',
    this.unitType = '',
    this.direction = '',
    this.sort = '',
  });
  final String q, status, unitType, direction, sort;
  Map<String, String> toParams() => {
    if (q.trim().isNotEmpty) 'q': q.trim(),
    if (status.trim().isNotEmpty) 'status': status.trim(),
    if (unitType.trim().isNotEmpty) 'unit_type': unitType.trim(),
    if (direction.trim().isNotEmpty) 'direction': direction.trim(),
    if (sort.isNotEmpty) ...{
      'sort': sort.split(':').first,
      'dir': sort.split(':').last,
    },
  };
  factory UnitSearchFilters.fromParams(Map<String, String> p) =>
      UnitSearchFilters(
        q: p['q'] ?? '',
        status: p['status'] ?? '',
        unitType: p['unit_type'] ?? '',
        direction: p['direction'] ?? '',
        sort: p['sort'] == null || p['sort']!.isEmpty
            ? ''
            : '${p['sort']}:${p['dir'] ?? 'asc'}',
      );
  UnitSearchFilters set(String key, String value) => UnitSearchFilters(
    q: key == 'q' ? value : q,
    status: key == 'status' ? value : status,
    unitType: key == 'unit_type' ? value : unitType,
    direction: key == 'direction' ? value : direction,
    sort: key == 'sort' ? value : sort,
  );
}

class SearchUnitsScreen extends ConsumerStatefulWidget {
  const SearchUnitsScreen({super.key});
  @override
  ConsumerState<SearchUnitsScreen> createState() => _SearchUnitsState();
}

class _SearchUnitsState extends ConsumerState<SearchUnitsScreen> {
  UnitSearchFilters f = const UnitSearchFilters();
  Map<String, String> params = const {'status': 'available'};
  Timer? timer;
  int page = 1;
  bool sheet = false, saving = false, deleting = false;
  String saveName = '';
  String? failure;
  void filters(UnitSearchFilters value) {
    setState(() => f = value);
    timer?.cancel();
    timer = Timer(searchDebounce, () {
      if (mounted) {
        setState(() {
          params = value.toParams();
          page = 1;
        });
      }
    });
  }

  void toggle(String key, String value) {
    final current = switch (key) {
      'status' => f.status,
      'unit_type' => f.unitType,
      'direction' => f.direction,
      _ => f.sort,
    };
    filters(f.set(key, current == value ? '' : value));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || saveName.trim().isEmpty) return;
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      await ref.read(saveFilterProvider)(saveName.trim(), params);
      if (mounted) {
        setState(() => saveName = '');
        ref.invalidate(fetchSavedFiltersProvider);
      }
    } catch (e) {
      if (mounted) setState(() => failure = errorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove(String id) async {
    if (deleting) return;
    setState(() {
      deleting = true;
      failure = null;
    });
    try {
      await ref.read(deleteSavedFilterProvider)(id);
      if (mounted) ref.invalidate(fetchSavedFiltersProvider);
    } catch (e) {
      if (mounted) setState(() => failure = errorMessage(e));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enums = ref.watch(fetchEnumsProvider);
    final saved = ref.watch(fetchSavedFiltersProvider);
    final queries = [
      for (var i = 1; i <= page; i++)
        searchUnitsProvider(ApiParams({...params, 'page': i, 'per_page': 30})),
    ];
    final results = queries.map((p) => ref.watch(p)).toList();
    final rows = results.expand((r) => r.value?.data ?? <SearchRow>[]).toList();
    final total = results.first.value?.total;
    final last = results.last;
    final next =
        last.value != null &&
        last.value!.page * last.value!.perPage < last.value!.total;
    final extras = <({String key, String label})>[
      if (f.unitType.isNotEmpty) (key: 'unit_type', label: f.unitType),
      if (f.direction.isNotEmpty)
        (
          key: 'direction',
          label:
              'Hướng ${enums.value?.directionLabels[f.direction] ?? f.direction}',
        ),
      if (f.sort.isNotEmpty)
        (
          key: 'sort',
          label:
              searchSorts.where((s) => s.$1 == f.sort).firstOrNull?.$2 ??
              'Sắp xếp',
        ),
    ];
    Future<void> refresh() async {
      for (final query in queries) {
        ref.invalidate(query);
      }
      await ref.read(queries.first.future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tìm căn')),
      body: Stack(
        children: [
          ListScreen<SearchRow>(
            data: rows,
            keyOf: (u) => u.id,
            top: SearchBar(
              value: f.q,
              onChangeText: (v) => filters(f.set('q', v)),
              placeholder: 'Mã căn, mã công khai, tên dự án…',
              autoCapitalize: TextCapitalization.characters,
              onFilter: () => setState(() => sheet = true),
              filterCount: extras.length,
            ),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                ChipRail(
                  children: [
                    for (final st in [
                      'available',
                      'reserved',
                      'booked',
                      'sold',
                    ])
                      Chip(
                        label: statusLabel[st] ?? st,
                        active: f.status == st,
                        color: _statusColor(st),
                        onPress: () => toggle('status', st),
                      ),
                  ],
                ),
                if (extras.isNotEmpty)
                  ChipRail(
                    children: [
                      for (final e in extras)
                        Chip(
                          label: e.label,
                          active: true,
                          trailing: Ionicons.close,
                          onPress: () => filters(f.set(e.key, '')),
                        ),
                    ],
                  ),
                if (saved.value?.isNotEmpty == true)
                  ChipRail(
                    children: [
                      for (final s in saved.value!)
                        Chip(
                          label: s.name,
                          icon: Ionicons.star,
                          onPress: () =>
                              filters(UnitSearchFilters.fromParams(s.params)),
                        ),
                    ],
                  ),
                if (total != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '$total căn',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            empty: AsyncView(
              value: results.first,
              onRetry: () => ref.invalidate(queries.first),
              builder: (_) => Empty(
                icon: Ionicons.searchOutline,
                text: 'Không có căn phù hợp. Thử mã ngắn hơn hoặc đổi trạng thái.',
                action: (
                  label: 'Đặt lại bộ lọc',
                  onPress: () => filters(const UnitSearchFilters()),
                ),
              ),
            ),
            renderItem: (u) => Card(
              onPress: () => context.push('/can/${Uri.encodeComponent(u.id)}'),
              accessibilityLabel:
                  'Căn ${u.publicCode ?? u.code}, ${statusLabel[u.status] ?? u.status}',
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        u.publicCode ?? u.code,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Pill(
                      label: statusLabel[u.status] ?? u.status,
                      color: _statusColor(u.status),
                    ),
                  ],
                ),
                if (u.project?.name.isNotEmpty == true ||
                    u.block?.name.isNotEmpty == true ||
                    u.floor != null)
                  Muted(
                    [
                          u.project?.name,
                          u.block?.name,
                          if (u.floor != null) 'Tầng ${u.floor}',
                        ]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Muted(
                      [
                            u.unitType,
                            if (u.bedrooms != null) '${u.bedrooms}PN',
                            fmtArea(u.areaNet ?? u.areaGross),
                            u.direction,
                          ]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                    ),
                    Text(
                      '${fmtPrice(u.priceMin ?? u.priceList)}${u.priceMinLabel?.isNotEmpty == true ? ' (${u.priceMinLabel})' : ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (u.heldBy?.isNotEmpty == true)
                  Row(
                    spacing: 6,
                    children: [
                      const Icon(
                        Ionicons.lockClosedOutline,
                        size: 14,
                        color: c.muted,
                      ),
                      Expanded(child: Muted('Đại lý giữ: ${u.heldBy}')),
                    ],
                  ),
              ],
            ),
            footer: last.hasError && rows.isNotEmpty
                ? ErrorBox(
                    error: last.error!,
                    onRetry: () => ref.invalidate(queries.last),
                  )
                : next || (last.isLoading && page > 1)
                ? Button(
                    kind: 'secondary',
                    title: 'Tải thêm',
                    loading: last.isLoading,
                    onPress: () => setState(() => page++),
                  )
                : null,
            onRefresh: refresh,
          ),
          Sheet(
            visible: sheet,
            onClose: () => setState(() => sheet = false),
            title: 'Lọc & sắp xếp',
            footer: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Button(
                    kind: 'secondary',
                    title: 'Xoá lọc',
                    disabled: extras.isEmpty,
                    onPress: () =>
                        filters(UnitSearchFilters(q: f.q, status: f.status)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Button(
                    title: total == null ? 'Xem kết quả' : 'Xem $total căn',
                    onPress: () => setState(() => sheet = false),
                  ),
                ),
              ],
            ),
            children: [
              FilterGroup(
                title: 'Sắp xếp',
                children: [
                  for (final (v, label) in searchSorts)
                    Chip(
                      label: label,
                      active: f.sort == v,
                      onPress: () => filters(f.set('sort', v)),
                    ),
                ],
              ),
              if (enums.value?.unitType.isNotEmpty == true)
                FilterGroup(
                  title: 'Loại căn',
                  children: [
                    for (final t in enums.value!.unitType)
                      Chip(
                        label: t,
                        active: f.unitType == t,
                        onPress: () => toggle('unit_type', t),
                      ),
                  ],
                ),
              if (enums.value?.direction.isNotEmpty == true)
                FilterGroup(
                  title: 'Hướng',
                  children: [
                    for (final d in enums.value!.direction)
                      Chip(
                        label: enums.value!.directionLabels[d] ?? d,
                        active: f.direction == d,
                        onPress: () => toggle('direction', d),
                      ),
                  ],
                ),
              Field(
                label: 'Lưu bộ lọc đang dùng',
                value: saveName,
                onChangeText: (v) => setState(() => saveName = v),
                placeholder: 'Tên bộ lọc',
              ),
              if (failure != null) Notice(tone: 'error', text: failure!),
              Button(
                kind: 'soft',
                icon: Ionicons.starOutline,
                title: 'Lưu bộ lọc',
                disabled: saveName.trim().isEmpty,
                loading: saving,
                onPress: save,
              ),
              if (saved.value?.isNotEmpty == true) ...[
                const Muted('BỘ LỌC ĐÃ LƯU'),
                for (final s in saved.value!)
                  Row(
                    children: [
                      Expanded(child: Text(s.name)),
                      Button(
                        kind: 'link',
                        title: 'Xoá',
                        accessibilityLabel: 'Xoá bộ lọc ${s.name}',
                        disabled: deleting,
                        onPress: () => remove(s.id),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
