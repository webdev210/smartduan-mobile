import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart' hide Card, SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/me.dart';
import '../../api/projects.dart';
import '../../api/errors.dart';
import '../../auth/roles.dart';
import '../../auth/session.dart';
import '../../ui/kit.dart' hide Row;
import '../../ui/search.dart';
import '../../ui/regions.dart';
import '../../ui/theme.dart' as c;

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});
  @override
  ConsumerState<InterestsScreen> createState() => _InterestsState();
}

class _InterestsState extends ConsumerState<InterestsScreen> {
  String? region;
  late List<String> ids;
  String q = '';
  bool onlyPicked = false, busy = false;
  late String? initialRegion;
  late Set<String> initialIds;
  bool leaving = false;
  bool get dirty =>
      region != initialRegion ||
      ids.length != initialIds.length ||
      !initialIds.containsAll(ids);
  Object? failure;
  @override
  void initState() {
    super.initState();
    final me = ref.read(sessionProvider).me;
    region = me?['region'] as String?;
    ids = jsonStrings(me?['interested_project_ids']).toList();
    initialRegion = region;
    initialIds = ids.toSet();
  }

  Future<void> leave() async {
    if (leaving || busy) return;
    leaving = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ thay đổi chưa lưu?'),
        scrollable: true,
        content: const Text('Lựa chọn miền và dự án của bạn chưa được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    leaving = false;
    if (discard == true && mounted) {
      setState(() {
        initialRegion = region;
        initialIds = ids.toSet();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
    }
  }

  Future<void> save() async {
    if (busy || region == null || ids.length > 50) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await ref.read(saveInterestsProvider)(
        Interests(region: region, interestedProjectIds: ids),
      );
      if (!mounted) return;
      await ref.read(sessionProvider.notifier).refreshMe();
      if (mounted) {
        setState(() {
          initialRegion = region;
          initialIds = ids.toSet();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) context.pop();
        });
      }
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void reset() => setState(() {
    q = '';
    onlyPicked = false;
  });
  @override
  Widget build(BuildContext context) {
    final allowed = can(ref.watch(sessionProvider).roles, 'view_projects');
    final projects = allowed
        ? ref.watch(fetchAllProjectsProvider)
        : const AsyncData<List<Project>>([]);
    final rows = smartFilter(
      (projects.value ?? [])
          .where((p) => !onlyPicked || ids.contains(p.id))
          .toList(),
      q,
      (p) => [p.name, p.province, p.district, p.developerName],
    );
    return PopScope(
      canPop: !dirty && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && dirty) leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Dự án quan tâm')),
        body: Column(
          children: [
            Expanded(
              child: ListScreen<Project>(
                data: rows,
                keyOf: (p) => p.id,
                top: SearchBar(
                  value: q,
                  onChangeText: (v) => setState(() => q = v),
                  placeholder: 'Tìm dự án để theo dõi…',
                ),
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    const H2('Miền bạn phụ trách'),
                    Segmented(
                      value: region,
                      onChange: (v) {
                        if (!busy) setState(() => region = v);
                      },
                      options: [
                        for (final r in regions)
                          (key: r.key, label: r.label, count: null),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const H2('Dự án quan tâm'),
                        Semantics(
                          label:
                              'Chỉ xem dự án đã chọn, đã chọn ${ids.length} trên 50',
                          selected: onlyPicked,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => onlyPicked = !onlyPicked),
                            icon: Icon(
                              onlyPicked
                                  ? Ionicons.checkbox
                                  : Ionicons.squareOutline,
                              color: c.brand,
                            ),
                            label: Text(
                              'Đã chọn ${ids.length}/50',
                              style: TextStyle(
                                color: ids.length > 50 ? c.danger : c.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                empty: AsyncView(
                  value: projects,
                  onRetry: () => ref.invalidate(fetchAllProjectsProvider),
                  builder: (_) => q.trim().isNotEmpty || onlyPicked
                      ? Empty(
                          icon: Ionicons.searchOutline,
                          text: 'Không có dự án nào khớp.',
                          action: (label: 'Xem tất cả dự án', onPress: reset),
                        )
                      : const Muted('Chưa có dự án để chọn.'),
                ),
                renderItem: (p) {
                  final on = ids.contains(p.id);
                  final subtitle = [
                    p.district,
                    p.province,
                    p.developerName,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
                  return Card(
                    accessibilityLabel:
                        '${p.name}${on ? ', đang theo dõi' : ''}',
                    onPress: busy
                        ? null
                        : () => setState(() {
                            if (on) {
                              ids.remove(p.id);
                            } else if (ids.length < 50) {
                              ids.add(p.id);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Chỉ chọn tối đa 50 dự án. Bỏ chọn một dự án để chọn thêm.',
                                  ),
                                ),
                              );
                            }
                          }),
                    style: on
                        ? BoxDecoration(
                            color: c.brandSoft,
                            border: Border.all(color: c.brand),
                          )
                        : null,
                    child: Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subtitle.isNotEmpty) Muted(subtitle),
                            ],
                          ),
                        ),
                        Icon(
                          on
                              ? Ionicons.checkmarkCircle
                              : Ionicons.ellipseOutline,
                          color: on ? c.brand : c.subtle,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              SafeArea(
                top: false,
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 10,
                        children: [
                          if (failure != null)
                            Notice(tone: 'error', text: errorMessage(failure)),
                          Button(
                            title: 'Lưu',
                            loading: busy,
                            disabled: region == null || ids.length > 50,
                            onPress: save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
