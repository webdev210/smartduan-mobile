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
Widget _quiet(String text) =>
    kit.Muted(text, style: const TextStyle(fontSize: 14));
String? _handover(Map<String, dynamic>? overview) {
  final value = overview?['handover'] ?? overview?['ban_giao'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

final _rows = <(String, Widget Function(PublicProject))>[
  (
    'Giá từ',
    (p) => Text(
      priceLabel(p.priceFrom),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: c.brand,
      ),
    ),
  ),
  (
    'Loại hình',
    (p) => p.projectType != null
        ? Text(typeLabel[p.projectType] ?? p.projectType!)
        : _quiet(_none),
  ),
  (
    'Trạng thái',
    (p) {
      final st = projectStatus[p.status];
      return st == null
          ? _quiet(_none)
          : kit.Pill(
              soft: true,
              label: st.label,
              color: Color(
                int.parse(st.color.replaceFirst('#', 'ff'), radix: 16),
              ),
            );
    },
  ),
  (
    'Bàn giao',
    (p) => switch (_handover(p.overviewJson)) {
      final String value => Text(value),
      null => _quiet(_none),
    },
  ),
  (
    'Chủ đầu tư',
    (p) => switch (p.developer?.name) {
      final String value => Text(value),
      null => _quiet(_none),
    },
  ),
  (
    'Khu vực',
    (p) {
      final place = [
        p.ward,
        p.district,
        p.province,
      ].whereType<String>().where((s) => s.isNotEmpty).toSet().join(', ');
      return place.isEmpty ? _quiet(_none) : Text(place);
    },
  ),
  (
    'Tiện ích',
    (p) {
      final list = amenitiesOf(p.overviewJson);
      return list.isEmpty
          ? _quiet(_none)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text('${list.length} tiện ích'),
                for (final a in list.take(5))
                  kit.Muted(a, style: const TextStyle(fontSize: 13)),
              ],
            );
    },
  ),
  (
    'Hoạt động 7 ngày',
    (p) => p.activity7d > 0
        ? Text('${p.activity7d} cập nhật căn')
        : _quiet('Chưa có thay đổi'),
  ),
  (
    'Tour 360°',
    (p) => p.hasTour360 ? const Text('Có tour công khai') : _quiet('Chưa có'),
  ),
];

class ProjectCompareScreen extends ConsumerStatefulWidget {
  const ProjectCompareScreen({super.key});
  @override
  ConsumerState<ProjectCompareScreen> createState() =>
      _ProjectCompareScreenState();
}

class _ProjectCompareScreenState extends ConsumerState<ProjectCompareScreen> {
  bool picker = false;
  @override
  Widget build(BuildContext context) {
    final codes = ref.watch(projectCompareProvider);
    final queries = [
      for (final code in codes) ref.watch(fetchPublicProjectProvider(code)),
    ];
    final projects = [for (final q in queries) q.asData?.value];
    final pick = ComparePicker(
      visible: picker,
      onClose: () => setState(() => picker = false),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('So sánh dự án')),
      body: Stack(
        children: [
          kit.Screen(
            children: codes.length < 2
                ? [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        const kit.Muted(
                          'Chọn ít nhất 2 dự án để so sánh giá, loại hình, bàn giao, tiện ích… Trên thẻ dự án: bấm “So sánh”, hoặc giữ nút để chọn nhiều dự án.',
                        ),
                        kit.Button(
                          title: 'Chọn dự án',
                          onPress: () => setState(() => picker = true),
                        ),
                      ],
                    ),
                  ]
                : [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width:
                              projects.length * 192.0 +
                              (projects.length > 1
                                  ? (projects.length - 1) * 12
                                  : 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 12,
                                children: [
                                  for (var i = 0; i < codes.length; i++)
                                    Expanded(
                                      key: ValueKey('compare-${codes[i]}'),
                                      child: switch (projects[i]) {
                                        null => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const AspectRatio(
                                              aspectRatio: 16 / 10,
                                              child: kit.Skeleton(height: 120),
                                            ),
                                            Text(codes[i]),
                                            Text(
                                              queries[i].hasError
                                                  ? 'Không tải được dự án (có thể đã ngừng công khai).'
                                                  : 'Đang tải dự án…',
                                            ),
                                            if (queries[i].hasError) ...[
                                              kit.Button(
                                                title: 'Thử lại dự án lỗi',
                                                kind: 'link',
                                                onPress: () => ref.invalidate(
                                                  fetchPublicProjectProvider(
                                                    codes[i],
                                                  ),
                                                ),
                                              ),
                                              kit.Button(
                                                title: 'Bỏ dự án lỗi',
                                                kind: 'link',
                                                onPress: () => ref
                                                    .read(
                                                      projectCompareProvider
                                                          .notifier,
                                                    )
                                                    .remove(codes[i]),
                                              ),
                                            ],
                                          ],
                                        ),
                                        final p => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          spacing: 8,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: AspectRatio(
                                                aspectRatio: 16 / 10,
                                                child: ProjectMedia(
                                                  compact: true,
                                                  name: p.name,
                                                  uri: p.coverUrl,
                                                ),
                                              ),
                                            ),
                                            Semantics(
                                              link: true,
                                              child: InkWell(
                                                onTap: () => context.push(
                                                  '/cong-khai/${Uri.encodeComponent(p.code)}',
                                                ),
                                                child: Text(
                                                  p.name,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    height: 20 / 15,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Semantics(
                                              button: true,
                                              label:
                                                  'Bỏ ${p.name} khỏi so sánh',
                                              onTap: () => ref
                                                  .read(
                                                    projectCompareProvider
                                                        .notifier,
                                                  )
                                                  .remove(p.code),
                                              excludeSemantics: true,
                                              child: InkWell(
                                                onTap: () => ref
                                                    .read(
                                                      projectCompareProvider
                                                          .notifier,
                                                    )
                                                    .remove(p.code),
                                                child: const Padding(
                                                  padding: EdgeInsets.zero,
                                                  child: SizedBox(
                                                    width: 48,
                                                    height: 48,
                                                    child: Center(
                                                      child: Text(
                                                        'Bỏ',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: c.brand,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      },
                                    ),
                                ],
                              ),
                              for (final (label, cell) in _rows)
                                Container(
                                  margin: const EdgeInsets.only(top: 14),
                                  padding: const EdgeInsets.only(top: 14),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: c.border,
                                        width: .5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    spacing: 8,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: c.muted,
                                        ),
                                      ),
                                      DefaultTextStyle(
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: c.text,
                                          height: 20 / 14,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          spacing: 12,
                                          children: [
                                            for (final p in projects)
                                              Expanded(
                                                child: p == null
                                                    ? _quiet(
                                                        'Chưa tải được dữ liệu',
                                                      )
                                                    : cell(p),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
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
          ),
          pick,
        ],
      ),
    );
  }
}
