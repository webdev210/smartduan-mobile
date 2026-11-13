import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/ui/menu.dart';

void main() {
  test(
    'upstream following menu uses favourite and notification copy/icons',
    () {
      final items = menuGroups([]).expand((g) => g.items);
      final favourite = items.firstWhere((i) => i.key == 'da-luu');
      expect(
        (favourite.label, favourite.hint, favourite.icon),
        ('Dự án yêu thích', 'Các dự án bạn thả tim', 'heart-outline'),
      );
      expect(
        items.firstWhere((i) => i.key == 'quan-tam').icon,
        'notifications-outline',
      );
    },
  );
  List<String> labels(List<String> roles) =>
      menuGroups(roles).expand((g) => g.items).map((i) => i.label).toList();
  test('no role sees public catalog signup profile and loan calculator', () {
    final got = labels([]);
    expect(
      got,
      containsAll([
        'Tất cả dự án trên sàn',
        'Đăng ký làm sale',
        'Hồ sơ của tôi',
        'Tính lãi vay',
      ]),
    );
    for (final s in ['Tìm căn', 'Bảng tin', 'Duyệt tài khoản']) {
      expect(got, isNot(contains(s)));
    }
  });
  test(
    'agent sees sales tools and internal content without administration',
    () {
      final got = labels(['agent']);
      expect(
        got,
        containsAll([
          'Dự án của tôi',
          'Tìm căn',
          'So sánh căn',
          'Bảng tin',
          'Quy trình & đào tạo',
          'Báo cáo',
        ]),
      );
      for (final s in ['Duyệt thiết bị', 'Đăng ký làm sale']) {
        expect(got, isNot(contains(s)));
      }
    },
  );
  test('manager sees team; superadmin sees both approval tools', () {
    expect(
      labels(['manager']),
      containsAll(['Đội của tôi', 'Duyệt thiết bị', 'Duyệt tài khoản']),
    );
    expect(
      labels(['superadmin']),
      containsAll(['Duyệt thiết bị', 'Duyệt tài khoản']),
    );
  });
  test('free sales invited to request F2', () {
    expect(labels(['sales_free']), contains('Xin xác nhận F2'));
  });
  test('technical tools hidden', () {
    for (final r in [
      <String>[],
      ['agent'],
      ['superadmin'],
    ]) {
      expect(labels(r), isNot(contains('Kết nối & nhật ký API')));
    }
  });
  test('groups nonempty and keys unique', () {
    for (final r in [
      <String>[],
      ['agent'],
      ['superadmin'],
      ['sales_free'],
    ]) {
      final groups = menuGroups(r);
      expect(groups.every((g) => g.items.isNotEmpty), true);
      final keys = groups.expand((g) => g.items).map((i) => i.key).toList();
      expect(keys.toSet().length, keys.length);
    }
  });
  test('search without accents including hints', () {
    final groups = menuGroups(['superadmin']);
    expect(searchMenu(groups, 'lai vay').map((i) => i.label), ['Tính lãi vay']);
    expect(searchMenu(groups, 'duyet').map((i) => i.label), [
      'Duyệt thiết bị',
      'Duyệt tài khoản',
    ]);
    expect(searchMenu(groups, 'khong co gi'), isEmpty);
  });
  test('three role appropriate quick actions', () {
    expect(quickActions(['agent']).map((i) => i.label), [
      'Tìm căn',
      'Tính lãi vay',
      'Bảng tin',
    ]);
    expect(quickActions([]).map((i) => i.label), [
      'Tính lãi vay',
      'Tất cả dự án trên sàn',
      'Đăng ký làm sale',
    ]);
  });
  test('readable role names', () {
    expect(rolesLabel([]), 'Chưa có vai trò');
    expect(rolesLabel(['sales_free']), 'Sale tự do');
    expect(rolesLabel(['sales_partner']), 'Đại lý F2');
    expect(rolesLabel(['agent', 'manager']), 'Chuyên viên kinh doanh, Quản lý');
  });
}
