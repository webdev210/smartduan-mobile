import 'package:ionicons/ionicons.dart';

import 'dart:io';

import 'package:flutter/services.dart';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/errors.dart';
import '../../ui/in_app.dart';
import '../../ui/kit.dart' as kit;
import '../../ui/tour_frame.dart';

// Step S has isHttp/inAppDestination but no viewer decision. Keep the RN
// viewer-specific rule here instead of modifying the shared layer.
String viewerNavigation(String url, bool top, {required bool android}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return 'block';
  if (['file', 'content', 'javascript'].contains(uri.scheme)) return 'block';
  if (['about', 'data', 'blob'].contains(uri.scheme)) return 'allow';
  if (isHttp(url) && uri.host.isNotEmpty) {
    return android && top && isFileUrl(url) ? 'download' : 'allow';
  }
  return 'external';
}

String downloadFilename(String url, String? disposition) {
  final extended = RegExp(
    "filename\\*=UTF-8''([^;]+)",
    caseSensitive: false,
  ).firstMatch(disposition ?? '')?.group(1);
  final plain = RegExp(
    r'filename\s*=\s*"?([^";]+)',
    caseSensitive: false,
  ).firstMatch(disposition ?? '')?.group(1);
  var name =
      extended ?? plain ?? Uri.parse(url).pathSegments.lastOrNull ?? 'document';
  try {
    name = Uri.decodeComponent(name);
  } on FormatException {
    /* Retain literal filename. */
  }
  name = name
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[<>:"|?*\x00-\x1f]'), '_')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty ||
      RegExp(
        r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(name)) {
    name = 'document';
  }
  return name.length > 180 ? name.substring(name.length - 180) : name;
}

/// A separate, unauthenticated client: public file hosts never receive API tokens.
final viewerFileProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  url,
) async {
  if (!isHttp(url) || Uri.tryParse(url)?.host.isNotEmpty != true) {
    throw const FormatException('Invalid file URL');
  }
  final client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  final cancel = CancelToken();
  ref.onDispose(() {
    cancel.cancel();
    client.close(force: true);
  });
  final response = await client.get<ResponseBody>(
    url,
    options: Options(responseType: ResponseType.stream),
    cancelToken: cancel,
  );
  return saveViewerFile(response, url);
}, retry: (_, _) => null);

Future<String> saveViewerFile(
  Response<ResponseBody> response,
  String url, {
  int maxBytes = 200 * 1024 * 1024,
}) async {
  const tooLarge = ApiError(
    413,
    'file_too_large',
    'File quá lớn để mở trong ứng dụng.',
  );
  final stream = response.data!.stream;
  final length = int.tryParse(response.headers.value('content-length') ?? '');
  if (length != null && length > maxBytes) {
    await stream.listen(null).cancel();
    throw tooLarge;
  }
  final name = downloadFilename(
    url,
    response.headers.value('content-disposition'),
  );
  final directory = await (await getTemporaryDirectory()).createTemp('viewer-');
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  try {
    final sink = await file.open(mode: FileMode.write);
    try {
      var received = 0;
      await for (final chunk in stream) {
        received += chunk.length;
        if (received > maxBytes) throw tooLarge;
        await sink.writeFrom(chunk);
      }
    } finally {
      await sink.close();
    }
    return file.path;
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    this.url,
    this.title = 'Xem',
    this.file = false,
  });
  final String? url;
  final String title;
  final bool file;
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  bool openFile = false;
  String? source;
  @override
  void initState() {
    super.initState();
    _setSource();
  }

  void _setSource() {
    source =
        isHttp(widget.url) && Uri.tryParse(widget.url!)?.host.isNotEmpty == true
        ? widget.url
        : null;
  }

  @override
  void didUpdateWidget(ViewerScreen old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      openFile = false;
      _setSource();
    }
  }

  @override
  Widget build(BuildContext context) {
    final android = Theme.of(context).platform == TargetPlatform.android;
    final src = source;
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ViewerSafeArea(
            child: Scaffold(
              appBar: AppBar(
                leading: Tooltip(
                  message: 'Quay lại',
                  child: BackButton(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                ),
                title: Tooltip(
                  message: widget.title.isEmpty ? 'Xem' : widget.title,
                  child: Text(widget.title.isEmpty ? 'Xem' : widget.title),
                ),
                actions: [
                  if (!android &&
                      !openFile &&
                      src != null &&
                      (widget.file || isFileUrl(src)))
                    IconButton(
                      tooltip: 'Chia sẻ tài liệu',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Ionicons.shareSocialOutline),
                      onPressed: () => setState(() => openFile = true),
                    ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: src == null
                    ? const kit.Screen(
                        children: [
                          kit.Notice(tone: 'warn', text: 'Link không hợp lệ.'),
                        ],
                      )
                    : (android || openFile) && (widget.file || isFileUrl(src))
                    ? _FileOpen(key: ValueKey(src), url: src)
                    : PublicWebView(
                        url: src,
                        title: widget.title,
                        navigation: (url, top) {
                          final verdict = viewerNavigation(
                            url,
                            top,
                            android: android,
                          );
                          if (verdict == 'download') {
                            setState(() => source = url);
                          }
                          return verdict;
                        },
                        onOpen: (url) async {
                          try {
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {
                            /* RN best effort. */
                          }
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileOpen extends ConsumerStatefulWidget {
  const _FileOpen({super.key, required this.url});
  final String url;
  @override
  ConsumerState<_FileOpen> createState() => _FileOpenState();
}

class _FileOpenState extends ConsumerState<_FileOpen> {
  String? shared;
  bool shareFailed = false, sharing = false;
  Future<void> _share(String path) async {
    if (sharing) return;
    setState(() {
      sharing = true;
      shareFailed = false;
    });
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => shareFailed = true);
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(viewerFileProvider(widget.url));
    if (value.asData?.value case final path?) {
      if (shared != path) {
        shared = path;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _share(path);
        });
      }
    }
    return kit.Screen(
      children: [
        kit.AsyncView(
          value: value,
          onRetry: () => ref.invalidate(viewerFileProvider(widget.url)),
          builder: (path) => kit.Card(
            children: [
              const kit.Muted(
                'Đã tải file về máy. Chọn ứng dụng để xem (Drive, trình đọc PDF…).',
              ),
              if (shareFailed)
                const kit.Notice(
                  tone: 'error',
                  text: 'Đã tải file; chưa mở được chia sẻ. Thử lại bằng file đã tải.',
                ),
              kit.Button(
                title: 'Mở hoặc chia sẻ tài liệu',
                icon: Ionicons.shareSocialOutline,
                loading: sharing,
                onPress: () => _share(path),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
