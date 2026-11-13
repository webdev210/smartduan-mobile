/// UI visibility only; the backend always enforces authorization.
typedef Roles = List<String>?;
const _rank = {
  'denied': 0,
  'public': 1,
  'own': 2,
  'unit': 3,
  'allocated': 4,
  'assigned': 5,
  'all': 6,
};
const matrix = {
  "view_units": {
    "agent": "allocated",
    "manager": "all",
    "admin": "assigned",
    "superadmin": "all",
    "sales_partner": "allocated",
    "sales_free": "public",
  },
  "view_projects": {
    "agent": "allocated",
    "manager": "all",
    "admin": "assigned",
    "superadmin": "all",
    "sales_partner": "allocated",
    "sales_free": "public",
  },
  "declare_booking": {
    "agent": "all",
    "manager": "all",
    "admin": "assigned",
    "superadmin": "all",
  },
  "manage_bookings": {
    "manager": "own",
    "admin": "assigned",
    "superadmin": "all",
  },
  "update_inventory": {"admin": "assigned", "superadmin": "all"},
  "hold": {"admin": "assigned", "superadmin": "all"},
  "release_hold": {"admin": "assigned", "superadmin": "all"},
  "configure_project": {"admin": "assigned", "superadmin": "all"},
  "manage_users": {"admin": "all"},
  "manage_settings": {"superadmin": "all"},
  "manage_funds": {"admin": "assigned", "superadmin": "all"},
  "view_viewer_log": {"superadmin": "all"},
  "publish_policy": {"admin": "assigned", "superadmin": "all"},
  "manage_content": {"admin": "all"},
  "manage_listing_templates": {"admin": "assigned", "superadmin": "all"},
  "manage_global_listing_template": {"admin": "all"},
  "view_training": {"agent": "all", "manager": "all", "admin": "all"},
  "view_reports": {
    "agent": "own",
    "manager": "unit",
    "admin": "assigned",
    "superadmin": "all",
  },
  "approve_devices": {"admin": "all", "superadmin": "all", "manager": "unit"},
  "allow_device_exception": {"superadmin": "all"},
  "approve_accounts": {"admin": "all", "manager": "unit"},
};
String scopeFor(Roles roles, String action) {
  final row = matrix[action];
  var best = 'denied';
  final held = [...?roles, if (roles?.contains('superadmin') ?? false) 'admin'];
  for (final role in held) {
    final scope = row?[role];
    if (scope != null && _rank[scope]! > _rank[best]!) best = scope;
  }
  return best;
}

bool can(Roles roles, String action) => scopeFor(roles, action) != 'denied';
bool isPartner(Roles roles) => roles?.contains('sales_partner') ?? false;
bool isFreeSales(Roles roles) =>
    (roles?.contains('sales_free') ?? false) &&
    scopeFor(roles, 'view_units') == 'public';
bool isManager(Roles roles) => roles?.contains('manager') ?? false;
bool hasNoRole(Roles roles) => roles == null || roles.isEmpty;
const _roleLabel = {
  "agent": "Chuyên viên kinh doanh",
  "manager": "Quản lý",
  "admin": "Quản trị",
  "superadmin": "Quản trị cấp cao",
  "sales_partner": "Đại lý F2",
  "sales_free": "Sale tự do",
};
String roleName(String role) => _roleLabel[role] ?? role;
const listingsEnabled = false;
const bookingsEnabled = false;
const plansEnabled = false;
const compareEnabled = true;
String notAssignedText(Roles roles) => switch (scopeFor(roles, 'view_units')) {
  'all' => "Không tìm thấy dự án này — có thể đã bị xoá hoặc ẩn.",
  'assigned' => "Dự án này chưa được phân cho tài khoản quản trị của bạn. Admin chỉ xem được bảng hàng các dự án superadmin đã phân — liên hệ superadmin để được phân dự án.",
  _ => "Dự án này chưa được phân bổ cho đơn vị kinh doanh của bạn — liên hệ quản lý để được mở bảng hàng.",
};
final Map<String, bool Function(Roles)> screens = {
  "overview": (Roles r) => true,
  "projects": (Roles r) => can(r, "view_projects"),
  "salesFloor": (Roles r) => can(r, "view_units"),
  "compare": (Roles r) => compareEnabled && can(r, "view_units"),
  "listings": (Roles r) => listingsEnabled && can(r, "view_units"),
  "declareBooking": (Roles r) => bookingsEnabled && can(r, "declare_booking"),
  "reviewBookings": (Roles r) => bookingsEnabled && isManager(r),
  "team": (Roles r) => isManager(r),
  "announcements": (Roles r) => !hasNoRole(r),
  "training": (Roles r) => can(r, "view_training"),
  "reports": (Roles r) => can(r, "view_reports"),
  "devices": (Roles r) => can(r, "approve_devices"),
  "accounts": (Roles r) => can(r, "approve_accounts"),
  "shareLinks": (Roles r) =>
      !["denied", "public"].contains(scopeFor(r, "view_units")),
  "becomeSales": (Roles r) => hasNoRole(r),
  "requestF2": (Roles r) => (r ?? []).contains("sales_free") && !isPartner(r),
};
