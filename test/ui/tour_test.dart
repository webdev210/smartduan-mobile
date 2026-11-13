import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/tour.dart';

void main() {
  test('malformed HTTP origins are blocked like the RN URL parser', () {
    for (final url in ['https://', 'http://', 'https://?x', 'http:']) {
      expect(tourEmbedUrl(url), isNull);
      expect(tourNavigation(url, true), 'block', reason: url);
    }
  });
  // URL thật trên smartduan.vn (CHARMORA-CITY-NHA-TRANG, 07/11/2026)
  const tour = "https://360.smartrealtors.vn/share/collection/7H1b3";

  group("tourEmbedUrl (allowlist như web/lib/url.ts MEDIA_FRAME_SRC)", () {
    test("chỉ nhúng https://360.smartrealtors.vn", () {
      expect(tourEmbedUrl(tour), tour);
      expect(tourEmbedUrl(' $tour '), tour);
    });

    test("host khác, http thường, scheme lạ hoặc rỗng → không nhúng", () {
      expect(tourEmbedUrl("https://kuula.co/share/abc"), isNull);
      expect(tourEmbedUrl("http://360.smartrealtors.vn/share/x"), isNull);
      expect(tourEmbedUrl("https://360.smartrealtors.vn.evil.com/x"), isNull);
      expect(tourEmbedUrl("javascript:alert(1)"), isNull);
      expect(tourEmbedUrl(null), isNull);
      expect(tourEmbedUrl(""), isNull);
    });
  });

  group("tourNavigation — WebView chỉ được đi trong host tour", () {
    test("trong host tour, about:blank, data:, blob: → cho phép", () {
      expect(tourNavigation(tour, true), "allow");
      expect(
        tourNavigation("https://360.smartrealtors.vn/share/scene/2", true),
        "allow",
      );
      expect(tourNavigation("about:blank", true), "allow");
      expect(
        tourNavigation("blob:https://360.smartrealtors.vn/1", true),
        "allow",
      );
    });

    test("khung con (bản đồ, video nhúng trong tour) không bị chặn", () {
      expect(
        tourNavigation("https://www.google.com/maps/embed?x", false),
        "allow",
      );
    });

    test("trang chính đi ra host khác (http/https/tel/mailto) → mở ngoài app; scheme lạ → chặn", () {
      expect(
        tourNavigation("https://smartrealtors.vn/du-an", true),
        "external",
      );
      expect(tourNavigation("tel:0901234567", true), "external");
      expect(tourNavigation("mailto:a@b.vn", true), "external");
      expect(tourNavigation("intent://x#Intent;end", true), "block");
      expect(tourNavigation("javascript:alert(1)", true), "block");
    });
  });
}
