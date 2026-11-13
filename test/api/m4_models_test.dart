import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/api/models.dart';

void main() {
  final models =
      <
        String,
        ({
          Map<String, dynamic> minimal,
          Map<String, dynamic> Function(Map<String, dynamic>) parse,
        })
      >{
        'AdminUser': (
          minimal: {'id': 'id'},
          parse: (j) => AdminUser.fromJson(j).toJson(),
        ),
        'SalesUnitRef': (
          minimal: {'id': 'id', 'name': 'Tên'},
          parse: (j) => SalesUnitRef.fromJson(j).toJson(),
        ),
        'ProfileBranch': (
          minimal: {'id': 'id', 'name': 'Tên'},
          parse: (j) => ProfileBranch.fromJson(j).toJson(),
        ),
        'Profile': (
          minimal: {'id': 'id'},
          parse: (j) => Profile.fromJson(j).toJson(),
        ),
        'Interests': (
          minimal: {},
          parse: (j) => Interests.fromJson(j).toJson(),
        ),
        'Device': (
          minimal: {'id': 'id'},
          parse: (j) => Device.fromJson(j).toJson(),
        ),
        'DownloadLog': (
          minimal: {'id': 'id'},
          parse: (j) => DownloadLog.fromJson(j).toJson(),
        ),
        'AnomalyUser': (
          minimal: {'id': 'id'},
          parse: (j) => AnomalyUser.fromJson(j).toJson(),
        ),
        'DeviceUser': (
          minimal: {'id': 'id'},
          parse: (j) => DeviceUser.fromJson(j).toJson(),
        ),
        'AdminDevice': (
          minimal: {'id': 'id'},
          parse: (j) => AdminDevice.fromJson(j).toJson(),
        ),
        'SharedDevice': (
          minimal: {'device_id': 'id'},
          parse: (j) => SharedDevice.fromJson(j).toJson(),
        ),
        'IpNetwork': (
          minimal: {},
          parse: (j) => IpNetwork.fromJson(j).toJson(),
        ),
        'DeviceAnomalies': (
          minimal: {},
          parse: (j) => DeviceAnomalies.fromJson(j).toJson(),
        ),
        'InventoryReportRow': (
          minimal: {'project_id': 'id'},
          parse: (j) => InventoryReportRow.fromJson(j).toJson(),
        ),
        'AttentionBlock': (
          minimal: {},
          parse: (j) => AttentionBlock.fromJson(j).toJson(),
        ),
        'Attention': (
          minimal: {},
          parse: (j) => Attention.fromJson(j).toJson(),
        ),
        'RecentChange': (
          minimal: {'unit_id': 'id'},
          parse: (j) => RecentChange.fromJson(j).toJson(),
        ),
        'BookingWeek': (
          minimal: {},
          parse: (j) => BookingWeek.fromJson(j).toJson(),
        ),
        'BookingsWeekly': (
          minimal: {},
          parse: (j) => BookingsWeekly.fromJson(j).toJson(),
        ),
        'InventoryUpdateRow': (
          minimal: {'project_id': 'id'},
          parse: (j) => InventoryUpdateRow.fromJson(j).toJson(),
        ),
        'InventoryUpdates': (
          minimal: {},
          parse: (j) => InventoryUpdates.fromJson(j).toJson(),
        ),
        'ActiveSalesRole': (
          minimal: {},
          parse: (j) => ActiveSalesRole.fromJson(j).toJson(),
        ),
        'ActiveSalesBranch': (
          minimal: {},
          parse: (j) => ActiveSalesBranch.fromJson(j).toJson(),
        ),
        'ActiveSales': (
          minimal: {},
          parse: (j) => ActiveSales.fromJson(j).toJson(),
        ),
        'SurveyMissing': (
          minimal: {},
          parse: (j) => SurveyMissing.fromJson(j).toJson(),
        ),
        'SurveyReport': (
          minimal: {},
          parse: (j) => SurveyReport.fromJson(j).toJson(),
        ),
        'ListingsUser': (
          minimal: {'user_id': 'id'},
          parse: (j) => ListingsUser.fromJson(j).toJson(),
        ),
        'ListingsProject': (
          minimal: {'project_id': 'id'},
          parse: (j) => ListingsProject.fromJson(j).toJson(),
        ),
        'ListingsReport': (
          minimal: {},
          parse: (j) => ListingsReport.fromJson(j).toJson(),
        ),
      };
  for (final MapEntry(key: name, value: model) in models.entries) {
    test(
      '$name accepts absent and null non-identity fields and roundtrips defaults',
      () {
        final parsed = model.parse(model.minimal);
        final withNulls = {
          for (final key in parsed.keys) key: null,
          ...model.minimal,
        };
        expect(model.parse(withNulls), parsed);
        expect(model.parse(parsed), parsed);
        for (final key in model.minimal.keys) {
          expect(
            () => model.parse({...model.minimal, key: null}),
            throwsFormatException,
          );
        }
      },
    );
  }
  test(
    'profile nested identities and Vietnamese names survive serialization',
    () {
      final j = <String, dynamic>{
        'id': 'u',
        'email': 'a@x.vn',
        'full_name': 'Nguyễn An',
        'phone': '0900000000',
        'address': 'Thành phố Hồ Chí Minh',
        'status': 'active',
        'sales_code': 'SALE',
        'roles': ['agent'],
        'region': 'nam',
        'interested_project_ids': ['p'],
        'branch': {
          'id': 'b',
          'code': null,
          'name': 'Chi nhánh',
          'province': null,
        },
        'sales_unit': {'id': 's', 'name': 'Đơn vị'},
      };
      final profile = Profile.fromJson(j);
      expect(profile.toJson(), j);
      expect(profile.branch?.code, isNull);
      expect(profile.salesUnit?.name, 'Đơn vị');
      expect(() => profile.roles.clear(), throwsUnsupportedError);
      expect(
        () => profile.interestedProjectIds.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('interests encode exact write payload and own an immutable copy', () {
    final ids = ['p'];
    final interests = Interests(region: 'nam', interestedProjectIds: ids);
    ids.clear();
    expect(interests.toJson(), {
      'region': 'nam',
      'interested_project_ids': ['p'],
    });
    expect(
      () => interests.interestedProjectIds.clear(),
      throwsUnsupportedError,
    );
  });
  test('download logs and devices retain full wire payloads', () {
    final download = <String, dynamic>{
      'id': 'd',
      'document_id': 'doc',
      'document_title': 'Bảng giá',
      'doc_type': 'price',
      'project_id': 'p',
      'downloaded_at': '2026-11-12',
      'expires_at': null,
      'requested_at': '2026-11-11',
    };
    expect(DownloadLog.fromJson(download).toJson(), download);
    final device = <String, dynamic>{
      'id': 'd',
      'kind': 'mobile',
      'label': 'Điện thoại',
      'status': 'approved',
      'first_seen_at': '2026-11-01',
      'last_seen_at': '2026-11-12',
      'last_ip': '127.0.0.1',
      'expires_at': null,
    };
    expect(Device.fromJson(device).toJson(), device);
  });
}
