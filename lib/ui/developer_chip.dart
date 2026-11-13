import 'network_image.dart';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import 'catalog.dart';
import 'theme.dart' as c;

String developerPath({
  required String id,
  required String name,
  String? slug,
}) => slug != null && slug.isNotEmpty
    ? '/chu-dau-tu/${Uri.encodeComponent(slug)}'
    : Uri(
        path: '/kham-pha',
        queryParameters: {'developer_id': id, 'developer': name},
      ).toString();
void openDeveloper(
  BuildContext context, {
  required String id,
  required String name,
  String? slug,
}) => context.push(developerPath(id: id, name: name, slug: slug));

class DeveloperChip extends StatelessWidget {
  const DeveloperChip({
    super.key,
    required this.name,
    required this.logo,
    required this.onPress,
  });
  final String name;
  final String? logo;
  final VoidCallback onPress;
  @override
  Widget build(BuildContext context) {
    final uri = mediaUrl(logo);
    const fallback = Icon(Ionicons.businessOutline, size: 16, color: c.muted);
    return Semantics(
      button: true,
      label: 'Dự án của $name',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: c.border,
            width: 1 / MediaQuery.devicePixelRatioOf(context),
          ),
        ),
        child: InkWell(
          onTap: onPress,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.only(left: 6, right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                ClipOval(
                  child: Container(
                    width: 32,
                    height: 32,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: uri == null
                        ? fallback
                        : AppNetworkImage(
                            uri,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => fallback,
                          ),
                  ),
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.text,
                      ),
                    ),
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
