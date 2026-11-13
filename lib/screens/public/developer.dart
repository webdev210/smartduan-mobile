import 'package:ionicons/ionicons.dart';

import '../../ui/network_image.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../ui/catalog.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/project_card.dart';
import '../../ui/project_filter.dart';

class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final dev = ref.watch(fetchPublicDeveloperProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(title: Text(dev.asData?.value.name ?? 'Chủ đầu tư')),
      body: SafeArea(
        top: false,
        child: kit.Screen(
          children: [
            kit.AsyncView(
              value: dev,
              onRetry: () =>
                  ref.invalidate(fetchPublicDeveloperProvider(widget.slug)),
              builder: (d) => kit.Card(
                children: [
                  Row(
                    spacing: 14,
                    children: [
                      if (mediaUrl(d.logoUrl) case final logo?)
                        AppNetworkImage(
                          logo,
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                          semanticLabel: 'Logo ${d.name}',
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(Ionicons.businessOutline),
                          ),
                        ),
                      Expanded(child: kit.H1(d.name)),
                    ],
                  ),
                  if (d.badges.isNotEmpty)
                    kit.Chips(
                      children: [
                        for (final b in d.badges)
                          kit.Chip(icon: Ionicons.ribbonOutline, label: b),
                      ],
                    ),
                  if (d.description case final description?)
                    kit.Body(description),
                  if (d.website case final website?)
                    kit.Button(
                      kind: 'link',
                      icon: Ionicons.globeOutline,
                      title: website,
                      onPress: () => openInApp(context, website, d.name),
                    ),
                ],
              ),
            ),
            if (dev.asData?.value case final d?) _projects(d.id),
          ],
        ),
      ),
    );
  }

  Widget _projects(String id) {
    final provider = listPublicProjectsProvider(
      PublicFilters(developerId: id, perPage: 50),
    );
    final projects = ref.watch(provider);
    return kit.Section(
      title: 'Dự án',
      eyebrow: projects.asData == null
          ? null
          : '${projects.asData!.value.total} dự án',
      child: kit.AsyncView(
        value: projects,
        onRetry: () => ref.invalidate(provider),
        builder: (page) {
          final rows = filterProjects(
            page.data,
            ProjectFilter(q: query),
            const {},
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              if (page.data.length > 4)
                kit.SearchBar(
                  value: query,
                  onChangeText: (s) => setState(() => query = s),
                  placeholder: 'Tìm trong dự án của chủ đầu tư…',
                ),
              for (final p in rows)
                ProjectCard(
                  p: Browsable(
                    id: p.id,
                    name: p.name,
                    status: p.status,
                    code: p.code,
                    coverUrl: p.coverUrl,
                    province: p.province,
                    district: p.district,
                    priceFrom: p.priceFrom,
                    projectType: p.projectType,
                    hasTour360: p.hasTour360,
                    activity7d: p.activity7d,
                  ),
                  onPress: () =>
                      context.push('/cong-khai/${Uri.encodeComponent(p.code)}'),
                ),
              if (page.data.isEmpty)
                const kit.Muted('Chưa có dự án công khai.')
              else if (rows.isEmpty)
                kit.Empty(
                  icon: Ionicons.searchOutline,
                  text: 'Không có dự án nào khớp.',
                  action: (
                    label: 'Xoá từ khoá',
                    onPress: () => setState(() => query = ''),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
