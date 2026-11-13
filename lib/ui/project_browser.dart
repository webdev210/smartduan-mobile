import 'dart:async';

import 'package:material_ui/material_ui.dart'
    hide Card, Chip, Divider, IconButton, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../api/models.dart';
import 'catalog.dart';
import 'kit.dart' hide Row;
import 'project_card.dart';
import 'project_compare.dart';
import 'project_compare_kit.dart';
import 'project_filter.dart';
import 'search.dart';
import 'theme.dart' as c;

class ProjectQuickFind extends StatelessWidget {
  const ProjectQuickFind({
    super.key,
    required this.q,
    required this.projects,
    required this.onOpen,
    required this.onAll,
  });
  final String q;
  final List<PublicProject> projects;
  final ValueChanged<PublicProject> onOpen;
  final VoidCallback onAll;
  @override
  Widget build(BuildContext context) {
    if (q.trim().isEmpty) return const SizedBox.shrink();
    final found = filterProjects(projects, ProjectFilter(q: q), const {});
    return Card(
      padding: EdgeInsets.zero,
      children: [
        for (final p in found.take(5)) ...[
          ListItem(
            icon: Ionicons.businessOutline,
            right: const Icon(
              Ionicons.chevronForward,
              size: 16,
              color: c.subtle,
            ),
            title: p.name,
            subtitle:
                [p.district, p.province, developerOf(p)]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' · ')
                    .nullIfEmpty ??
                projectStatus[p.status]?.label ??
                '—',
            onPress: () => onOpen(p),
          ),
          const Divider(),
        ],
        Button(
          title: found.isEmpty
              ? 'Tìm trong toàn bộ danh mục'
              : 'Xem tất cả ${found.length} kết quả',
          kind: 'link',
          icon: Ionicons.arrowForward,
          onPress: onAll,
        ),
      ],
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

typedef _BrowserState = ({ProjectFilter filter, bool compact, bool sheet});
final _browserResults = Provider.autoDispose
    .family<
      ({
        List<PublicProject> rows,
        Map<String, List<Option>> options,
        List<Suggestion> hints,
        int anyStatus,
      }),
      ({
        List<PublicProject> projects,
        ProjectFilter filter,
        Map<String, String> aliases,
      })
    >(
      (ref, args) => (
        rows: filterProjects(args.projects, args.filter, args.aliases),
        options: facets(args.projects, args.filter, args.aliases),
        hints: suggest(args.projects, args.filter.q, args.filter, args.aliases),
        anyStatus: countProjectsWithoutStatus(
          args.projects,
          args.filter,
          args.aliases,
        ),
      ),
    );

class _BrowserController extends Notifier<_BrowserState> {
  _BrowserController(this.initial);
  final ProjectFilter initial;
  @override
  _BrowserState build() => (filter: initial, compact: false, sheet: false);
  void reset(ProjectFilter filter) =>
      state = (filter: filter, compact: state.compact, sheet: state.sheet);
  void sheet(bool value) =>
      state = (filter: state.filter, compact: state.compact, sheet: value);
  void compact() => state = (
    filter: state.filter,
    compact: !state.compact,
    sheet: state.sheet,
  );
  void set(String key, String? value) {
    final f = state.filter;
    reset(
      ProjectFilter(
        q: key == 'q' ? value ?? '' : f.q,
        status: key == 'status' ? value : f.status,
        type: key == 'type' ? value : f.type,
        region: key == 'region' ? value : f.region,
        province: key == 'province' ? value : f.province,
        developer: key == 'developer' ? value : f.developer,
        price: key == 'price' ? value : f.price,
        sort: key == 'sort' ? value ?? 'default' : f.sort,
      ),
    );
  }

  void clear() => reset(ProjectFilter(sort: state.filter.sort));
  void hint(Suggestion h) {
    set('q', '');
    set(h.kind, h.label);
  }
}

class ProjectBrowser extends ConsumerStatefulWidget {
  const ProjectBrowser({
    super.key,
    this.projects,
    required this.loading,
    this.error,
    required this.onRetry,
    required this.onRefresh,
    required this.onOpen,
    this.aliases = const {},
    this.initial = emptyProjectFilter,
    this.resetKey,
    this.autoFocus = false,
    this.banner,
    this.actionBuilder,
    required this.emptyText,
  });
  final List<PublicProject>? projects;
  final bool loading, autoFocus;
  final Object? error;
  final VoidCallback onRetry;
  final FutureOr<void> Function() onRefresh;
  final ValueChanged<PublicProject> onOpen;
  final Map<String, String> aliases;
  final ProjectFilter initial;
  final String? resetKey;
  final Widget? banner;
  final Widget? Function(PublicProject)? actionBuilder;
  final String emptyText;
  @override
  ConsumerState<ProjectBrowser> createState() => _ProjectBrowserState();
}

class _ProjectBrowserState extends ConsumerState<ProjectBrowser> {
  late final _provider =
      NotifierProvider.autoDispose<_BrowserController, _BrowserState>(
        () => _BrowserController(widget.initial),
      );
  @override
  void didUpdateWidget(covariant ProjectBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(_provider.notifier).reset(widget.initial);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (filter: f, :compact, :sheet) = ref.watch(_provider);
    final control = ref.read(_provider.notifier);
    final list = widget.projects ?? const <PublicProject>[];
    final derived = ref.watch(
      _browserResults((projects: list, filter: f, aliases: widget.aliases)),
    );
    final rows = derived.rows;
    final opts = derived.options;
    final hints = derived.hints;
    final active = activeFilters(f);
    final anyStatus = derived.anyStatus;
    final sortLabel = sorts.firstWhere((s) => s.key == f.sort).label;
    String? picked(String key) => switch (key) {
      'status' => f.status,
      'type' => f.type,
      'region' => f.region,
      'province' =>
        f.province == null
            ? null
            : canonicalProvince(f.province, widget.aliases),
      'developer' => f.developer,
      'price' => f.price,
      _ => null,
    };
    Widget group(String title, String key) {
      final options = opts[key]!;
      if (options.length <= 1 && picked(key) == null) {
        return const SizedBox.shrink();
      }
      if ((key == 'province' || key == 'developer') && options.length > 5) {
        return _SearchableOptions(
          key: ValueKey(key),
          title: title,
          options: options,
          selected: picked(key),
          onPick: (value) =>
              control.set(key, picked(key) == value ? null : value),
        );
      }
      return FilterGroup(
        title: title,
        children: [
          for (final o in options)
            Chip(
              label: '${o.label} · ${o.count}',
              active: picked(key) == o.key,
              onPress: () =>
                  control.set(key, picked(key) == o.key ? null : o.key),
            ),
        ],
      );
    }

    final empty = widget.loading
        ? Column(
            spacing: 14,
            children: [
              if (compact)
                const Skeleton(height: 112)
              else
                const ProjectCardSkeleton(),
              if (compact)
                const Skeleton(height: 112)
              else
                const ProjectCardSkeleton(),
            ],
          )
        : widget.error != null
        ? ErrorBox(error: widget.error, onRetry: widget.onRetry)
        : active.isNotEmpty || f.q.trim().isNotEmpty
        ? Empty(
            icon: Ionicons.searchOutline,
            text:
                'Không có dự án khớp. Thử từ khoá ngắn hơn hoặc bỏ bớt bộ lọc.',
            action: (label: 'Xoá tìm kiếm & bộ lọc', onPress: control.clear),
          )
        : Empty(icon: Ionicons.businessOutline, text: widget.emptyText);
    return Stack(
      children: [
        ListScreen<PublicProject>(
          data: rows,
          keyOf: (p) => p.id,
          top: SearchBar(
            value: f.q,
            onChangeText: (q) => control.set('q', q),
            placeholder: 'Tên dự án, khu vực, chủ đầu tư…',
            maxLength: 60,
            autoFocus: widget.autoFocus,
            onFilter: () => control.sheet(true),
            filterCount: active.length,
          ),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              ?widget.banner,
              if (rows.isNotEmpty && widget.error != null)
                ErrorBox(error: widget.error, onRetry: widget.onRetry),
              if (hints.isNotEmpty)
                Card(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final h in hints)
                      Semantics(
                        label:
                            'Lọc theo ${h.kind == 'province' ? 'khu vực' : 'chủ đầu tư'} ${h.label}, ${h.count} dự án',
                        button: true,
                        excludeSemantics: true,
                        onTap: () => control.hint(h),
                        child: ListItem(
                          icon: h.kind == 'province'
                              ? Ionicons.locationOutline
                              : Ionicons.businessOutline,
                          title: h.label,
                          right: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 12,
                            children: [
                              Muted('${h.count} dự án'),
                              const Icon(
                                Ionicons.arrowForward,
                                size: 16,
                                color: c.subtle,
                              ),
                            ],
                          ),
                          onPress: () => control.hint(h),
                        ),
                      ),
                  ],
                ),
              if (list.isNotEmpty)
                ChipRail(
                  children: [
                    Chip(
                      label: 'Tất cả · $anyStatus',
                      active: f.status == null,
                      onPress: () => control.set('status', null),
                    ),
                    for (final o in opts['status']!)
                      Chip(
                        label: '${o.label} · ${o.count}',
                        active: f.status == o.key,
                        color: Color(
                          int.parse(
                            projectStatus[o.key]!.color.replaceFirst('#', 'ff'),
                            radix: 16,
                          ),
                        ),
                        onPress: () => control.set(
                          'status',
                          f.status == o.key ? null : o.key,
                        ),
                      ),
                  ],
                ),
              if (active.any((a) => a.key != 'status'))
                ChipRail(
                  children: [
                    for (final a in active.where((a) => a.key != 'status'))
                      Chip(
                        label: a.label,
                        active: true,
                        trailing: Ionicons.close,
                        onPress: () => control.set(a.key, null),
                      ),
                    Chip(
                      label: 'Xoá hết',
                      icon: Ionicons.refresh,
                      onPress: control.clear,
                    ),
                  ],
                ),
              if (list.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          '${rows.length} dự án',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Button(
                        title: sortLabel,
                        kind: 'link',
                        size: 'sm',
                        icon: Ionicons.swapVertical,
                        accessibilityLabel: 'Sắp xếp: $sortLabel',
                        onPress: () => control.sheet(true),
                      ),
                    ),
                    IconButton(
                      icon: compact
                          ? Ionicons.albumsOutline
                          : Ionicons.listOutline,
                      label: compact
                          ? 'Xem dạng thẻ lớn'
                          : 'Xem dạng danh sách gọn',
                      onPress: control.compact,
                    ),
                  ],
                ),
            ],
          ),
          empty: empty,
          renderItem: (p) => compact
              ? ProjectRow(
                  p: p,
                  onPress: () => widget.onOpen(p),
                  action: widget.actionBuilder?.call(p),
                )
              : ProjectCard(
                  p: p,
                  onPress: () => widget.onOpen(p),
                  action: widget.actionBuilder?.call(p),
                ),
          onRefresh: widget.onRefresh,
          footer: ref.watch(projectCompareProvider).isNotEmpty
              ? const SizedBox(height: 72)
              : null,
        ),
        const CompareDock(),
        Sheet(
          visible: sheet,
          onClose: () => control.sheet(false),
          title: 'Lọc & sắp xếp',
          footer: ButtonGroup(
            spacing: 10,
            children: [
              Button(
                title: 'Xoá lọc',
                kind: 'secondary',
                disabled: active.isEmpty,
                onPress: control.clear,
              ),
              Button(
                title: 'Xem ${rows.length} dự án',
                onPress: () => control.sheet(false),
              ),
            ],
          ),
          children: [
            SearchBar(
              value: f.q,
              onChangeText: (q) => control.set('q', q),
              placeholder: 'Gõ tên dự án…',
              maxLength: 60,
            ),
            group('Miền', 'region'),
            group('Tỉnh / thành', 'province'),
            group('Chủ đầu tư', 'developer'),
            group('Loại hình', 'type'),
            group('Khoảng giá', 'price'),
            group('Giai đoạn', 'status'),
            FilterGroup(
              title: 'Sắp xếp',
              children: [
                for (final s in sorts)
                  Chip(
                    label: s.label,
                    active: f.sort == s.key,
                    onPress: () => control.set('sort', s.key),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchableOptions extends StatefulWidget {
  const _SearchableOptions({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onPick,
  });
  final String title;
  final List<Option> options;
  final String? selected;
  final ValueChanged<String> onPick;
  @override
  State<_SearchableOptions> createState() => _SearchableOptionsState();
}

class _SearchableOptionsState extends State<_SearchableOptions> {
  bool expanded = false;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final matches = widget.options
        .where(
          (o) =>
              o.key == widget.selected || fold(o.label).contains(fold(query)),
        )
        .toList();
    final rows = expanded
        ? matches
        : [
            ...matches.where((o) => o.key == widget.selected),
            ...matches.where((o) => o.key != widget.selected).take(5),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (expanded)
          SearchBar(
            value: query,
            onChangeText: (value) => setState(() => query = value),
            placeholder: 'Tìm ${widget.title.toLowerCase()}…',
          ),
        FilterGroup(
          title: widget.title,
          children: [
            for (final o in rows)
              Chip(
                label: '${o.label} · ${o.count}',
                active: widget.selected == o.key,
                onPress: () => widget.onPick(o.key),
              ),
          ],
        ),
        Button(
          kind: 'link',
          title: expanded
              ? 'Thu gọn ${widget.title.toLowerCase()}'
              : 'Xem thêm ${widget.title.toLowerCase()} (${matches.length - rows.length})',
          onPress: () => setState(() => expanded = !expanded),
        ),
      ],
    );
  }
}
