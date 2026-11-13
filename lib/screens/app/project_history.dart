import 'package:material_ui/material_ui.dart' hide Card, Chip, SearchBar;
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
  'fund': 'Quỹ',
  'reserved_until': 'Giữ đến',
};
String historyValue(String field, String? value) => value == null
    ? '—'
    : field == 'status'
    ? statusLabel[value] ?? value
    : value;

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
  @override
  Widget build(BuildContext context) {
    final key = (projectId: widget.projectId, page: 1);
    final history = ref.watch(fetchProjectHistoryProvider(key));
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
      body: Column(
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
              onRetry: () => ref.invalidate(fetchProjectHistoryProvider(key)),
              builder: (result) {
                final all = result.data;
                final fields = all.map((h) => h.field).toSet();
                final rows = smartFilter(
                  all
                      .where((h) => _field == null || h.field == _field)
                      .toList(),
                  _query,
                  (h) => [
                    codes[h.unitId],
                    historyFields[h.field] ?? h.field,
                    historyValue(h.field, h.oldValue),
                    historyValue(h.field, h.newValue),
                    h.source,
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
                  renderItem: (h) => Card(
                    padding: EdgeInsets.zero,
                    child: ListItem(
                      title:
                          '${codes[h.unitId] ?? 'Căn'} · ${historyFields[h.field] ?? h.field}: ${historyValue(h.field, h.oldValue)} → ${historyValue(h.field, h.newValue)}',
                      subtitle: '${fmtDate(h.changedAt, true)} · ${h.source}',
                      onPress: () =>
                          context.push('/can/${Uri.encodeComponent(h.unitId)}'),
                    ),
                  ),
                  onRefresh: () =>
                      ref.refresh(fetchProjectHistoryProvider(key).future),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
