import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';

void main() {
  group('tolerant JSON readers', () {
    test('strings accept numbers and ignore other types', () {
      final unit = Unit.fromJson({
        'id': 'u',
        'code': 'U',
        'price_min': 400000000,
        'area_net': 50.5,
        'direction': <Object?>[],
        'status': false,
      });
      expect(unit.priceMin, '400000000');
      expect(unit.areaNet, '50.5');
      expect(unit.direction, isNull);
      expect(unit.status, '');
    });
    test('integers accept numeric strings and numbers, ignore bad types', () {
      final unit = Unit.fromJson({
        'id': 'u',
        'code': 'U',
        'floor': '8',
        'bedrooms': 2.0,
        'version': <String, Object?>{},
      });
      expect(unit.floor, 8);
      expect(unit.bedrooms, 2);
      expect(unit.version, 0);
      expect(
        TopUnits.fromJson({
          'bedrooms': ['2', 3.0, false],
        }).bedrooms,
        [2, 3],
      );
    });
    test('numbers accept numeric strings and ignore invalid values', () {
      expect(
        TopUnit.fromJson({'id': 'u', 'code': 'U', 'score': '1.5'}).score,
        1.5,
      );
      for (final value in [true, <Object?>[], <String, Object?>{}, 'bad']) {
        expect(
          TopUnit.fromJson({'id': 'u', 'code': 'U', 'score': value}).score,
          isNull,
        );
      }
    });
    test('booleans accept only booleans', () {
      for (final value in ['true', 1, <Object?>[], <String, Object?>{}]) {
        expect(
          Unit.fromJson({'id': 'u', 'code': 'U', 'top_pick': value}).topPick,
          isFalse,
        );
      }
      expect(
        Unit.fromJson({'id': 'u', 'code': 'U', 'top_pick': true}).topPick,
        isTrue,
      );
    });
    test('object lists ignore wrong containers and non-object entries', () {
      expect(
        TopUnits.fromJson({'groups': <String, Object?>{}}).groups,
        isEmpty,
      );
      final groups = TopUnits.fromJson({
        'groups': [
          null,
          1,
          <Object?>[],
          {'available': '3'},
        ],
      }).groups;
      expect(groups.single.available, 3);
      expect(
        () => TopUnitGroup.fromJson({
          'units': [
            {'code': 'U'},
          ],
        }),
        throwsFormatException,
      );
    });
    test('string lists ignore wrong containers and non-string entries', () {
      expect(TeamMember.fromJson({'id': 'u', 'roles': true}).roles, isEmpty);
      expect(
        TeamMember.fromJson({
          'id': 'u',
          'roles': ['sales', 1, null, <String, Object?>{}],
        }).roles,
        ['sales'],
      );
    });
    test('nested objects ignore wrong types but validate child identity', () {
      expect(
        AdminBooking.fromJson({'id': 'b', 'project': <Object?>[]}).project,
        isNull,
      );
      expect(
        () =>
            AdminBooking.fromJson({'id': 'b', 'project': <String, Object?>{}}),
        throwsFormatException,
      );
      expect(
        Project.fromJson({
          'id': 'p',
          'code': 'P',
          'name': 'Project',
          'overview_json': false,
        }).overviewJson,
        isNull,
      );
    });
    test('typed maps ignore wrong containers and default bad values', () {
      final enums = Enums.fromJson({
        'direction_labels': <Object?>[],
        'fund_labels': {'a': 42, 'b': <Object?>[]},
        'fund_colors': {'a': false},
        'fund_visible_to_free': {'a': 'true', 'b': true},
      });
      expect(enums.directionLabels, isEmpty);
      expect(enums.fundLabels, {'a': '42', 'b': ''});
      expect(enums.fundColors, {'a': null});
      expect(enums.fundVisibleToFree, {'a': false, 'b': true});
    });
    test(
      'partial snapshots tolerate bad optional types and retain presence',
      () {
        final unit = PartialUnit.fromJson({
          'floor': '8',
          'price_min': 42,
          'top_pick': <Object?>[],
          'attributes': false,
        });
        expect(unit.floor, 8);
        expect(unit.priceMin, '42');
        expect(unit.topPick, isNull);
        expect(unit.attributes, isNull);
        expect(unit.contains('attributes'), isTrue);
      },
    );
    test('top unit decodes the live payload with a reasons list', () {
      final unit = TopUnit.fromJson({
        'id': 'u',
        'code': 'T1-08-01',
        'floor': 8,
        'area': '50.5',
        'axis': '01',
        'why': <Object?>[],
        'price_min': '400000000',
        'price_min_label': 'Giá niêm yết',
        'score': 0,
        'area_field': 'area_net',
      });
      expect(unit.why, isEmpty);
      expect(unit.code, 'T1-08-01');
      expect(unit.floor, 8);
      expect(unit.area, '50.5');
      expect(unit.priceMin, '400000000');
      expect(unit.priceMinLabel, 'Giá niêm yết');
      expect(unit.score, 0);
      expect(unit.toJson()['why'], isEmpty);
    });
    test('top unit accepts old string reasons and preserves reason lists', () {
      expect(TopUnit.fromJson({'id': 'u', 'code': 'U', 'why': 'Giá tốt'}).why, [
        'Giá tốt',
      ]);
      final unit = TopUnit.fromJson({
        'id': 'u',
        'code': 'U',
        'why': ['Giá tốt', 'View đẹp'],
      });
      expect(unit.why, ['Giá tốt', 'View đẹp']);
      expect(TopUnit.fromJson(unit.toJson()).why, ['Giá tốt', 'View đẹp']);
      expect(
        TopUnit.fromJson({'id': 'u', 'code': 'U', 'why': false}).why,
        isEmpty,
      );
    });
  });
  final codecs =
      <
        String,
        ({
          Map<String, dynamic> Function(Map<String, dynamic>) roundtrip,
          Set<String> identity,
        })
      >{
        'Project': (
          roundtrip: (j) => Project.fromJson(j).toJson(),
          identity: <String>{'code', 'id', 'name'},
        ),
        'BlockRef': (
          roundtrip: (j) => BlockRef.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'Floor': (
          roundtrip: (j) => Floor.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'Block': (
          roundtrip: (j) => Block.fromJson(j).toJson(),
          identity: <String>{'id', 'name'},
        ),
        'ExtraPrice': (
          roundtrip: (j) => ExtraPrice.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'Unit': (
          roundtrip: (j) => Unit.fromJson(j).toJson(),
          identity: <String>{'code', 'id'},
        ),
        'RelatedUnit': (
          roundtrip: (j) => RelatedUnit.fromJson(j).toJson(),
          identity: <String>{'code'},
        ),
        'AxisMeta': (
          roundtrip: (j) => AxisMeta.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'StackCell': (
          roundtrip: (j) => StackCell.fromJson(j).toJson(),
          identity: <String>{'code', 'id'},
        ),
        'StackFloor': (
          roundtrip: (j) => StackFloor.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'StackPlan': (
          roundtrip: (j) => StackPlan.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'Policy': (
          roundtrip: (j) => Policy.fromJson(j).toJson(),
          identity: <String>{'id', 'title'},
        ),
        'Doc': (
          roundtrip: (j) => Doc.fromJson(j).toJson(),
          identity: <String>{'id', 'title'},
        ),
        'MediaItem': (
          roundtrip: (j) => MediaItem.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'ProgressItem': (
          roundtrip: (j) => ProgressItem.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'Faq': (
          roundtrip: (j) => Faq.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'Contact': (
          roundtrip: (j) => Contact.fromJson(j).toJson(),
          identity: <String>{'full_name'},
        ),
        'Booking': (
          roundtrip: (j) => Booking.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'SaleRef': (
          roundtrip: (j) => SaleRef.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'AdminBooking': (
          roundtrip: (j) => AdminBooking.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'HistoryRow': (
          roundtrip: (j) => HistoryRow.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'SearchProject': (
          roundtrip: (j) => SearchProject.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'SearchRow': (
          roundtrip: (j) => SearchRow.fromJson(j).toJson(),
          identity: <String>{'code', 'id'},
        ),
        'SavedFilter': (
          roundtrip: (j) => SavedFilter.fromJson(j).toJson(),
          identity: <String>{'id', 'name'},
        ),
        'Enums': (
          roundtrip: (j) => Enums.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'Plan': (
          roundtrip: (j) => Plan.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'Point': (
          roundtrip: (j) => Point.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'Pin': (
          roundtrip: (j) => Pin.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'ListingImage': (
          roundtrip: (j) => ListingImage.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'ListingTemplate': (
          roundtrip: (j) => ListingTemplate.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'Listing': (
          roundtrip: (j) => Listing.fromJson(j).toJson(),
          identity: <String>{'title'},
        ),
        'Notification': (
          roundtrip: (j) => Notification.fromJson(j).toJson(),
          identity: <String>{'id', 'title'},
        ),
        'Notifications': (
          roundtrip: (j) => Notifications.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'AnnouncementSummary': (
          roundtrip: (j) => AnnouncementSummary.fromJson(j).toJson(),
          identity: <String>{'id', 'title'},
        ),
        'ManagerOption': (
          roundtrip: (j) => ManagerOption.fromJson(j).toJson(),
          identity: <String>{'full_name', 'id'},
        ),
        'TeamMember': (
          roundtrip: (j) => TeamMember.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'Team': (
          roundtrip: (j) => Team.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'ProcessPage': (
          roundtrip: (j) => ProcessPage.fromJson(j).toJson(),
          identity: <String>{'id', 'slug', 'title'},
        ),
        'TopUnit': (
          roundtrip: (j) => TopUnit.fromJson(j).toJson(),
          identity: <String>{'code', 'id'},
        ),
        'TopUnitGroup': (
          roundtrip: (j) => TopUnitGroup.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'TopUnits': (
          roundtrip: (j) => TopUnits.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'Subdivision': (
          roundtrip: (j) => Subdivision.fromJson(j).toJson(),
          identity: <String>{'block_id', 'name'},
        ),
        'ShareLink': (
          roundtrip: (j) => ShareLink.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'PresentationBoard': (
          roundtrip: (j) => PresentationBoard.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'UnitImage': (
          roundtrip: (j) => UnitImage.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'PriceSheet': (
          roundtrip: (j) => PriceSheet.fromJson(j).toJson(),
          identity: <String>{'id'},
        ),
        'UnitImages': (
          roundtrip: (j) => UnitImages.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'ComparePolicy': (
          roundtrip: (j) => ComparePolicy.fromJson(j).toJson(),
          identity: <String>{'name'},
        ),
        'CompareSet': (
          roundtrip: (j) => CompareSet.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'Branch': (
          roundtrip: (j) => Branch.fromJson(j).toJson(),
          identity: <String>{'code', 'id', 'name'},
        ),
        'UnitRef': (
          roundtrip: (j) => UnitRef.fromJson(j).toJson(),
          identity: <String>{'code', 'id'},
        ),
        'ProjectViewRow': (
          roundtrip: (j) => ProjectViewRow.fromJson(j).toJson(),
          identity: <String>{'project_id'},
        ),
        'RolesResult': (
          roundtrip: (j) => RolesResult.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'F2Request': (
          roundtrip: (j) => F2Request.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'NotificationsRead': (
          roundtrip: (j) => NotificationsRead.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'ConsultResult': (
          roundtrip: (j) => ConsultResult.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'ProcessAccessResult': (
          roundtrip: (j) => ProcessAccessResult.fromJson(j).toJson(),
          identity: <String>{},
        ),
        'UnitDetail': (
          roundtrip: (j) => UnitDetail.fromJson(j).toJson(),
          identity: <String>{'code', 'id'},
        ),
        'CompareUnit': (
          roundtrip: (j) => CompareUnit.fromJson(j).toJson(),
          identity: <String>{'code', 'id'},
        ),
        'AnnouncementDetail': (
          roundtrip: (j) => AnnouncementDetail.fromJson(j).toJson(),
          identity: <String>{'id', 'title'},
        ),
      };
  for (final entry in codecs.entries) {
    test(
      '${entry.key} tolerates wrong optional types and validates identity',
      () {
        final codec = entry.value;
        final fixture = <String, dynamic>{
          for (final id in codec.identity) id: id,
          if (entry.key == 'StackPlan') 'block': {'id': 'b'},
        };
        final parsed = codec.roundtrip(fixture);
        expect(
          () => codec.roundtrip({
            ...fixture,
            for (final field in parsed.entries)
              if (!codec.identity.contains(field.key) && field.key != 'block')
                field.key: field.value is bool ? <String, dynamic>{} : false,
          }),
          returnsNormally,
        );
        for (final key in codec.identity) {
          for (final value in [
            null,
            42,
            true,
            <Object?>[],
            <String, Object?>{},
          ]) {
            expect(
              () => codec.roundtrip({...fixture, key: value}),
              throwsFormatException,
            );
          }
        }
      },
    );
    test(
      '${entry.key} tolerates omitted/null optional fields and roundtrips',
      () {
        final codec = entry.value;
        final fixture = <String, dynamic>{
          for (final id in codec.identity) id: id,
          if (entry.key == 'StackPlan') 'block': {'id': 'b'},
        };
        final parsed = codec.roundtrip(fixture);
        expect(codec.roundtrip(parsed), parsed);
        final nullable = <String, dynamic>{
          ...fixture,
          for (final key in parsed.keys)
            if (!codec.identity.contains(key) && key != 'block') key: null,
        };
        expect(() => codec.roundtrip(nullable), returnsNormally);
      },
    );
  }
  test('partial snapshot preserves absence versus explicit null', () {
    final missing = PartialUnit.fromJson({'id': 'u', 'status': 'sold'});
    final cleared = PartialUnit.fromJson({'id': 'u', 'fund': null});
    expect(missing.contains('fund'), isFalse);
    expect(cleared.contains('fund'), isTrue);
    expect(missing.code, isNull);
    expect(cleared.toJson()['fund'], isNull);
  });
  test('patch validates identity and version, retains explicit null fund', () {
    final patch = UnitPatch.fromJson({
      'unit_id': 'u',
      'status': 'sold',
      'version': 2,
      'fund': null,
    });
    expect(patch.hasFund, isTrue);
    expect(patch.fund, isNull);
    expect(patch.unitId, 'u');
    expect(UnitPatch(unitId: 'u', status: 'sold', version: 1).hasFund, isFalse);
    expect(() => UnitPatch.fromJson({'unit_id': 'u'}), throwsFormatException);
  });
  test(
    'unit identity remains required and decimal prices remain exact strings',
    () {
      expect(() => Unit.fromJson({'id': 'u'}), throwsFormatException);
      final u = Unit.fromJson({
        'id': 'u',
        'code': 'U',
        'price_min': '1234567890.123456',
      });
      expect(u.priceMin, '1234567890.123456');
      expect(u.extraPrices, isEmpty);
      expect(u.topPick, isFalse);
    },
  );
  test('loan accepts signed-in metadata and omitted optional fields', () {
    final r = LoanResult.fromJson({
      'terms_source': 'policy',
      'fund': 'f',
      'max_loan_ratio': 80,
    });
    expect(r.termsSource, 'policy');
    expect(r.maxLoanRatio, 80);
    expect(r.schedule, isEmpty);
    expect(r.totals.total, 0);
  });
  test('query keys use value equality independently of map ordering', () {
    expect(ApiParams({'a': 1, 'b': 'x'}), ApiParams({'b': 'x', 'a': 1}));
    expect(
      ApiParams({'a': 1, 'b': 'x'}).hashCode,
      ApiParams({'b': 'x', 'a': 1}).hashCode,
    );
    expect(ApiParams({'a': null}), isNot(ApiParams({'b': null})));
    expect(() => ApiParams({'a': <Object?>[]}), throwsArgumentError);
  });
}
