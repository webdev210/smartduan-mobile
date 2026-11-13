import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../ui/in_app.dart';
import '../../ui/tour.dart';
import '../../ui/tour_frame.dart';
import '../../ui/kit.dart' show Button;

class Tour360Screen extends StatelessWidget {
  const Tour360Screen({super.key, this.url, this.name = 'Dự án'});
  final String? url;
  final String name;
  @override
  Widget build(BuildContext context) {
    final embed = tourEmbedUrl(url);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ViewerSafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOUR 360°',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Đóng tour 360°',
                      button: true,
                      excludeSemantics: true,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                        icon: const Icon(Ionicons.close),
                        label: const Text('Đóng'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: embed != null
                    ? TourFrame(url: embed, title: 'Tour 360° $name')
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 16,
                          children: [
                            const Text(
                              'Tour 360° này không xem được trong app.',
                              style: TextStyle(color: Colors.white),
                            ),
                            if (isHttp(url))
                              Button(
                                title: 'Mở trang tour',
                                onPress: () =>
                                    openInApp(context, url!, 'Tour 360° $name'),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
