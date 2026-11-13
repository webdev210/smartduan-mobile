import 'package:material_ui/material_ui.dart'
    hide Card, Chip, Divider, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../api/units.dart';
import '../../realtime/inventory_channel.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/search.dart';

const historyFields = {
  'status': 'Trạng thái',
  'price_list': 'Giá niêm yết',
  'price_min': 'Giá thấp nhất',
  'price_loan': 'Giá vay',
  'price_progress': 'Giá theo tiến độ',
  'price_early': 'Giá thanh toán sớm',
  'fund': 'Quỹ',
  'reserved_until': 'Giữ đến',
};
String historyValue(
  String field,
  String? value, [
  Map<String, String> funds = const {},
]) => switch ((field, value)) {
  (_, null || '') => '—',
  ('status', final v?) => statusLabel[v] ?? v,
  ('fund', final v?) => funds[v] ?? v,
  ('reserved_until', final v?) => fmtDate(v, true),
  (final f, final v?) when f.startsWith('price_') => fmtPrice(v),
  (_, final v?) => v,
};

String historySource(String source) => switch (source) {
  'manual' => 'Cập nhật thủ công',
  'import' => 'Nhập dữ liệu',
  'sync' => 'Đồng bộ',
  '' => 'Chưa rõ nguồn',
  _ => 'Nguồn: $source',
};

class ProjectHistoryScreen extends ConsumerStatefulWidget {
  const ProjectHistoryScreen({super.key, required this.projectId, this.name});
  final String projectId;
  final String? name;
  @override
  ConsumerState<ProjectHistoryScreen> createState() =>
      _ProjectHistoryScreenState();
}

class _ProjectHistoryScreenState extends ConsumerState<ProjectHistoryScreen> {
  String _query = '';
  String? _field;
  int page = 1;
  @override
  Widget build(BuildContext context) {
    final queries = [
      for (var i = 1; i <= page; i++)
        fetchProjectHistoryProvider((projectId: widget.projectId, page: i)),
    ];
    final values = [for (final query in queries) ref.watch(query)];
    final history = values.first;
    final all = [for (final value in values) ...?value.value?.data];
    final last = values.last;
    final funds =
        ref.watch(fetchEnumsProvider).value?.fundLabels ??
        const <String, String>{};
    Future<void> refresh() async {
      for (final query in queries) {
        ref.invalidate(query);
      }
      await ref.read(queries.first.future);
    }

    final units = ref.watch(inventoryUnitsProvider(widget.projectId));
    final codes = {
      for (final u in units.value ?? <Unit>[]) u.id: u.publicCode ?? u.code,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.name == null ? 'Biến động' : 'Biến động · ${widget.name}',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: SearchBar(
                value: _query,
                onChangeText: (v) => setState(() => _query = v),
                autoCapitalize: TextCapitalization.characters,
                placeholder: 'Tìm mã căn, trạng thái, nguồn…',
              ),
            ),
            Expanded(
              child: AsyncView(
                value: history,
                onRetry: () => ref.invalidate(queries.first),
                builder: (result) {
                  final fields = all.map((h) => h.field).toSet();
                  final rows = smartFilter(
                    all
                        .where((h) => _field == null || h.field == _field)
                        .toList(),
                    _query,
                    (h) => [
                      codes[h.unitId],
                      historyFields[h.field] ?? h.field,
                      historyValue(h.field, h.oldValue, funds),
                      historyValue(h.field, h.newValue, funds),
                      historySource(h.source),
                    ],
                  );
                  return ListScreen<HistoryRow>(
                    data: rows,
                    keyOf: (h) => h.id,
                    header: all.isEmpty
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 14,
                            children: [
                              if (units.isLoading)
                                const Muted('Đang tải mã căn…'),
                              if (units.hasError) ...[
                                const Muted(
                                  'Chưa tải được mã căn. Các thay đổi vẫn hiển thị bên dưới.',
                                ),
                                ErrorBox(
                                  error: units.error,
                                  onRetry: () => ref.invalidate(
                                    inventoryUnitsSourceProvider(
                                      widget.projectId,
                                    ),
                                  ),
                                ),
                              ],
                              if (fields.length > 1)
                                ChipRail(
                                  children: [
                                    Chip(
                                      label: 'Tất cả · ${all.length}',
                                      active: _field == null,
                                      onPress: () =>
                                          setState(() => _field = null),
                                    ),
                                    for (final field in fields)
                                      Chip(
                                        label: historyFields[field] ?? field,
                                        active: _field == field,
                                        onPress: () => setState(
                                          () => _field = _field == field
                                              ? null
                                              : field,
                                        ),
                                      ),
                                  ],
                                ),
                              Muted(
                                rows.length == all.length
                                    ? '${all.length}/${result.total} thay đổi gần nhất'
                                    : '${rows.length} trong ${all.length} thay đổi gần nhất',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                    empty: all.isEmpty
                        ? const Empty(
                            icon: Ionicons.timeOutline,
                            text: 'Chưa có thay đổi nào.',
                          )
                        : Empty(
                            icon: Ionicons.searchOutline,
                            text: 'Không có thay đổi nào khớp.',
                            action: (
                              label: 'Xoá tìm kiếm & bộ lọc',
                              onPress: () => setState(() {
                                _query = '';
                                _field = null;
                              }),
                            ),
                          ),
                    renderItem: (h) => Column(
                      children: [
                        if (h.id != rows.first.id) const Divider(),
                        ListItem(
                          title:
                              '${codes[h.unitId] ?? (units.isLoading ? 'Đang tải mã căn…' : 'Chưa có mã căn')} · ${historyFields[h.field] ?? h.field}: ${historyValue(h.field, h.oldValue, funds)} → ${historyValue(h.field, h.newValue, funds)}',
                          subtitle:
                              '${fmtDate(h.changedAt, true)} · ${historySource(h.source)}',
                          onPress: () => context.push(
                            '/can/${Uri.encodeComponent(h.unitId)}',
                          ),
                        ),
                      ],
                    ),
                    footer: last.hasError && page > 1
                        ? ErrorBox(
                            error: last.error,
                            onRetry: () => ref.invalidate(queries.last),
                          )
                        : last.isLoading ||
                              (last.value != null &&
                                  last.value!.data.isNotEmpty &&
                                  all.length < result.total)
                        ? Button(
                            kind: 'secondary',
                            title: 'Tải thêm',
                            loading: last.isLoading,
                            onPress: () => setState(() => page++),
                          )
                        : null,
                    onRefresh: refresh,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
