import 'dart:convert';

String captchaUrl(String action, String web) =>
    '${web.replaceFirst(RegExp(r'/+$'), '')}/xac-minh-app?action=$action';
String _originOf(String url) =>
    RegExp(
      r'^[a-z][a-z0-9+.-]*://[^/?#]+',
      caseSensitive: false,
    ).firstMatch(url)?.group(0)?.toLowerCase() ??
    '';
bool captchaNavigation(String url, bool isTopFrame, String page) => isTopFrame
    ? url.split('#').first == page
    : url.startsWith('https://') || url.startsWith('about:');

sealed class CaptchaMessage {
  const CaptchaMessage();
}

final class CaptchaToken extends CaptchaMessage {
  const CaptchaToken(this.token);
  final String token;
}

final class CaptchaError extends CaptchaMessage {
  const CaptchaError();
}

final class CaptchaIgnored extends CaptchaMessage {
  const CaptchaIgnored();
}

/// Ignored leaves the current token intact; error clears it.
CaptchaMessage captchaMessage(String data, String? from, String page) {
  if (from == null || from.isEmpty || _originOf(from) != _originOf(page)) {
    return const CaptchaIgnored();
  }
  try {
    return switch (jsonDecode(data)) {
      {'type': 'turnstile', 'token': String token} when token.isNotEmpty =>
        CaptchaToken(token),
      {'type': 'turnstile-error'} => const CaptchaError(),
      _ => const CaptchaIgnored(),
    };
  } on FormatException {
    return const CaptchaIgnored();
  }
}
