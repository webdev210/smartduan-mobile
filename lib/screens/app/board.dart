import 'package:material_ui/material_ui.dart'
    hide Card, Chip, SearchBar, Row, Divider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/errors.dart';
import '../../api/projects.dart';
import '../../api/units.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../realtime/inventory_channel.dart';
import '../../ui/board_filter.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' hide Row;

import 'package:material_ui/material_ui.dart' as m show Row;

import '../../ui/stack_grid.dart';
import '../../ui/theme.dart' as c;

final shareBoardFileProvider = Provider(
  (ref) => (String path, Rect origin) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        title: 'Bảng hàng',
        sharePositionOrigin: origin,
      ),
    );
  },
);

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({
    super.key,
    required this.projectId,
    this.name,
    this.blockId,
  });
  final String projectId;
  final String? name, blockId;
  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  late String? _pickedBlock = widget.blockId;
  BoardFilter _filter = emptyFilter;
  bool _list = false;
  String _viewMode = 'grid';
  String _budget = '';
  bool _sheet = false, _exporting = false;
  Object? _exportError;

  void _set(String key, Object? value) => setState(() {
    final f = _filter;
    _filter = BoardFilter(
      code: key == 'code' ? value as String : f.code,
      status: key == 'status' ? value as String? : f.status,
      type: key == 'type' ? value as String? : f.type,
      fund: key == 'fund' ? value as String? : f.fund,
      direction: key == 'direction' ? value as String? : f.direction,
      bedrooms: key == 'bedrooms' ? value as int? : f.bedrooms,
    );
  });
  void _clearExtra() => setState(
    () => _filter = BoardFilter(status: _filter.status, code: _filter.code),
  );
  void _open(String id) => context.push('/can/${Uri.encodeComponent(id)}');

  Future<void> _export() async {
    final session = ref.read(sessionProvider);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _exporting = true;
      _exportError = null;
    });
    try {
      final share = ref.read(shareBoardFileProvider);
      final path = await ref.read(downloadUnitsXlsxProvider)(
        widget.projectId,
        widget.name ?? widget.projectId,
      );
      if (mounted && identical(session, ref.read(sessionProvider))) {
        await share(path, origin);
      }
    } catch (error) {
      if (mounted) setState(() => _exportError = error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.projectId;
    final live = ref.watch(inventoryChannelProvider(id)).live;
    final free = isFreeSales(ref.watch(sessionProvider).roles);
    final blocks = ref.watch(fetchBlocksProvider(id));
    final enumQuery = ref.watch(fetchEnumsProvider);
    final enums = enumQuery.value;
    final blockId = _pickedBlock ?? blocks.value?.firstOrNull?.id;
    final key = (projectId: id, blockId: blockId ?? '');
    final AsyncValue<StackPlan?> stack = blockId == null
        ? const AsyncData<StackPlan?>(null)
        : ref.watch(inventoryStackProvider(key));
    final tooLarge =
        stack.error is ApiError &&
        (stack.error as ApiError).code == 'grid_too_large';
    final noBlocks = blocks.hasValue && blocks.value!.isEmpty;
    final flat = _list || tooLarge || noBlocks;
    final units = flat
        ? ref.watch(inventoryUnitsProvider(id))
        : const AsyncData<List<Unit>>([]);
    final plan = flat ? null : stack.value;
    final pool = <Filterable>[
      if (flat)
        ...?units.value?.where((u) => _list || noBlocks || u.blockId == blockId)
      else if (plan != null)
        ...cellsOf(plan),
    ];
    final counts = countByStatus(pool);
    final opts = filterOptions(pool, plan);
    final f = _filter;
    final budget = num.tryParse(_budget);
    final unknownPrices = pool
        .whereType<Unit>()
        .where(
          (u) =>
              keeps(u, f) &&
              num.tryParse(u.priceMin ?? u.priceList ?? '') == null,
        )
        .length;
    final incompatible =
        (f.type != null && !opts.types.contains(f.type)) ||
        (f.bedrooms != null && !opts.bedrooms.contains(f.bedrooms)) ||
        (f.direction != null && !opts.directions.contains(f.direction)) ||
        (f.fund != null && !opts.funds.contains(f.fund));
    String fundName(String slug) => enums?.fundLabels[slug] ?? slug;
    String dirName(String slug) => enums?.directionLabels[slug] ?? slug;
    final extra = <({String key, String label})>[
      if (f.type != null) (key: 'type', label: f.type!),
      if (f.bedrooms != null) (key: 'bedrooms', label: '${f.bedrooms} PN'),
      if (f.direction != null)
        (key: 'direction', label: 'Hướng ${dirName(f.direction!)}'),
      if (f.fund != null) (key: 'fund', label: fundName(f.fund!)),
    ];
    final hasExtra =
        opts.types.length > 1 ||
        opts.bedrooms.length > 1 ||
        opts.directions.length > 1 ||
        opts.funds.isNotEmpty;
    final matched = pool.where((u) => keeps(u, f, plan)).length;
    final flatRows = flat
        ? pool.cast<Unit>().where((u) {
            final price = num.tryParse(u.priceMin ?? u.priceList ?? '');
            return keeps(u, f) &&
                (budget == null || (price != null && price <= budget));
          }).toList()
        : <Unit>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.name == null ? 'Bảng hàng' : 'Bảng hàng · ${widget.name}',
        ),
      ),
      body: Stack(
        children: [
          Screen(
            onRefresh: () async {
              ref.invalidate(fetchBlocksProvider(id));
              ref.read(inventoryChannelProvider(id).notifier).refresh();
              // Each provider keeps its own error for the screen to display.
              await Future.wait([
                AsyncValue.guard(
                  () => ref.read(fetchBlocksProvider(id).future),
                ),
                if (flat)
                  AsyncValue.guard(
                    () => ref.read(inventoryUnitsSourceProvider(id).future),
                  ),
                if (blockId != null)
                  AsyncValue.guard(
                    () => ref.read(inventoryStackSourceProvider(key).future),
                  ),
              ]);
            },
            slivers: [
              if (flat && flatRows.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: flatRows.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) => _unitCard(flatRows[i]),
                  ),
                ),
              if (plan != null)
                StackGrid(
                  sliver: true,
                  viewMode: _viewMode,
                  plan: plan,
                  keep: (cell) => keeps(cell, f, plan),
                  onOpen: _open,
                  fundColors: enums?.fundColors,
                ),
            ],
            children: [
              if (enumQuery.isLoading) const Loading(),
              if (enumQuery.hasError) const Muted('Chưa tải được nhãn bộ lọc.'),
              if (enumQuery.hasError)
                ErrorBox(
                  error: enumQuery.error,
                  onRetry: () => ref.invalidate(fetchEnumsProvider),
                ),
              m.Row(
                spacing: 8,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: live ? c.success : c.subtle,
                    ),
                  ),
                  Expanded(
                    child: Muted(
                      live ? 'Đang cập nhật trực tiếp' : 'Chưa kết nối cập nhật trực tiếp — kéo xuống để làm mới',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              ButtonGroup(
                spacing: 8,
                children: [
                  Button(
                    kind: 'secondary',
                    icon: Ionicons.timeOutline,
                    title: 'Biến động',
                    onPress: () => context.push(
                      Uri(
                        path: '/bien-dong/$id',
                        queryParameters: {
                          if (widget.name != null) 'name': widget.name!,
                        },
                      ).toString(),
                    ),
                  ),
                  if (!free)
                    Button(
                      kind: 'secondary',
                      icon: Ionicons.downloadOutline,
                      title: 'Xuất Excel',
                      loading: _exporting,
                      onPress: _export,
                    ),
                ],
              ),
              if (_exportError != null)
                Notice(
                  tone: 'error',
                  text:
                      'Không tải được file Excel: ${errorMessage(_exportError)}',
                ),
              const Body(
                'Phạm vi',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Chips(
                children: [
                  Chip(
                    label: 'Theo toà',
                    active: !_list,
                    onPress: () => setState(() => _list = false),
                  ),
                  Chip(
                    label: 'Toàn dự án',
                    active: _list,
                    onPress: () => setState(() => _list = true),
                  ),
                ],
              ),
              if (_list)
                Field(
                  label: 'Giá tối đa (đồng)',
                  value: _budget,
                  keyboardType: TextInputType.number,
                  onChangeText: (value) => setState(() => _budget = value),
                  error:
                      _budget.isNotEmpty &&
                          (budget == null || !budget.isFinite || budget < 0)
                      ? 'Nhập giá tối đa bằng số không âm.'
                      : null,
                ),
              if (_list)
                const Muted(
                  'Phạm vi: toàn dự án. Danh sách hiển thị sau khi tải đủ các trang.',
                ),
              if (!_list)
                AsyncView(
                  value: blocks,
                  onRetry: () => ref.invalidate(fetchBlocksProvider(id)),
                  builder: (list) => list.isEmpty
                      ? const SizedBox.shrink()
                      : ChipRail(
                          children: [
                            for (final b in list)
                              Chip(
                                icon: Ionicons.businessOutline,
                                label: b.name,
                                active: b.id == blockId,
                                onPress: () {
                                  setState(() => _pickedBlock = b.id);
                                },
                              ),
                          ],
                        ),
                ),
              SearchBar(
                value: f.code,
                onChangeText: (v) => _set('code', v),
                autoCapitalize: TextCapitalization.characters,
                placeholder: 'Tìm mã căn, VD: A-12.05',
                onFilter: hasExtra ? () => setState(() => _sheet = true) : null,
                filterCount: extra.length,
              ),
              if (!flat)
                Segmented(
                  value: _viewMode,
                  onChange: (value) => setState(() => _viewMode = value),
                  options: const [
                    (key: 'grid', label: 'Sơ đồ', count: null),
                    (key: 'list', label: 'Danh sách', count: null),
                  ],
                ),
              ChipRail(
                children: [
                  Chip(
                    label: 'Tất cả · ${pool.length}',
                    active: f.status == null,
                    onPress: () => _set('status', null),
                  ),
                  for (final s in [
                    'available',
                    'reserved',
                    'booked',
                    'sold',
                    'hidden',
                  ])
                    if ((counts[s] ?? 0) > 0 || f.status == s)
                      Chip(
                        label: '${statusLabel[s]} · ${counts[s] ?? 0}',
                        color: _color(statusColor[s]),
                        active: f.status == s,
                        onPress: () => _set('status', f.status == s ? null : s),
                      ),
                ],
              ),
              if (extra.isNotEmpty)
                ChipRail(
                  children: [
                    for (final x in extra)
                      Chip(
                        label: x.label,
                        active: true,
                        trailing: Ionicons.close,
                        onPress: () => _set(x.key, null),
                      ),
                    Chip(
                      label: 'Xoá hết',
                      icon: Ionicons.refresh,
                      onPress: _clearExtra,
                    ),
                  ],
                ),
              if (incompatible && (plan != null || units.hasValue))
                const Notice(
                  tone: 'warn',
                  text: 'Phạm vi này không có lựa chọn đang lọc. Bộ lọc vẫn được giữ; bỏ tiêu chí bên trên để xem thêm căn.',
                ),
              if (flat && budget != null && unknownPrices > 0)
                Muted(
                  '$unknownPrices căn chưa có giá, chưa tính vào kết quả theo ngân sách. Xoá giá tối đa để xem.',
                ),
              if (flat) ...[
                if (tooLarge)
                  const Notice(
                    text: 'Toà này quá nhiều căn để vẽ lưới — hiển thị dạng danh sách.',
                  ),
                AsyncView(
                  value: units,
                  onRetry: () =>
                      ref.invalidate(inventoryUnitsSourceProvider(id)),
                  builder: (_) => flatRows.isEmpty
                      ? const Empty(
                          icon: Ionicons.searchOutline,
                          text: 'Không có căn nào khớp bộ lọc.',
                        )
                      : Muted('${flatRows.length} căn'),
                ),
              ] else if (blockId != null)
                AsyncView(
                  value: stack,
                  onRetry: () =>
                      ref.invalidate(inventoryStackSourceProvider(key)),
                  builder: (_) => const SizedBox.shrink(),
                ),
            ],
          ),
          Sheet(
            visible: _sheet,
            onClose: () => setState(() => _sheet = false),
            title: 'Lọc căn',
            footer: ButtonGroup(
              spacing: 8,
              children: [
                Button(
                  kind: 'secondary',
                  title: 'Xoá lọc',
                  disabled: extra.isEmpty,
                  onPress: _clearExtra,
                ),
                Button(
                  title: 'Xem $matched căn',
                  onPress: () => setState(() => _sheet = false),
                ),
              ],
            ),
            children: [
              if (opts.types.length > 1)
                FilterGroup(
                  title: 'Loại căn',
                  children: [
                    for (final t in opts.types)
                      Chip(
                        label: t,
                        active: f.type == t,
                        onPress: () => _set('type', f.type == t ? null : t),
                      ),
                  ],
                ),
              if (opts.bedrooms.length > 1)
                FilterGroup(
                  title: 'Số phòng ngủ',
                  children: [
                    for (final b in opts.bedrooms)
                      Chip(
                        label: '$b PN',
                        active: f.bedrooms == b,
                        onPress: () =>
                            _set('bedrooms', f.bedrooms == b ? null : b),
                      ),
                  ],
                ),
              if (opts.directions.length > 1)
                FilterGroup(
                  title: 'Hướng',
                  children: [
                    for (final d in opts.directions)
                      Chip(
                        label: dirName(d),
                        active: f.direction == d,
                        onPress: () =>
                            _set('direction', f.direction == d ? null : d),
                      ),
                  ],
                ),
              if (opts.funds.isNotEmpty)
                FilterGroup(
                  title: 'Quỹ hàng',
                  children: [
                    for (final q in opts.funds)
                      Chip(
                        label: fundName(q),
                        color: _color(enums?.fundColors[q]),
                        active: f.fund == q,
                        onPress: () => _set('fund', f.fund == q ? null : q),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitCard(Unit u) => ListItem(
    onPress: () => _open(u.id),
    title: u.publicCode ?? u.code,
    subtitle:
        '${[u.unitType, if (u.bedrooms != null) '${u.bedrooms}PN', fmtArea(u.areaNet)].whereType<String>().where((s) => s.isNotEmpty).join(' · ')} · ${u.status == 'sold' ? 'Đã bán' : fmtPrice(u.priceMin ?? u.priceList)}',
    right: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .3,
      ),
      child: m.Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Flexible(
            child: Body(
              statusLabel[u.status] ?? u.status,
              style: TextStyle(color: _color(statusColor[u.status])),
            ),
          ),
          const Icon(Ionicons.chevronForward, size: 18, color: c.subtle),
        ],
      ),
    ),
  );
}

Color? _color(String? value) =>
    value != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)
    ? Color(0xff000000 | int.parse(value.substring(1), radix: 16))
    : null;
