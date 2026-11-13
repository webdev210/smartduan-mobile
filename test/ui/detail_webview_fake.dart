// The platform interface is installed by webview_flutter; no extra dependency.
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class DetailWebViewPlatform extends WebViewPlatform {
  final controllers = <DetailWebController>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = DetailWebController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => DetailNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => DetailWebWidget(params);
}

class DetailWebController extends PlatformWebViewController {
  DetailWebController(super.params) : super.implementation();
  final loaded = <String>[];
  String? html, baseUrl;
  JavaScriptMode? javascript;
  DetailNavigation? navigation;
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loaded.add(params.uri.toString());
  }

  @override
  Future<void> loadHtmlString(String value, {String? baseUrl}) async {
    html = value;
    this.baseUrl = baseUrl;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    javascript = mode;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigation = handler as DetailNavigation;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> enableZoom(bool enabled) async {}
}

class DetailNavigation extends PlatformNavigationDelegate {
  DetailNavigation(super.params) : super.implementation();
  late NavigationRequestCallback request;
  PageEventCallback? finished;
  WebResourceErrorCallback? error;
  HttpResponseErrorCallback? httpError;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    request = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    httpError = callback;
  }

  Future<NavigationDecision> navigate(String url, [bool top = true]) async =>
      request(NavigationRequest(url: url, isMainFrame: top));
}

class DetailWebWidget extends PlatformWebViewWidget {
  DetailWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
