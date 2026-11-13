import 'package:flutter_test/flutter_test.dart';
import 'package:smartduan/auth/roles.dart';

void main() {
  group("404 ở chi tiết dự án theo vai trò (policy.ex)", () {
    test("admin thường chỉ thấy dự án được phân; superadmin thấy hết", () {
      expect(scopeFor(["admin"], "view_units"), "assigned");
      expect(scopeFor(["superadmin"], "view_units"), "all");
    });
    test("admin → hướng dẫn xin superadmin phân dự án", () {
      expect(notAssignedText(["admin"]), matches(r"superadmin"));
    });
    test("superadmin/manager → không phải chuyện phân quyền", () {
      expect(notAssignedText(["superadmin"]), matches(r"xoá hoặc ẩn"));
      expect(notAssignedText(["manager"]), matches(r"xoá hoặc ẩn"));
    });
    test("chuyên viên/F2 → chưa phân bổ cho đơn vị", () {
      expect(notAssignedText(["agent"]), matches(r"đơn vị kinh doanh"));
    });
  });

  // Expected scopes copied from the RN policy matrix, in the fixed role order below.
  const heldRoles = <String?>[
    'agent',
    'manager',
    'admin',
    'superadmin',
    'sales_partner',
    'sales_free',
    'unknown',
    null,
  ];
  const expectedScopes = <String, List<String>>{
    "view_units": [
      "allocated",
      "all",
      "assigned",
      "all",
      "allocated",
      "public",
      "denied",
      "denied",
    ],
    "view_projects": [
      "allocated",
      "all",
      "assigned",
      "all",
      "allocated",
      "public",
      "denied",
      "denied",
    ],
    "declare_booking": [
      "all",
      "all",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "manage_bookings": [
      "denied",
      "own",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "update_inventory": [
      "denied",
      "denied",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "hold": [
      "denied",
      "denied",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "release_hold": [
      "denied",
      "denied",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "configure_project": [
      "denied",
      "denied",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "manage_users": [
      "denied",
      "denied",
      "all",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "manage_settings": [
      "denied",
      "denied",
      "denied",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "manage_funds": [
      "denied",
      "denied",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "view_viewer_log": [
      "denied",
      "denied",
      "denied",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "publish_policy": [
      "denied",
      "denied",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "manage_content": [
      "denied",
      "denied",
      "all",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "manage_listing_templates": [
      "denied",
      "denied",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "manage_global_listing_template": [
      "denied",
      "denied",
      "all",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "view_training": [
      "all",
      "all",
      "all",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "view_reports": [
      "own",
      "unit",
      "assigned",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "approve_devices": [
      "denied",
      "unit",
      "all",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "allow_device_exception": [
      "denied",
      "denied",
      "denied",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
    "approve_accounts": [
      "denied",
      "unit",
      "all",
      "all",
      "denied",
      "denied",
      "denied",
      "denied",
    ],
  };
  for (final MapEntry(key: action, value: expected) in expectedScopes.entries) {
    for (var i = 0; i < heldRoles.length; i++) {
      final role = heldRoles[i];
      test('$action / ${role ?? "guest"}', () {
        final roles = role == null ? null : [role];
        expect(scopeFor(roles, action), expected[i]);
        expect(can(roles, action), expected[i] != 'denied');
      });
    }
  }
  test('multiple roles take the widest scope; superadmin inherits admin', () {
    expect(scopeFor(['sales_free', 'agent'], 'view_units'), 'allocated');
    expect(scopeFor(['admin', 'manager'], 'view_units'), 'all');
    expect(can(['superadmin'], 'manage_users'), true);
    expect(scopeFor([], 'view_units'), 'denied');
  });
  test('role predicates, labels and feature flags', () {
    expect(isPartner(['sales_partner']), true);
    expect(isPartner(null), false);
    expect(isFreeSales(['sales_free']), true);
    expect(isFreeSales(['sales_free', 'agent']), false);
    expect(isManager(['manager']), true);
    expect(isManager(null), false);
    expect(hasNoRole(null), true);
    expect(hasNoRole([]), true);
    expect(hasNoRole(['unknown']), false);
    expect(roleName('unknown'), 'unknown');
    expect(
      [listingsEnabled, bookingsEnabled, plansEnabled, compareEnabled],
      [false, false, false, true],
    );
  });
  const gates = <String, List<String>>{
    'guest': ['overview', 'becomeSales'],
    'agent': [
      'overview',
      'projects',
      'salesFloor',
      'compare',
      'announcements',
      'training',
      'reports',
      'shareLinks',
    ],
    'manager': [
      'overview',
      'projects',
      'salesFloor',
      'compare',
      'team',
      'announcements',
      'training',
      'reports',
      'devices',
      'accounts',
      'shareLinks',
    ],
    'admin': [
      'overview',
      'projects',
      'salesFloor',
      'compare',
      'announcements',
      'training',
      'reports',
      'devices',
      'accounts',
      'shareLinks',
    ],
    'superadmin': [
      'overview',
      'projects',
      'salesFloor',
      'compare',
      'announcements',
      'training',
      'reports',
      'devices',
      'accounts',
      'shareLinks',
    ],
    'sales_partner': [
      'overview',
      'projects',
      'salesFloor',
      'compare',
      'announcements',
      'shareLinks',
    ],
    'sales_free': [
      'overview',
      'projects',
      'salesFloor',
      'compare',
      'announcements',
      'requestF2',
    ],
    'unknown': ['overview', 'announcements'],
  };
  for (final MapEntry(key: role, value: expected) in gates.entries) {
    test('screen gates / $role', () {
      final roles = role == 'guest' ? null : [role];
      expect([
        for (final MapEntry(:key, :value) in screens.entries)
          if (value(roles)) key,
      ], expected);
    });
  }
}
