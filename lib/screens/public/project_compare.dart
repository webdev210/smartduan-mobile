import 'package:ionicons/ionicons.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/overview.dart';
import '../../ui/project_card.dart';
import '../../ui/project_compare.dart';
import '../../ui/project_compare_kit.dart';
import '../../ui/project_filter.dart';
import '../../ui/theme.dart' as c;

const _none = 'Chưa cập nhật';
String? _handover(Map<String, dynamic>? overview) {
  final value = overview?['handover'] ?? overview?['ban_giao'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

final _rows = <(String, String Function(PublicProject))>[
  ('Giá', (p) => priceLabel(p.priceFrom)),
  ('Loại hình', (p) => typeLabel[p.projectType] ?? p.projectType ?? _none),
  ('Trạng thái', (p) => projectStatus[p.status]?.label ?? _none),
  ('Bàn giao', (p) => _handover(p.overviewJson) ?? _none),
  ('Chủ đầu tư', (p) => p.developer?.name ?? _none),
  (
    'Khu vực',
    (p) {
      final place = [
        p.ward,
        p.district,
        p.province,
      ].whereType<String>().where((s) => s.isNotEmpty).toSet().join(', ');
      return place.isEmpty ? _none : place;
    },
  ),
  (
    'Tiện ích',
    (p) {
      final list = amenitiesOf(p.overviewJson);
      return list.isEmpty
          ? _none
          : ['${list.length} tiện ích', ...list.take(5)].join('\n');
    },
  ),
  (
    'Hoạt động 7 ngày',
    (p) =>
        p.activity7d > 0 ? '${p.activity7d} cập nhật căn' : 'Chưa có thay đổi',
  ),
  ('Tour 360°', (p) => p.hasTour360 ? 'Có tour công khai' : 'Chưa có'),
];

class ProjectCompareScreen extends ConsumerStatefulWidget {
  const ProjectCompareScreen({super.key});
  @override
  ConsumerState<ProjectCompareScreen> createState() =>
      _ProjectCompareScreenState();
}

class _ProjectCompareScreenState extends ConsumerState<ProjectCompareScreen> {
  bool picker = false;
  final headingScroll = ScrollController();
  final valuesScroll = ScrollController();
  @override
  void initState() {
    super.initState();
    headingScroll.addListener(() => _sync(headingScroll, valuesScroll));
    valuesScroll.addListener(() => _sync(valuesScroll, headingScroll));
  }

  void _sync(ScrollController from, ScrollController to) {
    if (to.hasClients && to.offset != from.offset) to.jumpTo(from.offset);
  }

  @override
  void dispose() {
    headingScroll.dispose();
    valuesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codes = ref.watch(projectCompareProvider);
    final queries = [
      for (final code in codes) ref.watch(fetchPublicProjectProvider(code)),
    ];
    final projects = [for (final query in queries) query.value];
    void remove(String code) =>
        ref.read(projectCompareProvider.notifier).remove(code);
    const labelWidth = 104.0, projectWidth = 192.0;
    final style = Theme.of(context).textTheme.bodyMedium!
        .merge(const TextStyle(fontSize: 14, height: 20 / 14, color: c.text));
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double textHeight(
      String value,
      double width, {
      int? maxLines,
      bool bold = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: style.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textScaler: scaler,
        textDirection: direction,
        maxLines: maxLines,
      )..layout(maxWidth: width - 24);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final heights = [
      for (final (i, (label, value)) in _rows.indexed)
        [
              textHeight(label, labelWidth),
              for (final p in projects)
                textHeight(
                  p == null ? 'Chưa tải được dữ liệu' : value(p),
                  projectWidth,
                  bold: i == 0,
                ),
            ].reduce((a, b) => a > b ? a : b) +
            24.5, // Cell padding plus the bottom divider.
    ];
    Widget cell(
      String text,
      double width,
      double height, {
      Color? color,
      bool bold = false,
    }) => Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in text.split('\n'))
            Text(
              line,
              style: style.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
        ],
      ),
    );
    Widget heading(int i, double height) => SizedBox(
      key: ValueKey('compare-${codes[i]}'),
      width: projectWidth,
      height: height,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (projects[i] case final p?) ...[
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: c.link,
                ),
                onPressed: () =>
                    context.push('/cong-khai/${Uri.encodeComponent(p.code)}'),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: ProjectMedia(
                        compact: true,
                        name: p.name,
                        uri: p.coverUrl,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Tooltip(
                        message: p.name,
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                            color: c.link,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              kit.Button(
                title: 'Bỏ',
                kind: 'link',
                accessibilityLabel: 'Bỏ ${p.name} khỏi so sánh',
                onPress: () => remove(p.code),
              ),
            ] else ...[
              Text(codes[i], style: style),
              if (queries[i].hasError)
                kit.Button(
                  title: 'Thử lại dự án lỗi',
                  kind: 'link',
                  onPress: () =>
                      ref.invalidate(fetchPublicProjectProvider(codes[i])),
                ),
              Text(
                queries[i].hasError
                    ? 'Không tải được dự án (có thể đã ngừng công khai).'
                    : 'Đang tải dự án…',
              ),
              if (queries[i].hasError) ...[
                kit.Button(
                  title: 'Bỏ dự án lỗi',
                  kind: 'link',
                  onPress: () => remove(codes[i]),
                ),
              ],
            ],
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('So sánh dự án')),
      body: Stack(
        children: [
          if (codes.length < 2)
            kit.Screen(
              children: [
                const kit.Muted(
                  'Chọn ít nhất 2 dự án để so sánh giá, loại hình, bàn giao, tiện ích… Trên thẻ dự án: bấm “So sánh”, hoặc giữ nút để chọn nhiều dự án.',
                ),
                kit.Button(
                  title: 'Chọn dự án',
                  onPress: () => setState(() => picker = true),
                ),
              ],
            )
          else
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final headerHeight =
                          (textHeight(
                                    'Tên dự án\nTên dự án',
                                    projectWidth,
                                    maxLines: 2,
                                  ) +
                                  72)
                              .clamp(0.0, constraints.maxHeight * .45);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: labelWidth),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: headingScroll,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var i = 0; i < codes.length; i++)
                                        heading(i, headerHeight),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      for (var i = 0; i < _rows.length; i++)
                                        cell(
                                          _rows[i].$1,
                                          labelWidth,
                                          heights[i],
                                          color: c.muted,
                                        ),
                                    ],
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: valuesScroll,
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (final p in projects)
                                            Column(
                                              children: [
                                                for (
                                                  var i = 0;
                                                  i < _rows.length;
                                                  i++
                                                )
                                                  cell(
                                                    p == null
                                                        ? 'Chưa tải được dữ liệu'
                                                        : _rows[i].$2(p),
                                                    projectWidth,
                                                    heights[i],
                                                    color: i == 0
                                                        ? c.brand
                                                        : i == 2 &&
                                                              p != null &&
                                                              projectStatus[p
                                                                      .status] !=
                                                                  null
                                                        ? Color(
                                                            int.parse(
                                                              projectStatus[p
                                                                      .status]!
                                                                  .color
                                                                  .replaceFirst(
                                                                    '#',
                                                                    'ff',
                                                                  ),
                                                              radix: 16,
                                                            ),
                                                          )
                                                        : c.text,
                                                    bold: i == 0,
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          kit.Button(
                            kind: 'secondary',
                            icon: codes.length < 3 ? Ionicons.add : null,
                            title: codes.length < 3
                                ? 'Thêm dự án so sánh'
                                : 'Đổi dự án',
                            onPress: () => setState(() => picker = true),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ComparePicker(
            visible: picker,
            onClose: () => setState(() => picker = false),
          ),
        ],
      ),
    );
  }
}
