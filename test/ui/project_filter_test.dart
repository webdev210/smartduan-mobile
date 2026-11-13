import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/ui/project_filter.dart';
import 'package:smartduan/ui/search.dart';

const list = [
  Browsable(
    id: '1',
    name: 'Vinhomes Grand Park',
    status: 'selling',
    projectType: 'apartment',
    province: 'TP.HCM',
    district: 'Thủ Đức',
    priceFrom: '2500000000',
    developerName: 'Vinhomes',
  ),
  Browsable(
    id: '2',
    name: 'The Emerald 68',
    status: 'selling',
    projectType: 'apartment',
    province: 'Bình Dương',
    priceFrom: '1800000000',
    developer: ProjectDeveloper(id: 'd2', name: 'Lê Phong'),
  ),
  Browsable(
    id: '3',
    name: 'Sun Urban City',
    status: 'upcoming',
    projectType: 'lowrise',
    province: 'Hà Nam',
    priceFrom: '12000000000',
    developerName: 'Sun Group',
  ),
  Browsable(
    id: '4',
    name: 'Đất nền Bảo Lộc',
    status: 'sold_out',
    projectType: 'land',
    province: 'Lâm Đồng',
  ),
];
List<String> names(ProjectFilter f, [Map<String, String> aliases = const {}]) =>
    filterProjects(list, f, aliases).map((p) => p.name).toList();
void main() {
  test('empty optional filter strings behave as unselected RN values', () {
    const f = ProjectFilter(
      status: '',
      type: '',
      region: '',
      province: '',
      developer: '',
      price: '',
    );
    expect(names(f), list.map((p) => p.name));
    expect(activeFilters(f), isEmpty);
  });
  test(
    'empty filters preserve server order',
    () => expect(names(emptyProjectFilter), list.map((p) => p.name)),
  );
  test('search covers accentless location developer type and status', () {
    expect(names(const ProjectFilter(q: 'thu duc')), ['Vinhomes Grand Park']);
    expect(names(const ProjectFilter(q: 'le phong')), ['The Emerald 68']);
    expect(names(const ProjectFilter(q: 'can ho dang ban binh duong')), [
      'The Emerald 68',
    ]);
    expect(names(const ProjectFilter(q: 'dat nen')), ['Đất nền Bảo Lộc']);
    expect(names(const ProjectFilter(q: 'sap mo ban')), ['Sun Urban City']);
  });
  test('status type region and both developer shapes', () {
    expect(names(const ProjectFilter(status: 'selling', type: 'apartment')), [
      'Vinhomes Grand Park',
      'The Emerald 68',
    ]);
    expect(names(const ProjectFilter(region: 'bac')), ['Sun Urban City']);
    expect(names(const ProjectFilter(developer: 'Lê Phong')), [
      'The Emerald 68',
    ]);
    expect(names(const ProjectFilter(developer: 'Vinhomes')), [
      'Vinhomes Grand Park',
    ]);
  });
  test('province uses post-merger names', () {
    expect(
      names(const ProjectFilter(province: 'TP.HCM'), {'Bình Dương': 'TP.HCM'}),
      ['Vinhomes Grand Park', 'The Emerald 68'],
    );
    expect(names(const ProjectFilter(province: 'TP.HCM')), [
      'Vinhomes Grand Park',
    ]);
  });
  test('price bands exclude unpublished prices', () {
    expect(names(const ProjectFilter(price: 'lt2')), ['The Emerald 68']);
    expect(names(const ProjectFilter(price: '2to5')), ['Vinhomes Grand Park']);
    expect(names(const ProjectFilter(price: 'gt10')), ['Sun Urban City']);
  });
  test(
    'price sort keeps null last in both directions; Vietnamese name sort',
    () {
      expect(names(const ProjectFilter(sort: 'price_asc')), [
        'The Emerald 68',
        'Vinhomes Grand Park',
        'Sun Urban City',
        'Đất nền Bảo Lộc',
      ]);
      expect(names(const ProjectFilter(sort: 'price_desc')), [
        'Sun Urban City',
        'Vinhomes Grand Park',
        'The Emerald 68',
        'Đất nền Bảo Lộc',
      ]);
      expect(names(const ProjectFilter(sort: 'name')), [
        'Đất nền Bảo Lộc',
        'Sun Urban City',
        'The Emerald 68',
        'Vinhomes Grand Park',
      ]);
    },
  );
  test('facets count other filters only', () {
    final got = facets(
      list,
      const ProjectFilter(status: 'selling', type: 'apartment'),
      {},
    );
    expect(got['status'], [(key: 'selling', label: 'Đang bán', count: 2)]);
    expect(got['type']!.map((o) => (o.key, o.count)), [('apartment', 2)]);
    final open = facets(list, emptyProjectFilter, {});
    expect(open['status']!.map((o) => (o.key, o.count)), [
      ('selling', 2),
      ('upcoming', 1),
      ('sold_out', 1),
    ]);
    expect(open['region']!.map((o) => (o.key, o.count)), [
      ('bac', 1),
      ('trung', 1),
      ('nam', 2),
    ]);
    expect(open['developer']!.map((o) => o.label), [
      'Lê Phong',
      'Sun Group',
      'Vinhomes',
    ]);
  });
  test('selected zero-count option stays removable', () {
    expect(
      facets(
        list,
        const ProjectFilter(q: 'vinhomes', type: 'land'),
        {},
      )['type'],
      [
        (key: 'apartment', label: 'Căn hộ', count: 1),
        (key: 'land', label: 'Đất nền', count: 0),
      ],
    );
  });
  final withMixed = [
    ...list,
    const Browsable(
      id: '5',
      name: 'Artisan Park',
      status: 'selling',
      projectType: 'mixed',
      province: 'Bình Dương',
    ),
  ];
  List<String> of(ProjectFilter f) =>
      filterProjects(withMixed, f, {}).map((p) => p.name).toList();
  test('mixed belongs to apartments and lowrise; lowrise includes land', () {
    expect(of(const ProjectFilter(type: 'apartment')), [
      'Vinhomes Grand Park',
      'The Emerald 68',
      'Artisan Park',
    ]);
    expect(of(const ProjectFilter(type: 'lowrise')), [
      'Sun Urban City',
      'Đất nền Bảo Lộc',
      'Artisan Park',
    ]);
    expect(of(const ProjectFilter(type: 'land')), ['Đất nền Bảo Lộc']);
    expect(of(const ProjectFilter(type: 'mixed')), ['Artisan Park']);
  });
  test('mixed facet counts follow the same grouping and translated label', () {
    expect(facets(withMixed, emptyProjectFilter, {})['type'], [
      (key: 'apartment', label: 'Căn hộ', count: 3),
      (key: 'lowrise', label: 'Thấp tầng', count: 3),
      (key: 'mixed', label: 'Cao tầng & thấp tầng', count: 1),
      (key: 'land', label: 'Đất nền', count: 1),
    ]);
  });
  test(
    'search matches mixed label cao tang',
    () => expect(of(const ProjectFilter(q: 'cao tang')), ['Artisan Park']),
  );
  test('active chips ordered and exclude query and sort', () {
    expect(activeFilters(const ProjectFilter(q: 'abc', sort: 'name')), isEmpty);
    expect(
      activeFilters(
        const ProjectFilter(
          status: 'selling',
          type: 'land',
          region: 'nam',
          province: 'Đồng Nai',
          developer: 'Sun Group',
          price: '5to10',
        ),
      ),
      [
        (key: 'status', label: 'Đang bán'),
        (key: 'type', label: 'Đất nền'),
        (key: 'region', label: 'Miền Nam'),
        (key: 'province', label: 'Đồng Nai'),
        (key: 'developer', label: 'Sun Group'),
        (key: 'price', label: '5 – 10 tỷ'),
      ],
    );
  });
  test('province and developer suggestions include counts', () {
    expect(suggest(list, 'binh', emptyProjectFilter, {}), [
      (kind: 'province', label: 'Bình Dương', count: 1),
    ]);
    expect(suggest(list, 'sun', emptyProjectFilter, {}), [
      (kind: 'developer', label: 'Sun Group', count: 1),
    ]);
  });
  test('short query and selected facet suppress suggestions', () {
    expect(suggest(list, 'b', emptyProjectFilter, {}), isEmpty);
    expect(
      suggest(list, 'binh', const ProjectFilter(province: 'Bình Dương'), {}),
      isEmpty,
    );
  });
  test(
    'incremental search on 100 projects preserves results with warmed cache',
    () {
      final many = List.generate(
        100,
        (i) => Browsable(
          id: '$i',
          name: 'Dự án Số $i',
          status: 'selling',
          projectType: 'apartment',
          province: ['Bình Dương', 'TP.HCM', 'Hà Nội'][i % 3],
          district: 'Thủ Đức',
          developerName: 'Chủ đầu tư ${i % 7}',
        ),
      );
      final foldedNames = many.map((p) => fold(p.name)).toList();
      for (final q in ['du an', 'du an s']) {
        final f = ProjectFilter(q: q);
        expect(filterProjects(many, f, {}), hasLength(100));
        expect(facets(many, f, {})['type']!.single.count, 100);
        suggest(many, q, f, {});
      }
      // Dart cannot spy on String.prototype.normalize; cached output identity
      // verifies that warmed titles were reused rather than normalized again.
      for (var i = 0; i < many.length; i++) {
        expect(identical(fold(many[i].name), foldedNames[i]), true);
      }
    },
  );
}
