import 'package:material_ui/material_ui.dart';

int imageCacheWidth(double logicalWidth, double devicePixelRatio) =>
    ((logicalWidth * devicePixelRatio / 360).ceil().clamp(1, 4)) * 360;

/// Shares decode sizes across thumbnails while preserving each caller's fallback.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.semanticLabel,
    this.errorBuilder,
    this.loadingBuilder,
  });
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      cacheWidth: imageCacheWidth(
        width ??
            (constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width),
        MediaQuery.devicePixelRatioOf(context),
      ),
    ),
  );
}
