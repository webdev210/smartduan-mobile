import 'dart:convert';

import 'in_app.dart';

String? embedOrigin(String? url) => url == null
    ? null
    : RegExp(
        r'^https://[^/?#\s]+',
        caseSensitive: false,
      ).firstMatch(url)?.group(0);
String _attr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
String _jsStr(String s) => jsonEncode(s).replaceAll('<', r'\u003c');

/// attrs and script must be app-authored HTML, never external data.
String frameHtml(
  String src,
  String title, [
  String attrs = '',
  String script = '',
]) =>
    '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;height:100%;background:#fff}iframe{display:block;border:0;width:100%;height:100%}</style></head><body>
<iframe title="${_attr(title)}" src="${_attr(src)}" ${attrs}allow="fullscreen"></iframe>$script
</body></html>''';

String basketFrameHtml(String src, String origin, String nonce) => frameHtml(
  src,
  'Rổ hàng',
  'sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox" referrerpolicy="no-referrer" ',
  '''
<script>var O=${_jsStr(origin)},N=${_jsStr(nonce)};addEventListener("message",function(e){var d=e.data;if(e.origin!==O||!d||d.nonce!==N||typeof d.type!=="string")return;window.ReactNativeWebView&&window.ReactNativeWebView.postMessage(JSON.stringify({type:d.type,message:typeof d.message==="string"?d.message:""}));});</script>''',
);

String frameNavigation(String url, bool isTopFrame, String parent) {
  if (RegExp(r'^about:', caseSensitive: false).hasMatch(url)) return 'allow';
  if (!isTopFrame) return isHttp(url) ? 'allow' : 'block';
  if (url.replaceFirst(RegExp(r'/$'), '') ==
      parent.replaceFirst(RegExp(r'/$'), '')) {
    return 'allow';
  }
  return isHttp(url) ||
          RegExp(r'^(tel|mailto):', caseSensitive: false).hasMatch(url)
      ? 'open'
      : 'block';
}
