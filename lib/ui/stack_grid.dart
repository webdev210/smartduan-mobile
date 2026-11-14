import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import 'format.dart';
import 'kit.dart' show Empty, Segmented, ListItem;
import 'theme.dart' as c;

class StackGrid extends StatefulWidget {
  const StackGrid({
    super.key,
    required this.plan,
    this.keep,
    required this.onOpen,
    this.priceLabel = false,
    this.fundColors,
    this.sliver = false,
    this.viewMode,
  }) : assert(viewMode == null || viewMode == 'grid' || viewMode == 'list');
  final StackPlan plan;
  final bool Function(StackCell)? keep;
  final ValueChanged<String> onOpen;
  final bool priceLabel;
  final Map<String, String?>? fundColors;
  final bool sliver;

  /// When set, the parent owns the single view selector.
  final String? viewMode;

  @override
  State<StackGrid> createState() => _StackGridState();
}

class _StackGridState extends State<StackGrid> {
  bool _list = false;
  final _horizontal = _BoardScrollController();
  late List<({StackFloor floor, List<StackCell?> cells})> _rows;
  late Map<StackCell, String> _prices;
  StackPlan get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant StackGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.plan, plan) ||
        oldWidget.priceLabel != widget.priceLabel) {
      _prepare();
    }
  }

  void _prepare() {
    final floors = [...plan.floors]..sort((a, b) => b.floor.compareTo(a.floor));
    _rows = floors.map((floor) {
      final byAxis = {for (final cell in floor.cells) cell.axis: cell};
      return (
        floor: floor,
        cells: plan.layout == 'floors'
            ? plan.axes.map((axis) => byAxis[axis]).toList()
            : floor.cells,
      );
    }).toList();
    _prices = {
      for (final floor in floors)
        for (final cell in floor.cells)
          cell: cell.status == 'sold'
              ? 'Đã bán'
              : widget.priceLabel
              ? cell.priceMinLabel ?? '—'
              : fmtPrice(cell.priceMin),
    };
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final width = 84 * (scale.scale(11) / 11).clamp(1.0, double.infinity);
    final height = 52 + (scale.scale(11) - 11).clamp(0.0, double.infinity) * 3;
    if (_rows.isEmpty) {
      const empty = Empty(text: 'Toà này chưa có căn nào bạn được xem.');
      return widget.sliver ? const SliverToBoxAdapter(child: empty) : empty;
    }
    final modes = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Segmented(
        value: _list ? 'list' : 'grid',
        onChange: (value) => setState(() => _list = value == 'list'),
        options: const [
          (key: 'grid', label: 'Sơ đồ', count: null),
          (key: 'list', label: 'Danh sách', count: null),
        ],
      ),
    );
    Widget withMode(Widget content) => widget.viewMode != null
        ? content
        : widget.sliver
        ? SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(child: modes),
              ),
              content,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [modes, content],
          );
    if (widget.viewMode == 'list' || (widget.viewMode == null && _list)) {
      final matches = _rows
          .expand((row) => row.cells)
          .whereType<StackCell>()
          .where((cell) => widget.keep?.call(cell) ?? true)
          .toList();
      Widget item(BuildContext context, int index) {
        final cell = matches[index];
        return Material(
          color: c.card,
          child: ListItem(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: cell.code,
            subtitle: [
              statusLabel[cell.status] ?? cell.status,
              _prices[cell]!,
              if (cell.areaNet != null) fmtArea(cell.areaNet),
              if (cell.direction != null) cell.direction!,
            ].join(' · '),
            onPress: () => widget.onOpen(cell.id),
          ),
        );
      }

      if (matches.isEmpty) {
        const empty = Empty(text: 'Không có căn khớp bộ lọc trong tòa này.');
        return withMode(
          widget.sliver ? const SliverToBoxAdapter(child: empty) : empty,
        );
      }
      return withMode(
        widget.sliver
            ? SliverList.separated(
                itemCount: matches.length,
                itemBuilder: item,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: c.line),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matches.length,
                itemBuilder: item,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: c.line),
              ),
      );
    }
    final header = plan.layout == 'floors'
        ? Row(
            spacing: 4,
            children: [
              const SizedBox(width: 44),
              for (final axis in plan.axes)
                SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      Text(
                        axis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        plan.axisMeta[axis]?.unitType ?? '',
                        style: const TextStyle(color: c.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          )
        : null;
    if (widget.sliver) {
      final columns = _rows.fold(
        0,
        (count, row) => row.cells.length > count ? row.cells.length : count,
      );
      final boardWidth = 44 + columns * (width + 4);
      return withMode(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: _rows.length + (header == null ? 0 : 1),
            itemBuilder: (context, index) {
              final rowIndex = index - (header == null ? 0 : 1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: boardWidth,
                    child: rowIndex < 0
                        ? header
                        : _row(_rows[rowIndex], width, height),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return withMode(
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            ?header,
            for (final row in _rows) _row(row, width, height),
          ],
        ),
      ),
    );
  }

  Widget _row(
    ({StackFloor floor, List<StackCell?> cells}) row,
    double width,
    double height,
  ) {
    final (:floor, :cells) = row;
    return Row(
      spacing: 4,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            plan.layout == 'rows'
                ? floor.name ?? 'Dãy ${floor.floor}'
                : 'T${floor.floor}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        for (final cell in cells)
          cell == null
              ? SizedBox(width: width, height: height)
              : _cell(cell, width, height),
      ],
    );
  }

  Widget _cell(StackCell cell, double width, double height) {
    final included = widget.keep?.call(cell) ?? true;
    final price = _prices[cell]!;
    final raw = widget.fundColors?[cell.fund];
    final dot = raw == null ? null : _hex(raw);
    return Opacity(
      opacity: included ? 1 : 0.2,
      child: Semantics(
        button: true,
        enabled: included,
        label:
            'Căn ${cell.code}, ${statusLabel[cell.status]}, $price${included ? '' : ', Không khớp bộ lọc'}',
        excludeSemantics: true,
        onTap: included ? () => widget.onOpen(cell.id) : null,
        child: Material(
          color: _hex(statusColor[cell.status] ?? '#9ca3af')!,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: included ? () => widget.onOpen(cell.id) : null,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: dot == null ? 0 : 8),
                          child: Text(
                            cell.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.solidForeground(
                                _hex(statusColor[cell.status] ?? '#9ca3af')!,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.solidForeground(
                              _hex(statusColor[cell.status] ?? '#9ca3af')!,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dot != null)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color? _hex(String value) {
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(0xff000000 | int.parse(value.substring(1), radix: 16));
}

// Each lazy floor shares the board's horizontal position, including newly
// mounted floors. Vertical scrolling remains owned by the page's sliver list.
class _BoardScrollController extends ScrollController {
  _BoardScrollController() : super(keepScrollOffset: false);
  final _listeners = <ScrollPosition, VoidCallback>{};
  double _offset = 0;
  bool _syncing = false;
  @override
  double get initialScrollOffset => _offset;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    void sync() {
      if (_syncing || !position.hasContentDimensions) return;
      _syncing = true;
      _offset = position.pixels;
      try {
        for (final other in positions) {
          if (identical(other, position) || !other.hasContentDimensions) {
            continue;
          }
          final offset = _offset.clamp(
            other.minScrollExtent,
            other.maxScrollExtent,
          );
          if (other.pixels != offset) other.jumpTo(offset);
        }
      } finally {
        _syncing = false;
      }
    }

    _listeners[position] = sync;
    position.addListener(sync);
  }

  @override
  void detach(ScrollPosition position) {
    position.removeListener(_listeners.remove(position)!);
    super.detach(position);
  }

  @override
  void dispose() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
    super.dispose();
  }
}
