import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/catalog.dart';

Browsable p(String id, String status, [String? cover, String? name]) =>
    Browsable(
      id: id,
      name: name ?? 'Dự án $id',
      status: status,
      coverUrl: cover,
    );
void main() {
  test('Vietnamese name order preserves base letters, tones and canonical equivalence', () {
    final names = ['ạ', 'á', 'ã', 'ả', 'à', 'a', 'ă', 'â', 'e', 'đ', 'd'];
    names.sort(compareVietnamese);
    expect(names, ['a', 'à', 'ả', 'ã', 'á', 'ạ', 'ă', 'â', 'd', 'đ', 'e']);
    expect(compareVietnamese('Đà Nẵng', 'Đa\u0300 Na\u0306\u0303ng'), 0);
  });
  test(
    'absolute HTTP media unchanged; relative media resolved on web base',
    () {
      const web = 'http://192.168.21.142:3000';
      expect(
        mediaUrl('https://s3.example.vn/a.jpg', web),
        'https://s3.example.vn/a.jpg',
      );
      expect(
        mediaUrl('http://localhost:9000/b.png', web),
        'http://localhost:9000/b.png',
      );
      expect(mediaUrl('/demo/unit-1.svg', web), '$web/demo/unit-1.svg');
      expect(
        mediaUrl('/demo/unit-1.svg', 'https://smartduan.vn/'),
        'https://smartduan.vn/demo/unit-1.svg',
      );
    },
  );
  test(
    'unconfigured, empty, unknown schemes and protocol relative media ignored',
    () {
      expect(mediaUrl('/demo/unit-1.svg', ''), isNull);
      for (final url in [
        null,
        '',
        'javascript:alert(1)',
        '//evil.example/x.png',
      ]) {
        expect(mediaUrl(url), isNull);
      }
    },
  );
  test('hero prefers at most six hot projects with covers', () {
    final hot = List.generate(
      8,
      (i) => p('h$i', 'selling', 'https://x/$i.jpg'),
    );
    expect(
      heroProjects<Browsable>([
        p('no-cover', 'selling'),
        ...hot,
      ], []).map((x) => x.id),
      ['h0', 'h1', 'h2', 'h3', 'h4', 'h5'],
    );
  });
  test('hero fallback favors selling with normal-case name and cover', () {
    expect(
      heroProjects<Browsable>([], [
        p('a', 'selling', 'https://x/a.jpg', 'DỰ ÁN IN HOA'),
        p('b', 'selling', 'https://x/b.jpg', 'Dự án Bình Thường'),
        p('c', 'upcoming', 'https://x/c.jpg'),
      ]).map((x) => x.id),
      ['b'],
    );
    expect(
      heroProjects<Browsable>([], [
        p('u', 'upcoming'),
        p('s', 'selling'),
      ]).map((x) => x.id),
      ['s'],
    );
    expect(heroProjects<Browsable>([], <Browsable>[]), isEmpty);
  });
  final aliases = provinceAliases([
    Province(name: 'Hà Nội', oldNames: []),
    Province(name: 'TP.HCM', oldNames: ['Bà Rịa - Vũng Tàu', 'Bình Dương']),
  ]);
  test(
    'old and alternate province names canonicalized; unknown and null retained',
    () {
      for (final value in [
        'Bình Dương',
        'Bà Rịa – Vũng Tàu',
        'TP. Hồ Chí Minh',
      ]) {
        expect(canonicalProvince(value, aliases), 'TP.HCM');
      }
      expect(canonicalProvince('Đà Nẵng', aliases), 'Đà Nẵng');
      expect(canonicalProvince(null, aliases), '');
      expect(canonicalProvince('A', {'A': 'B', 'B': 'A'}), 'A');
    },
  );
  test('province counts omit unknown location and sort by count then Vietnamese name', () {
    final list = [
      'TP.HCM',
      'Bình Dương',
      'Đà Nẵng',
      'Hà Nội',
      null,
      'TP. Hồ Chí Minh',
    ].map((s) => Browsable(name: '', status: 'selling', province: s)).toList();
    expect(provinceCounts(list, aliases), [
      (name: 'TP.HCM', count: 3),
      (name: 'Đà Nẵng', count: 1),
      (name: 'Hà Nội', count: 1),
    ]);
    expect(inProvince('Bình Dương', 'TP.HCM', aliases), true);
    expect(inProvince('Hà Nội', 'TP.HCM', aliases), false);
    expect(inProvince(null, null, aliases), true);
  });
  test(
    'featured selling first, upcoming second, excludes others, caps six',
    () {
      expect(
        featuredProjects([
          p('u1', 'upcoming'),
          p('s1', 'selling'),
          p('x', 'sold_out'),
          p('s2', 'selling'),
          p('z', 'paused'),
        ]).map((x) => x.id),
        ['s1', 's2', 'u1'],
      );
      expect(
        featuredProjects(List.generate(9, (i) => p('s$i', 'selling'))),
        hasLength(6),
      );
    },
  );
  test('footer parses only catalogue fields and handles plus and unicode', () {
    for (final href in [
      '/du-an?province=H%E1%BB%93+Ch%C3%AD+Minh&project_type=apartment',
      '/du-an?province=Hồ+Chí+Minh&project_type=apartment',
    ]) {
      expect(footerCatalogParams(href), {
        'province': 'Hồ Chí Minh',
        'project_type': 'apartment',
      });
    }
    for (final href in [
      '/khu-vuc/H%C3%A0%20N%E1%BB%99i',
      '/chu-dau-tu/vinhomes',
      '/du-an?page=2',
    ]) {
      expect(footerCatalogParams(href), isNull);
    }
  });
  test(
    'footer ignores malformed percent pairs and preserves equals in values',
    () {
      expect(
        footerCatalogParams('/du-an?province=%E1%BB&project_type=apartment'),
        {'project_type': 'apartment'},
      );
      expect(footerCatalogParams('/du-an?%E1=x'), isNull);
      expect(footerCatalogParams('/du-an?province=a=b'), {'province': 'a=b'});
    },
  );
}
