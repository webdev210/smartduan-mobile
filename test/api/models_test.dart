import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';
import 'package:smartduan/api/unit_compare.dart';

import 'public_test.dart' show projectJson;

const developerJson = <String, Object?>{
  'id': 'd',
  'name': 'Sun Group',
  'slug': 'sun',
  'logo_url': null,
  'website': null,
  'description': null,
  'badges': ['Diamond Agent Sun Group'],
};
const postJson = <String, Object?>{
  'id': 'n',
  'kind': 'news',
  'title': 'Tin mới',
  'slug': 'tin-moi',
  'excerpt': null,
  'cover_url': null,
  'published_at': null,
  'event_at': null,
  'location': null,
  'project': {'id': 'p', 'name': 'Dự án', 'code': 'P'},
  'body': '<p>Nội dung</p>',
};
const loanJson = <String, Object?>{
  'price': 1000000000,
  'loan_amount': 700000000,
  'loan_ratio': 0.7,
  'term_months': 120,
  'grace_months': 0,
  'supported_rate': 0,
  'floating_rate': 10.5,
  'monthly_payment': 10000000,
  'totals': {'principal': 700000000, 'interest': 100000000, 'total': 800000000},
  'schedule': [
    {
      'period': 1,
      'principal': 5000000,
      'interest': 5000000,
      'total': 10000000,
      'remaining': 695000000,
    },
  ],
};

void main() {
  group('M2 tolerant JSON readers', () {
    test('strings accept numbers and default unexpected types', () {
      final document = PublicDocument.fromJson({
        'name': 42,
        'url': <Object?>[],
      });
      expect(document.name, '42');
      expect(document.url, isNull);
    });
    test('integers accept numeric strings and default unexpected types', () {
      final page = Paged.fromJson({
        'page': '2',
        'per_page': 50.0,
        'total': <Object?>[],
      }, Province.fromJson);
      expect([page.page, page.perPage, page.total], [2, 50, 0]);
    });
    test('numbers accept numeric strings and default unexpected types', () {
      final totals = LoanTotals.fromJson({
        'principal': '50.5',
        'interest': <Object?>[],
        'total': 'invalid',
      });
      expect([totals.principal, totals.interest, totals.total], [50.5, 0, 0]);
    });
    test('booleans default unexpected types', () {
      expect(
        PublicProject.fromJson({...projectJson('p'), 'has_tour360': 'yes'})
            .hasTour360,
        isFalse,
      );
    });
    test('object lists tolerate wrong containers and entries', () {
      expect(Paged.fromJson({'data': false}, Province.fromJson).data, isEmpty);
      expect(
        Paged.fromJson({
          'data': [
            null,
            <Object?>[],
            {'name': 'A'},
          ],
        }, Province.fromJson).data.single.name,
        'A',
      );
    });
    test('string lists tolerate wrong containers and entries', () {
      expect(
        Province.fromJson({'name': 'A', 'old_names': <String, Object?>{}})
            .oldNames,
        isEmpty,
      );
      expect(
        Province.fromJson({
          'name': 'A',
          'old_names': [false, 'B'],
        }).oldNames,
        ['B'],
      );
    });
    test(
      'nested objects tolerate wrong types and default required summaries',
      () {
        expect(
          PublicProject.fromJson({...projectJson('p'), 'developer': false})
              .developer,
          isNull,
        );
        expect(LoanResult.fromJson({'totals': <Object?>[]}).totals.total, 0);
      },
    );
    test('identity fields reject missing or non-string values', () {
      for (final value in [null, 1, true, <Object?>[], <String, Object?>{}]) {
        expect(() => Province.fromJson({'name': value}), throwsFormatException);
        expect(
          () => ComparePickerUnit.fromJson({'id': value, 'code': 'U'}),
          throwsFormatException,
        );
      }
    });
    test('compare picker uses tolerant optional fields', () {
      final unit = ComparePickerUnit.fromJson({
        'id': 'u',
        'code': 'U',
        'price_min': 400000000,
        'status': <Object?>[],
        'unit_type': false,
      });
      expect(unit.priceMin, '400000000');
      expect(unit.status, '');
      expect(unit.unitType, isNull);
    });
  });
  for (final explicitNull in [false, true]) {
    Map<String, dynamic> payload(
      Map<String, dynamic> identity,
      List<String> optional,
    ) => {
      ...identity,
      if (explicitNull)
        for (final key in optional) key: null,
    };
    group(
      explicitNull ? 'null non-identity fields' : 'identity fields only',
      () {
        test('Paged', () {
          final p = Paged.fromJson(
            payload({}, ['data', 'page', 'per_page', 'total']),
            Province.fromJson,
          );
          expect(p.data, isEmpty);
          expect([p.page, p.perPage, p.total], [0, 0, 0]);
        });
        test('Province', () {
          final p = Province.fromJson(payload({'name': 'A'}, ['old_names']));
          expect(p.name, 'A');
          expect(p.oldNames, isEmpty);
        });
        test('PrivacyPolicy', () {
          final p = PrivacyPolicy.fromJson(
            payload(
              {'version': 'v1', 'title': 'Policy'},
              ['url', 'effective_from'],
            ),
          );
          expect([p.version, p.title], ['v1', 'Policy']);
          expect(p.url, isNull);
          expect(p.effectiveFrom, '');
        });
        test('FullPolicy', () {
          final p = FullPolicy.fromJson(
            payload({'version': 'v1'}, ['title', 'effective_from', 'body']),
          );
          expect(p.version, 'v1');
          expect([p.title, p.effectiveFrom], [null, null]);
          expect(p.body, '');
        });
        test('FooterLink', () {
          final p = FooterLink.fromJson(
            payload({}, ['label', 'href', 'count']),
          );
          expect([p.label, p.href, p.count], ['', '', 0]);
        });
        test('ProjectDeveloper', () {
          final p = ProjectDeveloper.fromJson(
            payload({'id': 'd', 'name': 'Developer'}, ['logo_url', 'slug']),
          );
          expect([p.id, p.name], ['d', 'Developer']);
          expect([p.logoUrl, p.slug], [null, null]);
        });
        test('PublicMedia', () {
          final p = PublicMedia.fromJson(
            payload(
              {'id': 'm'},
              ['media_type', 'url', 'caption', 'display_order', 'embed_url'],
            ),
          );
          expect(p.id, 'm');
          expect([p.mediaType, p.url], ['', '']);
          expect([p.caption, p.displayOrder, p.embedUrl], [null, null, null]);
        });
        test('PublicDocument', () {
          final p = PublicDocument.fromJson(payload({}, ['name', 'url']));
          expect([p.name, p.url], [null, null]);
        });
        test('PublicSubdivision', () {
          final p = PublicSubdivision.fromJson(
            payload({'name': 'A'}, ['code', 'description', 'cover_url']),
          );
          expect(p.name, 'A');
          expect([p.code, p.description, p.coverUrl], [null, null, null]);
        });
        test('PublicProgress', () {
          final p = PublicProgress.fromJson(
            payload(
              {'title': 'Progress'},
              ['occurred_on', 'body', 'image_url'],
            ),
          );
          expect(p.title, 'Progress');
          expect([p.occurredOn, p.body, p.imageUrl], [null, null, null]);
        });
        test('PublicFaq', () {
          final p = PublicFaq.fromJson(
            payload({'id': 'f'}, ['question', 'answer', 'position']),
          );
          expect(p.id, 'f');
          expect([p.question, p.answer, p.position], ['', '', 0]);
        });
        test('PublicProject', () {
          final p = PublicProject.fromJson(
            payload(
              {'id': 'p', 'code': 'P', 'name': 'Project'},
              [
                'status',
                'project_type',
                'developer',
                'province',
                'district',
                'ward',
                'address',
                'lat',
                'lng',
                'price_from',
                'overview_json',
                'documents',
                'cover_url',
                'has_tour360',
                'tour360_url',
                'activity_7d',
                'province_old',
                'district_old',
                'ward_old',
                'media',
                'subdivisions',
                'progress',
                'faqs',
              ],
            ),
          );
          expect([p.id, p.code, p.name], ['p', 'P', 'Project']);
          expect(p.status, '');
          expect(p.hasTour360, false);
          expect(p.activity7d, 0);
          expect(p.documents, isEmpty);
          expect([
            p.projectType,
            p.developer,
            p.province,
            p.district,
            p.ward,
            p.address,
            p.lat,
            p.lng,
            p.priceFrom,
            p.overviewJson,
            p.coverUrl,
            p.tour360Url,
            p.provinceOld,
            p.districtOld,
            p.wardOld,
            p.media,
            p.subdivisions,
            p.progress,
            p.faqs,
          ], everyElement(isNull));
        });
        test('PublicDeveloper', () {
          final p = PublicDeveloper.fromJson(
            payload(
              {'id': 'd', 'name': 'Developer'},
              ['slug', 'logo_url', 'website', 'description', 'badges'],
            ),
          );
          expect([p.id, p.name], ['d', 'Developer']);
          expect([
            p.slug,
            p.logoUrl,
            p.website,
            p.description,
          ], everyElement(isNull));
          expect(p.badges, isEmpty);
        });
        test('PublicContact', () {
          final p = PublicContact.fromJson(
            payload({}, ['hotline', 'zalo_url']),
          );
          expect([p.hotline, p.zaloUrl], [null, null]);
        });
        test('PublicStats', () {
          final p = PublicStats.fromJson(
            payload({}, [
              'developers',
              'projects_selling',
              'activity_7d_total',
              'contact',
            ]),
          );
          expect(
            [p.developers, p.projectsSelling, p.activity7dTotal],
            [0, 0, 0],
          );
          expect([p.contact.hotline, p.contact.zaloUrl], [null, null]);
        });
        test('PostProject', () {
          final p = PostProject.fromJson({
            'id': 'p',
            'code': 'P',
            'name': 'Project',
          });
          expect([p.id, p.code, p.name], ['p', 'P', 'Project']);
        });
        test('PublicPost', () {
          final p = PublicPost.fromJson(
            payload(
              {'id': 'n', 'title': 'Post', 'slug': 'post'},
              [
                'kind',
                'excerpt',
                'cover_url',
                'published_at',
                'event_at',
                'location',
                'project',
                'body',
              ],
            ),
          );
          expect([p.id, p.title, p.slug], ['n', 'Post', 'post']);
          expect(p.kind, '');
          expect([
            p.excerpt,
            p.coverUrl,
            p.publishedAt,
            p.eventAt,
            p.location,
            p.project,
            p.body,
          ], everyElement(isNull));
        });
        test('LoanTotals', () {
          final p = LoanTotals.fromJson(
            payload({}, ['principal', 'interest', 'total']),
          );
          expect([p.principal, p.interest, p.total], [0, 0, 0]);
        });
        test('LoanPeriod', () {
          final p = LoanPeriod.fromJson(
            payload({}, [
              'period',
              'principal',
              'interest',
              'total',
              'remaining',
            ]),
          );
          expect(
            [p.period, p.principal, p.interest, p.total, p.remaining],
            [0, 0, 0, 0, 0],
          );
        });
        test('LoanResult', () {
          final p = LoanResult.fromJson(
            payload({}, [
              'price',
              'loan_amount',
              'loan_ratio',
              'term_months',
              'grace_months',
              'supported_rate',
              'floating_rate',
              'monthly_payment',
              'price_basis',
              'totals',
              'schedule',
            ]),
          );
          expect([
            p.price,
            p.loanAmount,
            p.loanRatio,
            p.termMonths,
            p.graceMonths,
            p.supportedRate,
            p.floatingRate,
            p.monthlyPayment,
            p.totals.principal,
            p.totals.interest,
            p.totals.total,
          ], everyElement(0));
          expect(p.priceBasis, isNull);
          expect(p.schedule, isEmpty);
        });
        test('ComparePickerUnit', () {
          final p = ComparePickerUnit.fromJson(
            payload(
              {'id': 'u', 'code': 'U'},
              ['status', 'public_code', 'unit_type', 'price_min', 'price_list'],
            ),
          );
          expect([p.id, p.code], ['u', 'U']);
          expect(p.status, '');
          expect([
            p.publicCode,
            p.unitType,
            p.priceMin,
            p.priceList,
          ], everyElement(isNull));
        });
      },
    );
  }
  test(
    'public project parses every nested detail and preserves decimal strings',
    () {
      final p = PublicProject.fromJson({
        ...projectJson('p'),
        'project_type': 'mixed',
        'developer': {
          'id': 'd',
          'name': 'Sun Group',
          'logo_url': null,
          'slug': 'sun',
        },
        'province': 'TP.HCM',
        'district': 'Thủ Đức',
        'ward': 'A',
        'address': 'B',
        'lat': '10.2',
        'lng': '106.3',
        'price_from': '12345678901234567890.12',
        'overview_json': {
          'units': 12,
          'nested': {
            'items': ['one'],
          },
        },
        'documents': [
          {'name': 'CSBH', 'url': 'https://x/doc'},
        ],
        'tour360_url': 'https://360.smartrealtors.vn/a',
        'province_old': 'Bình Dương',
        'district_old': 'B',
        'ward_old': 'C',
        'media': [
          {
            'id': 'm',
            'media_type': 'video',
            'url': 'https://x/video',
            'caption': 'Video',
            'display_order': 1,
            'embed_url': 'https://x/embed',
          },
        ],
        'subdivisions': [
          {'name': 'A', 'code': null, 'description': null, 'cover_url': null},
        ],
        'progress': [
          {
            'title': 'Xây dựng',
            'occurred_on': '2026-01-01',
            'body': null,
            'image_url': null,
          },
        ],
        'faqs': [
          {'id': 'f', 'question': 'Hỏi', 'answer': 'Đáp', 'position': 2},
        ],
      });
      expect(p.code, 'p');
      expect(p.projectType, 'mixed');
      expect(p.developer!.slug, 'sun');
      expect(p.priceFrom, '12345678901234567890.12');
      expect(p.lat, '10.2');
      expect(p.lng, '106.3');
      expect(p.provinceOld, 'Bình Dương');
      expect(p.districtOld, 'B');
      expect(p.wardOld, 'C');
      expect(p.documents.single.name, 'CSBH');
      expect(p.media!.single.embedUrl, 'https://x/embed');
      expect(p.media!.single.displayOrder, 1);
      expect(p.subdivisions!.single.code, isNull);
      expect(p.progress!.single.occurredOn, '2026-01-01');
      expect(p.faqs!.single.position, 2);
      expect(() => p.documents.clear(), throwsUnsupportedError);
      expect(() => p.media!.clear(), throwsUnsupportedError);
      final nested = p.overviewJson!['nested'] as Map<String, dynamic>;
      expect(
        () => (nested['items'] as List<Object?>).clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('summary projects retain nullable omitted details', () {
    final p = PublicProject.fromJson(projectJson('p'));
    expect(p.media, isNull);
    expect(p.subdivisions, isNull);
    expect(p.progress, isNull);
    expect(p.faqs, isNull);
    expect(p.developer, isNull);
    expect(p.overviewJson, isNull);
    expect(p.lat, isNull);
    expect(p.provinceOld, isNull);
  });
  test('malformed optional response fields use neutral defaults', () {
    expect(
      PublicProject.fromJson({...projectJson('p'), 'has_tour360': 'yes'})
          .hasTour360,
      isFalse,
    );
    expect(
      PublicProject.fromJson({
        ...projectJson('p'),
        'documents': [1],
      }).documents,
      isEmpty,
    );
    expect(
      Province.fromJson({
        'name': 'Hà Nội',
        'old_names': [1],
      }).oldNames,
      isEmpty,
    );
  });
  test('developer and post preserve nullable fields and nested project', () {
    final d = PublicDeveloper.fromJson(developerJson);
    expect(d.logoUrl, isNull);
    expect(d.badges, ['Diamond Agent Sun Group']);
    expect(() => d.badges.clear(), throwsUnsupportedError);
    final p = PublicPost.fromJson(postJson);
    expect(p.kind, 'news');
    expect(p.project!.code, 'P');
    expect(p.body, '<p>Nội dung</p>');
    expect(
      PublicPost.fromJson({...postJson, 'project': null, 'body': null}).project,
      isNull,
    );
  });
  test(
    'public loan parses numbers and schedule without authenticated fields',
    () {
      final result = LoanResult.fromJson(loanJson);
      expect(result.price, 1000000000);
      expect(result.floatingRate, 10.5);
      expect(result.totals.total, 800000000);
      expect(result.schedule.single.period, 1);
      expect(result.schedule.single.remaining, 695000000);
      expect(result.priceBasis, isNull);
      expect(() => result.schedule.clear(), throwsUnsupportedError);
    },
  );
}
