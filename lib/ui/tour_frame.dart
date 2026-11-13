import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'in_app.dart';
import 'kit.dart' show Button, Loading, Notice;
import 'tour.dart';

/// Keep cut-outs protected even when immersive mode clears view padding's
/// visible counterpart. SafeArea consumes the insets so nested viewers don't
/// apply them twice.
class ViewerSafeArea extends StatelessWidget {
  const ViewerSafeArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: EdgeInsets.fromLTRB(
          math.max(media.padding.left, media.viewPadding.left),
          math.max(media.padding.top, media.viewPadding.top),
          math.max(media.padding.right, media.viewPadding.right),
          math.max(media.padding.bottom, media.viewPadding.bottom),
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

/// Shared native setup for the four public WebViews. Configure the delegate and
/// local-access restrictions before loading any content; no JavaScript bridge.
class PublicWebView extends StatefulWidget {
  const PublicWebView({
    super.key,
    this.url,
    this.html,
    this.baseUrl,
    required this.navigation,
    required this.title,
    this.javascript = true,
    this.onOpen,
    this.loadingText,
    this.errorText = 'Không tải được trang. Kiểm tra mạng rồi thử lại.',
    this.errorAction,
    this.dark = false,
  });
  final String? url, html, baseUrl, loadingText;
  final String title, errorText;
  final bool javascript, dark;
  final String Function(String, bool) navigation;
  final void Function(String)? onOpen;
  final Widget? errorAction;
  @override
  State<PublicWebView> createState() => _PublicWebViewState();
}

class _PublicWebViewState extends State<PublicWebView> {
  WebViewController? controller;
  bool failed = false, loading = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PublicWebView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url ||
        old.html != widget.html ||
        old.baseUrl != widget.baseUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final ticket = ++generation;
    var mainDocument = widget.html == null
        ? Uri.tryParse(widget.url ?? '')?.removeFragment()
        : null;
    failed = false;
    loading = true;
    controller = null;
    try {
      if (widget.url != null &&
          widget.navigation(widget.url!, true) != 'allow') {
        throw const FormatException('Blocked initial URL');
      }
      final params = WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true,
              mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
            )
          : const PlatformWebViewControllerCreationParams();
      final next = WebViewController.fromPlatformCreationParams(params);
      await next.setJavaScriptMode(
        widget.javascript
            ? JavaScriptMode.unrestricted
            : JavaScriptMode.disabled,
      );
      if (next.platform case final AndroidWebViewController android) {
        await android.setAllowFileAccess(false);
        await android.setAllowContentAccess(false);
        await android.setMediaPlaybackRequiresUserGesture(false);
      }
      await next.setBackgroundColor(widget.dark ? Colors.black : Colors.white);
      await next.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!mounted || ticket != generation) {
              return NavigationDecision.prevent;
            }
            final verdict = widget.navigation(request.url, request.isMainFrame);
            if (widget.html == null &&
                request.isMainFrame &&
                verdict == 'allow') {
              mainDocument = Uri.tryParse(request.url)?.removeFragment();
            }
            if (verdict == 'open' || verdict == 'external') {
              if (widget.onOpen case final open?) {
                open(request.url);
              } else {
                openInApp(context, request.url);
              }
            }
            return verdict == 'allow'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted && ticket == generation) {
              setState(() => loading = false);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != false) _fail(ticket);
          },
          onHttpError: (error) {
            if (mainDocument != null &&
                error.request?.uri.removeFragment() == mainDocument &&
                (error.response?.statusCode ?? 0) >= 400) {
              _fail(ticket);
            }
          },
        ),
      );
      if (!mounted || ticket != generation) return;
      if (widget.html case final html?) {
        await next.loadHtmlString(html, baseUrl: widget.baseUrl);
      } else {
        await next.loadRequest(Uri.parse(widget.url!));
      }
      if (mounted && ticket == generation) setState(() => controller = next);
    } catch (_) {
      _fail(ticket);
    }
  }

  void _fail(int ticket) {
    if (mounted && ticket == generation) setState(() => failed = true);
  }

  @override
  Widget build(BuildContext context) =>
      ViewerSafeArea(child: _content(context));

  Widget _content(BuildContext context) {
    if (failed) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                Notice(text: widget.errorText, tone: 'error'),
                if (widget.dark)
                  const Text(
                    'Kiểm tra mạng rồi thử lại.',
                    style: TextStyle(color: Colors.white),
                  ),
                Button(
                  title: 'Thử lại',
                  onPress: () {
                    setState(() {});
                    _load();
                  },
                ),
                ?widget.errorAction,
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: widget.title,
      child: Stack(
        children: [
          if (controller case final c?)
            Positioned.fill(child: WebViewWidget(controller: c)),
          if (loading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Loading(),
                  if (widget.loadingText case final label?)
                    Text(
                      label,
                      style: TextStyle(
                        color: widget.dark ? Colors.white : Colors.black,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class TourFrame extends StatelessWidget {
  const TourFrame({super.key, required this.url, required this.title});
  final String url, title;
  @override
  Widget build(BuildContext context) {
    final embed = tourEmbedUrl(url);
    if (embed == null) {
      return const Center(
        child: Text('Tour 360° này không xem được trong app.'),
      );
    }
    return PublicWebView(
      url: embed,
      title: title,
      navigation: tourNavigation,
      dark: true,
      loadingText: 'Đang tải tour 360°…',
      errorText: 'Không tải được tour 360°',
      errorAction: Button(
        title: 'Mở trang tour',
        kind: 'secondary',
        onPress: () => openInApp(context, url, title),
      ),
    );
  }
}
