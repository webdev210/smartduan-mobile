import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/sales.dart';
import '../../api/units.dart' show fetchEnumsProvider;
import '../../api/unit_compare.dart' show unitCompareProvider;
import '../../auth/session.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/in_app.dart';

class CompareUnitsScreen extends ConsumerStatefulWidget {
  const CompareUnitsScreen({super.key});
  @override
  ConsumerState<CompareUnitsScreen> createState() => _CompareUnitsScreenState();
}

class _CompareUnitsScreenState extends ConsumerState<CompareUnitsScreen> {
  bool busy = false;
  Object? error;
  final headingScroll = ScrollController();
  final valuesScroll = ScrollController();
  @override
  void initState() {
    super.initState();
    headingScroll.addListener(() => sync(headingScroll, valuesScroll));
    valuesScroll.addListener(() => sync(valuesScroll, headingScroll));
  }

  void sync(ScrollController from, ScrollController to) {
    if (to.hasClients && from.offset != to.offset) to.jumpTo(from.offset);
  }

  @override
  void dispose() {
    headingScroll.dispose();
    valuesScroll.dispose();
    super.dispose();
  }

  Widget _comparison(
    BuildContext context,
    CompareSet set,
    Map<String, String>? directions,
  ) {
    if (set.units.isEmpty) {
      return const kit.Screen(
        children: [
          kit.Empty(
            text: 'Chưa có căn nào. Mở chi tiết căn → “Thêm vào so sánh”.',
          ),
        ],
      );
    }
    final rows = <(String, String Function(CompareUnit))>[
      ('Giá tốt nhất', (u) => fmtPrice(u.priceMin)),
      ('Thông thuỷ', (u) => fmtArea(u.areaNet)),
      ('Hướng', (u) => directions?[u.direction] ?? dash(u.direction)),
      ('Trạng thái', (u) => statusLabel[u.status] ?? u.status),
      ('Dự án', (u) => u.project?.name ?? '—'),
      ('Loại', (u) => dash(u.unitType)),
      ('PN', (u) => dash(u.bedrooms)),
      ('Tim tường', (u) => fmtArea(u.areaGross)),
      (
        'Đơn giá',
        (u) => u.pricePerSqm == null || u.pricePerSqm == ''
            ? '—'
            : '${fmtPrice(u.pricePerSqm)}/m²',
      ),
      (
        'CSBH',
        (u) => u.policy?.url?.isNotEmpty == true
            ? 'Chính sách: ${u.policy!.name}'
            : u.policy?.name ?? '—',
      ),
    ];
    const labelWidth = 96.0, unitWidth = 180.0;
    const style = TextStyle(fontSize: 15, height: 1.5);
    double textHeight(String text, double width) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: width - 16);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final heights = [
      for (final (label, value) in rows)
        [
              textHeight(label, labelWidth),
              for (final u in set.units) textHeight(value(u), unitWidth),
            ].reduce(math.max) +
            32,
    ];
    Widget cell(String text, double width, double height) => SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text, style: style),
      ),
    );
    final headerHeight =
        set.units
            .map((u) => textHeight(u.publicCode ?? u.code, unitWidth))
            .reduce(math.max) +
        88;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (set.removed.isNotEmpty)
          kit.Notice(
            tone: 'warn',
            text:
                '${set.removed.length} căn đã bị gỡ khỏi danh sách (không còn xem được).',
          ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: kit.Muted('Vuốt ngang để xem thêm căn.'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: labelWidth),
            Expanded(
              child: SingleChildScrollView(
                controller: headingScroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final u in set.units)
                      SizedBox(
                        width: unitWidth,
                        height: headerHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextButton(
                              onPressed: () => context.push(
                                '/can/${Uri.encodeComponent(u.id)}',
                              ),
                              child: Text(u.publicCode ?? u.code, style: style),
                            ),
                            kit.Button(
                              title: 'Bỏ',
                              kind: 'link',
                              disabled: busy,
                              onPress: () => remove(u.id),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(fetchCompareProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        cell(rows[i].$1, labelWidth, heights[i]),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: valuesScroll,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final u in set.units)
                            Column(
                              children: [
                                for (var i = 0; i < rows.length; i++)
                                  if (rows[i].$1 == 'CSBH' &&
                                      u.policy?.url?.isNotEmpty == true)
                                    SizedBox(
                                      width: unitWidth,
                                      height: heights[i],
                                      child: TextButton(
                                        onPressed: () => openInApp(
                                          context,
                                          u.policy!.url!,
                                          u.policy!.name,
                                        ),
                                        child: Text(
                                          rows[i].$2(u),
                                          style: style,
                                        ),
                                      ),
                                    )
                                  else
                                    cell(rows[i].$2(u), unitWidth, heights[i]),
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
        ),
      ],
    );
  }

  Future<void> remove(String id) async {
    if (busy) return;
    final session = ref.read(sessionProvider);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(removeCompareProvider)(id);
      if (mounted && identical(session, ref.read(sessionProvider))) {
        ref.invalidate(fetchCompareProvider);
        ref.invalidate(unitCompareProvider);
      }
    } catch (e) {
      if (mounted && identical(session, ref.read(sessionProvider))) {
        setState(() => error = e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(fetchCompareProvider);
    final directions = ref.watch(fetchEnumsProvider).value?.directionLabels;
    ref.listen(sessionProvider, (_, _) {
      if (mounted) setState(() => error = null);
    });
    return Scaffold(
      appBar: AppBar(title: const Text('So sánh căn')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) kit.ErrorBox(error: error),
                Expanded(
                  child: kit.AsyncView(
                    value: query,
                    onRetry: () => ref.invalidate(fetchCompareProvider),
                    builder: (set) => _comparison(context, set, directions),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
