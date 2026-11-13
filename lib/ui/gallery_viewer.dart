import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';

import 'catalog.dart';
import 'network_image.dart';

typedef GalleryImage = ({String url, String? caption});

Future<void> openGallery(
  BuildContext context,
  List<GalleryImage> images, {
  int initialIndex = 0,
}) async {
  if (images.isEmpty) return;
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);
  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => GalleryViewer(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class GalleryViewer extends StatefulWidget {
  const GalleryViewer({super.key, required this.images, this.initialIndex = 0})
    : assert(images.length > 0),
      assert(initialIndex >= 0 && initialIndex < images.length);
  final List<GalleryImage> images;
  final int initialIndex;

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  late final pages = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;
  bool zoomed = false;

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: 'Đóng',
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Ionicons.close, color: Colors.white),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Ảnh ${index + 1} trên ${widget.images.length}',
                    child: ExcludeSemantics(
                      child: Text(
                        '${index + 1} / ${widget.images.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: pages,
                physics: zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: widget.images.length,
                onPageChanged: (value) => setState(() {
                  index = value;
                  zoomed = false;
                }),
                itemBuilder: (_, i) => _GalleryPage(
                  key: ValueKey(i),
                  image: widget.images[i],
                  onZoom: (value) {
                    if (i == index && value != zoomed) {
                      setState(() => zoomed = value);
                    }
                  },
                ),
              ),
            ),
            if (widget.images[index].caption case final caption?
                when caption.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .2,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _GalleryPage extends StatefulWidget {
  const _GalleryPage({super.key, required this.image, required this.onZoom});
  final GalleryImage image;
  final ValueChanged<bool> onZoom;
  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  final transform = TransformationController();
  int attempt = 0;
  bool get zoomed => transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    transform.addListener(changed);
  }

  void changed() => widget.onZoom(zoomed);

  @override
  void dispose() {
    transform.removeListener(changed);
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      onDoubleTap: () => transform.value = zoomed
          ? Matrix4.identity()
          : (Matrix4.identity()
              ..translateByDouble(
                -constraints.maxWidth / 2,
                -constraints.maxHeight / 2,
                0,
                1,
              )
              ..scaleByDouble(2, 2, 1, 1)),
      child: InteractiveViewer(
        transformationController: transform,
        minScale: 1,
        maxScale: 5,
        panEnabled: zoomed,
        child: Center(
          child: AppNetworkImage(
            mediaUrl(widget.image.url) ?? '',
            key: ValueKey(attempt),
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: Text(
                      'Đang tải ảnh…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
            errorBuilder: (_, _, _) => Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Không tải được ảnh.',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => setState(() => attempt++),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
