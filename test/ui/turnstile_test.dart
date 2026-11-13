import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/turnstile.dart';

void main() {
  const page = 'https://smartduan.vn/xac-minh-app?action=register';
  test('verification URL uses supplied web and action', () {
    expect(captchaUrl('register', 'https://smartduan.vn'), page);
    expect(
      captchaUrl('forgot-password', 'https://dev.smartduan.vn/'),
      'https://dev.smartduan.vn/xac-minh-app?action=forgot-password',
    );
  });
  test(
    'top frame stays on verification page; HTTPS challenge frames allowed',
    () {
      expect(captchaNavigation(page, true, page), true);
      expect(captchaNavigation('https://smartduan.vn/', true, page), false);
      expect(
        captchaNavigation(
          'https://evil.vn/xac-minh-app?action=register',
          true,
          page,
        ),
        false,
      );
      expect(
        captchaNavigation(
          'https://challenges.cloudflare.com/cdn-cgi/challenge-platform/x',
          false,
          page,
        ),
        true,
      );
      expect(captchaNavigation('intent://x#Intent;end', false, page), false);
    },
  );
  test(
    'accept tokens only from matching origin; error clears; unrelated ignored',
    () {
      const ok = '{"type":"turnstile","token":"tok"}';
      for (final from in [page, 'https://smartduan.vn']) {
        expect(
          captchaMessage(ok, from, page),
          isA<CaptchaToken>().having((m) => m.token, 'token', 'tok'),
        );
      }
      for (final from in [
        'https://evil.vn',
        'https://smartduan.vn.evil.vn',
        'http://smartduan.vn',
        null,
      ]) {
        expect(captchaMessage(ok, from, page), isA<CaptchaIgnored>());
      }
      expect(
        captchaMessage('{"type":"turnstile-error"}', page, page),
        isA<CaptchaError>(),
      );
      for (final data in [
        '{"type":"turnstile","token":""}',
        'không phải json',
        'null',
        '[]',
        '{"type":"turnstile","token":1}',
      ]) {
        expect(captchaMessage(data, page, page), isA<CaptchaIgnored>());
      }
    },
  );
}
