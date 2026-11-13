import 'package:ionicons/ionicons.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;

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
    this.bedrooms = '',
    this.budget = '',
  });
  final String q, status, unitType, direction, sort, bedrooms, budget;
  num? get priceCeiling {
    final value =
        (num.tryParse(budget.trim().replaceAll(',', '.')) ?? double.nan)
            .toDouble() *
        1000000000;
    return value.isFinite && value > 0 ? value : null;
  }

  bool get local => bedrooms.isNotEmpty || budget.isNotEmpty;
  bool matches(SearchRow row) =>
      (budget.isEmpty || priceCeiling != null) &&
      (bedrooms.isEmpty || row.bedrooms == int.tryParse(bedrooms)) &&
      (priceCeiling == null ||
          (searchPrice(row) != null && searchPrice(row)! <= priceCeiling!));
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
    bedrooms: key == 'bedrooms' ? value : bedrooms,
    budget: key == 'budget' ? value : budget,
  );
}

num? searchPrice(SearchRow row) {
  for (final raw in [row.priceMin, row.priceList]) {
    final price = num.tryParse(raw ?? '');
    if (price != null && price.isFinite && price > 0) return price;
  }
  return null;
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
  bool sheet = false, naming = false, saving = false, deleting = false;
  bool savedOk = false;
  String saveName = '';
  String? failure;
  void filters(UnitSearchFilters value, {bool typing = false}) {
    setState(() {
      f = value;
      savedOk = false;
    });
    timer?.cancel();
    void apply() {
      if (mounted) {
        setState(() {
          final next = value.toParams();
          if (!mapEquals(params, next)) {
            params = next;
            page = 1;
          }
        });
      }
    }

    if (typing) {
      timer = Timer(searchDebounce, apply);
    } else {
      apply();
    }
  }

  void toggle(String key, String value) {
    final current = switch (key) {
      'status' => f.status,
      'unit_type' => f.unitType,
      'direction' => f.direction,
      'bedrooms' => f.bedrooms,
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
    if (saving || saveName.trim().isEmpty || f.local) return;
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      await ref.read(saveFilterProvider)(saveName.trim(), f.toParams());
      if (mounted) {
        setState(() {
          saveName = '';
          naming = false;
          savedOk = true;
        });
        ref.invalidate(fetchSavedFiltersProvider);
      }
    } catch (e) {
      if (mounted) setState(() => failure = errorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove(String id, String name) async {
    if (deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Xoá bộ lọc?'),
        content: Text('Xoá bộ lọc “$name”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || deleting) return;
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
    final matches = rows.where(f.matches).toList();
    final unknown = f.priceCeiling == null
        ? <SearchRow>[]
        : rows
              .where(
                (u) =>
                    searchPrice(u) == null &&
                    (f.bedrooms.isEmpty ||
                        u.bedrooms == int.tryParse(f.bedrooms)),
              )
              .toList();
    final updating =
        !mapEquals(params, f.toParams()) || results.any((r) => r.isLoading);
    final total = results.first.value?.total;
    final last = results.last;
    final next =
        last.value != null &&
        last.value!.page * last.value!.perPage < last.value!.total;
    final extras = <({String key, String label})>[
      if (f.bedrooms.isNotEmpty) (key: 'bedrooms', label: '${f.bedrooms} PN'),
      if (f.budget.isNotEmpty) (key: 'budget', label: 'Tối đa ${f.budget} tỷ'),
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
            data: [...matches, ...unknown],
            keyOf: (u) => u.id,
            top: SearchBar(
              value: f.q,
              onChangeText: (v) => filters(f.set('q', v), typing: true),
              placeholder: 'Mã căn, mã công khai, tên dự án…',
              autoCapitalize: TextCapitalization.characters,
              onFilter: () => setState(() => sheet = true),
              filterCount: extras.length,
            ),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                if (enums.isLoading || saved.isLoading) const Loading(),
                if (enums.hasError)
                  const Muted('Chưa tải được lựa chọn bộ lọc.'),
                if (enums.hasError)
                  ErrorBox(
                    error: enums.error,
                    onRetry: () => ref.invalidate(fetchEnumsProvider),
                  ),
                if (saved.hasError) const Muted('Chưa tải được bộ lọc đã lưu.'),
                if (saved.hasError)
                  ErrorBox(
                    error: saved.error,
                    onRetry: () => ref.invalidate(fetchSavedFiltersProvider),
                  ),
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
                Button(
                  title: 'Lưu bộ lọc này',
                  kind: 'link',
                  onPress: () => setState(() => naming = true),
                ),
                if (savedOk)
                  const Notice(tone: 'success', text: 'Đã lưu bộ lọc.'),
                if (total != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      updating
                          ? 'Đang cập nhật kết quả…'
                          : '${matches.length} phù hợp trong ${rows.length}/$total căn đã tải',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (unknown.isNotEmpty)
                  Muted(
                    '${unknown.length} căn chưa có giá — cần xác nhận, chưa tính là phù hợp ngân sách.',
                  ),
                if (f.budget.isNotEmpty && f.priceCeiling == null)
                  const Notice(
                    tone: 'error',
                    text: 'Kiểm tra giá tối đa trong bộ lọc. Nhập số tiền lớn hơn 0.',
                  ),
                if (next)
                  const Muted(
                    'Tải thêm để kiểm tra phần còn lại của bảng hàng.',
                  ),
              ],
            ),
            empty: AsyncView(
              value: results.first,
              onRetry: () => ref.invalidate(queries.first),
              builder: (_) => Empty(
                icon: Ionicons.searchOutline,
                text: next
                    ? 'Chưa có căn phù hợp trong phần đã tải. Tải thêm để kiểm tra tiếp.'
                    : 'Không có căn phù hợp. Thử mã ngắn hơn hoặc đổi trạng thái.',
                action: (
                  label: 'Đặt lại bộ lọc',
                  onPress: () => filters(const UnitSearchFilters()),
                ),
              ),
            ),
            renderItem: (u) => Card(
              onPress: () => context.push('/can/${Uri.encodeComponent(u.id)}'),
              accessibilityLabel:
                  'Căn ${u.publicCode ?? u.code}, ${statusLabel[u.status] ?? u.status}, ${u.project?.name ?? ''}, ${u.block?.name ?? ''}, ${u.floor == null ? '' : 'Tầng ${u.floor}'}, ${u.unitType ?? ''}, ${u.bedrooms == null ? '' : '${u.bedrooms} phòng ngủ'}, ${fmtArea(u.areaNet ?? u.areaGross)}, ${enums.value?.directionLabels[u.direction] ?? u.direction ?? ''}, ${fmtPrice(u.priceMin ?? u.priceList)}, ${u.priceMinLabel ?? ''}${u.heldBy?.isNotEmpty == true ? ', Đại lý giữ: ${u.heldBy}' : ''}',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      u.publicCode ?? u.code,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      statusLabel[u.status] ?? u.status,
                      style: TextStyle(color: _statusColor(u.status)),
                    ),
                  ],
                ),
                if (f.priceCeiling != null && searchPrice(u) == null)
                  const Muted('Chưa có giá — chưa xác nhận ngân sách'),
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
                            enums.value?.directionLabels[u.direction] ??
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
            footer: last.hasError && page > 1
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
            footer: ButtonGroup(
              spacing: 10,
              children: [
                Button(
                  kind: 'secondary',
                  title: 'Xoá lọc',
                  disabled: extras.isEmpty,
                  onPress: () =>
                      filters(UnitSearchFilters(q: f.q, status: f.status)),
                ),
                Button(
                  title: updating ? 'Đang cập nhật…' : 'Xem kết quả',
                  onPress: () => setState(() => sheet = false),
                ),
              ],
            ),
            children: [
              FilterGroup(
                title: 'Phòng ngủ',
                children: [
                  for (final count in ['0', '1', '2', '3', '4', '5'])
                    Chip(
                      label: count == '0' ? 'Studio' : '$count PN',
                      active: f.bedrooms == count,
                      onPress: () => toggle('bedrooms', count),
                    ),
                ],
              ),
              Field(
                label: 'Giá tối đa (tỷ đồng)',
                value: f.budget,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChangeText: (v) => filters(f.set('budget', v)),
                error: f.budget.isNotEmpty && f.priceCeiling == null
                    ? 'Nhập số tiền lớn hơn 0.'
                    : null,
              ),
              const Muted(
                'Chỉ lọc các căn đã tải theo phòng ngủ và ngân sách.',
              ),
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
            ],
          ),
          Sheet(
            visible: naming,
            onClose: () => setState(() => naming = false),
            title: 'Lưu bộ lọc',
            children: [
              if (f.local)
                const Notice(
                  text: 'Chưa lưu được phòng ngủ và ngân sách. Xoá hai tiêu chí này trước khi lưu.',
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
                disabled: saveName.trim().isEmpty || f.local,
                loading: saving,
                onPress: save,
              ),
              if (saved.value?.isNotEmpty == true) ...[
                const Muted('Bộ lọc đã lưu'),
                for (final s in saved.value!)
                  Row(
                    children: [
                      Expanded(child: Text(s.name)),
                      Button(
                        kind: 'danger',
                        title: 'Xoá',
                        accessibilityLabel: 'Xoá bộ lọc ${s.name}',
                        disabled: deleting,
                        onPress: () => remove(s.id, s.name),
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
