import '../auth/roles.dart';

typedef MenuItem = ({
  String key,
  String label,
  String hint,
  String icon,
  String href,
});
typedef MenuGroup = ({String title, List<MenuItem> items});
List<MenuGroup> menuGroups(Roles roles) {
  final onFloor = screens['salesFloor']!(roles);
  final groups = <MenuGroup>[
    (
      title: "Bán hàng",
      items: <MenuItem>[
        if (screens['projects']!(roles))
          (
            key: "du-an",
            label: "Dự án của tôi",
            hint: "Bảng hàng, chính sách, tài liệu các dự án được phân bổ",
            icon: "business-outline",
            href: "/du-an",
          ),
        if (onFloor)
          (
            key: "tim-can",
            label: "Tìm căn",
            hint: "Lọc căn theo mã, loại, hướng, trạng thái",
            icon: "search-outline",
            href: "/tim-can",
          ),
        if (screens['compare']!(roles))
          (
            key: "so-sanh",
            label: "So sánh căn",
            hint: "Đặt các căn cạnh nhau để chọn",
            icon: "git-compare-outline",
            href: "/so-sanh",
          ),
        (
          key: "lai-vay",
          label: "Tính lãi vay",
          hint: "Ước tính khoản trả hàng tháng",
          icon: "calculator-outline",
          href: onFloor ? "/lai-vay" : "/tinh-lai-vay",
        ),
        if (screens['declareBooking']!(roles) ||
            screens['reviewBookings']!(roles))
          (
            key: "booking",
            label: "Booking",
            hint: "Khai báo và xác nhận booking",
            icon: "bookmark-outline",
            href: "/booking",
          ),
        (
          key: "kham-pha",
          label: "Tất cả dự án trên sàn",
          hint: "Danh mục công khai: tìm theo tỉnh, chủ đầu tư, loại hình",
          icon: "globe-outline",
          href: "/kham-pha",
        ),
      ],
    ),
    (
      title: "Theo dõi",
      items: <MenuItem>[
        (
          key: "quan-tam",
          label: "Dự án quan tâm",
          hint: "Chọn miền và dự án để nhận thông báo",
          icon: "notifications-outline",
          href: "/quan-tam",
        ),
        (
          key: "da-luu",
          label: "Dự án yêu thích",
          hint: "Các dự án bạn thả tim",
          icon: "heart-outline",
          href: "/da-luu",
        ),
        (
          key: "tu-van",
          label: "Yêu cầu tư vấn",
          hint: "Nhờ sàn liên hệ hỗ trợ",
          icon: "chatbubbles-outline",
          href: "/tu-van",
        ),
      ],
    ),
    (
      title: "Nội bộ",
      items: <MenuItem>[
        if (screens['announcements']!(roles))
          (
            key: "bang-tin",
            label: "Bảng tin",
            hint: "Thông báo, tin mới từ sàn",
            icon: "newspaper-outline",
            href: "/bang-tin",
          ),
        if (screens['training']!(roles))
          (
            key: "quy-trinh",
            label: "Quy trình & đào tạo",
            hint: "Hướng dẫn nghiệp vụ, tài liệu học",
            icon: "school-outline",
            href: "/quy-trinh",
          ),
        if (screens['team']!(roles))
          (
            key: "doi-cua-toi",
            label: "Đội của tôi",
            hint: "Thành viên đại lý, lần đăng nhập gần nhất",
            icon: "people-outline",
            href: "/doi-cua-toi",
          ),
        if (screens['reports']!(roles))
          (
            key: "bao-cao",
            label: "Báo cáo",
            hint: "Số liệu hoạt động và kết quả",
            icon: "bar-chart-outline",
            href: "/bao-cao",
          ),
      ],
    ),
    (
      title: "Quản trị",
      items: <MenuItem>[
        if (screens['devices']!(roles))
          (
            key: "duyet-thiet-bi",
            label: "Duyệt thiết bị",
            hint: "Cho phép hoặc thu hồi máy đăng nhập",
            icon: "phone-portrait-outline",
            href: "/duyet-thiet-bi",
          ),
        if (screens['accounts']!(roles))
          (
            key: "duyet-tai-khoan",
            label: "Duyệt tài khoản",
            hint: "Kích hoạt, khoá tài khoản và hồ sơ F2",
            icon: "person-add-outline",
            href: "/duyet-tai-khoan",
          ),
      ],
    ),
    (
      title: "Tài khoản",
      items: <MenuItem>[
        (
          key: "ho-so",
          label: "Hồ sơ của tôi",
          hint: "Thông tin, thiết bị đăng nhập, tài liệu đã tải",
          icon: "person-circle-outline",
          href: "/ho-so",
        ),
        if (screens['becomeSales']!(roles) || screens['requestF2']!(roles))
          (
            key: "len-sale",
            label: hasNoRole(roles) ? "Đăng ký làm sale" : "Xin xác nhận F2",
            hint: hasNoRole(roles)
                ? "Trở thành sale tự do để xem danh mục dự án"
                : "Gửi yêu cầu lên F2 để xem bảng hàng đại lý",
            icon: "rocket-outline",
            href: "/len-sale",
          ),
        (
          key: "chinh-sach",
          label: "Chính sách bảo vệ dữ liệu",
          hint: "Toàn văn chính sách đang áp dụng",
          icon: "document-lock-outline",
          href: "/chinh-sach-bao-mat",
        ),
      ],
    ),
  ];
  return groups.where((g) => g.items.isNotEmpty).toList();
}

const _accents = {
  "àáâãäåāăąǎǟǡǻȁȃȧḁạảấầẩẫậắằẳẵặ": "a",
  "çćĉċčḉ": "c",
  "èéêëēĕėęěȅȇȩḕḗḙḛḝẹẻẽếềểễệ": "e",
  "i̇ìíîïĩīĭįǐȉȋḭḯỉị": "i",
  "ñńņňǹṅṇṉṋ": "n",
  "òóôõöōŏőơǒǫǭȍȏȫȭȯȱṍṏṑṓọỏốồổỗộớờởỡợ": "o",
  "ùúûüũūŭůűųưǔǖǘǚǜȕȗṳṵṷṹṻụủứừửữự": "u",
  "ýÿŷȳẏẙỳỵỷỹ": "y",
  "ďḋḍḏḑḓ": "d",
  "ĝğġģǧǵḡ": "g",
  "ĥȟḣḥḧḩḫẖ": "h",
  "ĵǰ": "j",
  "ķǩḱḳḵ": "k",
  "ĺļľḷḹḻḽ": "l",
  "ŕŗřȑȓṙṛṝṟ": "r",
  "śŝşšșṡṣṥṧṩ": "s",
  "ţťțṫṭṯṱẗ": "t",
  "ŵẁẃẅẇẉẘ": "w",
  "źżžẑẓẕ": "z",
  "ḃḅḇ": "b",
  "ḟ": "f",
  "ḿṁṃ": "m",
  "ṕṗ": "p",
  "ṽṿ": "v",
  "ẋẍ": "x",
};
String _fold(String text) {
  var out = text.toLowerCase().replaceAll('đ', 'd');
  for (final MapEntry(:key, :value) in _accents.entries) {
    out = out.replaceAll(RegExp('[$key]'), value);
  }
  return out
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<MenuItem> searchMenu(List<MenuGroup> groups, String query) {
  final items = groups.expand((g) => g.items).toList();
  final q = _fold(query);
  if (q.isEmpty) return items;
  final words = q.split(' ');
  int score(MenuItem item) {
    final title = _fold(item.label);
    if (title.startsWith(q)) return 3;
    if (title.split(' ').any((w) => w.startsWith(words.first))) return 2;
    return title.contains(words.first) ? 1 : 0;
  }

  final matches = items.indexed.where((pair) {
    final text = _fold('${pair.$2.label} ${pair.$2.hint}');
    return words.every(text.contains);
  }).toList();
  matches.sort((a, b) {
    final order = score(b.$2) - score(a.$2);
    return order != 0 ? order : a.$1 - b.$1;
  });
  return matches.map((pair) => pair.$2).toList();
}

List<MenuItem> quickActions(Roles roles) {
  final items = menuGroups(roles).expand((g) => g.items);
  return [
    for (final key in [
      'tim-can',
      'lai-vay',
      'bang-tin',
      'kham-pha',
      'len-sale',
      'so-sanh',
    ])
      ...items.where((i) => i.key == key),
  ].take(3).toList();
}

String rolesLabel(Roles roles) => hasNoRole(roles)
    ? 'Chưa có vai trò'
    : isFreeSales(roles)
    ? 'Sale tự do'
    : isPartner(roles)
    ? 'Đại lý F2'
    : roles!.map(roleName).join(', ');
