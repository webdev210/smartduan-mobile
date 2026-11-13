import 'dart:math' as math;

import 'package:ionicons/ionicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'in_app.dart';
import 'kit.dart' show Button;
import 'project_card.dart';
import 'tour.dart';
import 'tour_frame.dart';
import 'theme.dart' as c;

class Tour360 extends StatefulWidget {
  const Tour360({
    super.key,
    required this.url,
    required this.name,
    required this.cover,
  });
  final String url, name;
  final String? cover;
  @override
  State<Tour360> createState() => _Tour360State();
}

class _Tour360State extends State<Tour360> {
  bool playing = false;
  @override
  void didUpdateWidget(Tour360 old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) playing = false;
  }

  @override
  Widget build(BuildContext context) {
    final embed = tourEmbedUrl(widget.url);
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        math.max(media.padding.top, media.viewPadding.top) -
        math.max(media.padding.bottom, media.viewPadding.bottom);
    if (embed == null) {
      return ViewerSafeArea(
        child: Button(
          kind: 'secondary',
          icon: Ionicons.cubeOutline,
          title: 'Xem tour 360°',
          onPress: () =>
              openInApp(context, widget.url, 'Tour 360° ${widget.name}'),
        ),
      );
    }
    void fullscreen() => context.push(
      Uri(
        path: '/tour-360',
        queryParameters: {'url': embed, 'name': widget.name},
      ).toString(),
    );
    return ViewerSafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: availableHeight * .65),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: playing
                    ? TourFrame(url: embed, title: 'Tour 360° ${widget.name}')
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ProjectMedia(name: widget.name, uri: widget.cover),
                          Semantics(
                            button: true,
                            label: 'Xem tour 360° ${widget.name}',
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () => setState(() => playing = true),
                              child: ColoredBox(
                                color: Colors.black45,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  spacing: 12,
                                  children: [
                                    const Icon(
                                      Ionicons.cubeOutline,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 8,
                                      children: [
                                        Icon(
                                          Ionicons.play,
                                          size: 14,
                                          color: c.text,
                                        ),
                                        Text(
                                          'Xem tour 360°',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      'Kéo để nhìn quanh · chụm hai ngón để phóng to',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 12,
                            left: 12,
                            child: Text(
                              '360°',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Semantics(
                              label: 'Xem tour 360° toàn màn hình',
                              button: true,
                              excludeSemantics: true,
                              child: IconButton(
                                tooltip: 'Xem tour 360° toàn màn hình',
                                onPressed: fullscreen,
                                icon: const Icon(
                                  Ionicons.expandOutline,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (playing)
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Button(
                    icon: Ionicons.expandOutline,
                    title: 'Mở rộng',
                    accessibilityLabel: 'Xem tour 360° toàn màn hình',
                    onPress: fullscreen,
                  ),
                ),
                Expanded(
                  child: Button(
                    icon: Ionicons.close,
                    title: 'Đóng tour',
                    accessibilityLabel: 'Đóng tour 360°',
                    kind: 'secondary',
                    onPress: () => setState(() => playing = false),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
