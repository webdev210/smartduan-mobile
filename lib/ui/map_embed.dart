import 'package:material_ui/material_ui.dart';

import '../config.dart';
import 'basket.dart';
import 'in_app.dart';
import 'kit.dart' show Button;
import 'tour_frame.dart';

class MapEmbed extends StatelessWidget {
  const MapEmbed({
    super.key,
    required this.lat,
    required this.lng,
    required this.name,
  });
  final Object? lat, lng;
  final String name;
  @override
  Widget build(BuildContext context) {
    final src = mapEmbedUrl(lat, lng);
    if (src.isEmpty) return const SizedBox.shrink();
    final parent = webUrl.isEmpty ? 'https://smartduan.vn' : webUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 240,
            child: PublicWebView(
              html: frameHtml(src, 'Bản đồ $name'),
              baseUrl: parent,
              title: 'Bản đồ vị trí $name',
              navigation: (url, top) => frameNavigation(url, top, parent),
              onOpen: (url) => openInApp(context, url, 'Bản đồ $name'),
            ),
          ),
        ),
        Button(
          kind: 'link',
          title: 'Xem bản đồ lớn hơn',
          onPress: () => openInApp(
            context,
            'https://www.google.com/maps?q=${Uri.parse(src).queryParameters['q']}',
            'Bản đồ $name',
          ),
        ),
      ],
    );
  }
}
