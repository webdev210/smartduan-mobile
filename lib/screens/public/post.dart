import '../../ui/network_image.dart';

import 'package:ionicons/ionicons.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/public.dart';
import '../../ui/catalog.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/post_body.dart';
import '../../ui/theme.dart' as c;

const _kindLabel = {
  'news': 'Tin tức',
  'event': 'Sự kiện',
  'guide': 'Hướng dẫn',
};

class PostScreen extends ConsumerWidget {
  const PostScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(fetchPublicPostProvider(slug));
    return Scaffold(
      appBar: AppBar(
        title: Text(_kindLabel[q.asData?.value.kind] ?? 'Bài viết'),
      ),
      body: SafeArea(
        top: false,
        child: kit.Screen(
          children: [
            kit.AsyncView(
              value: q,
              onRetry: () => ref.invalidate(fetchPublicPostProvider(slug)),
              builder: (p) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 18,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      kit.Muted(_kindLabel[p.kind] ?? p.kind),
                      kit.Muted(fmtDate(p.eventAt ?? p.publishedAt)),
                    ],
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 25,
                        height: 32 / 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (p.location case final location?)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Ionicons.locationOutline,
                            size: 16,
                            color: c.muted,
                          ),
                        ),
                        Expanded(child: kit.Muted(location)),
                      ],
                    ),
                  if (mediaUrl(p.coverUrl) case final cover?)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: AppNetworkImage(
                          cover,
                          fit: BoxFit.cover,
                          semanticLabel: p.title,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: c.quiet),
                        ),
                      ),
                    ),
                  PostBody(html: p.body),
                  if (p.project case final project?)
                    kit.Card(
                      onPress: () => context.push(
                        '/cong-khai/${Uri.encodeComponent(project.code)}',
                      ),
                      child: Row(
                        spacing: 12,
                        children: [
                          const Icon(
                            Ionicons.businessOutline,
                            size: 20,
                            color: c.brand,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const kit.Muted('Dự án trong bài'),
                                kit.Body(project.name),
                              ],
                            ),
                          ),
                          const Icon(
                            Ionicons.chevronForward,
                            size: 18,
                            color: c.subtle,
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
    );
  }
}
