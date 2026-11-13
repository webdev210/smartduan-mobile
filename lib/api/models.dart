// Response shapes from legacy-rn/src/api/public.ts and api/types.ts.
// Decimal prices remain strings; only calculator results use numbers.

// M4 account, device and report response shapes from legacy-rn/src/api/.
class AdminUser {
  AdminUser({
    required this.id,
    this.email = '',
    this.fullName,
    this.phone,
    this.status = '',
    List<String> roles = const [],
    this.salesUnitName,
    this.phoneVerifiedAt,
    this.emailVerifiedAt,
    this.f2RequestedAt,
    this.f2RequestVersion = 0,
    this.f2Company,
    this.address,
    this.requestedSalesUnitName,
    this.requestedManagerName,
    this.f2RejectedReason,
    this.lastLoginAt,
  }) : roles = List.unmodifiable(roles);
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String status;
  final List<String> roles;
  final String? salesUnitName;
  final String? phoneVerifiedAt;
  final String? emailVerifiedAt;
  final String? f2RequestedAt;
  final int f2RequestVersion;
  final String? f2Company;
  final String? address;
  final String? requestedSalesUnitName;
  final String? requestedManagerName;
  final String? f2RejectedReason;
  final String? lastLoginAt;
  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: _requiredString(j['id']),
    email: _string(j['email']) ?? '',
    fullName: _string(j['full_name']),
    phone: _string(j['phone']),
    status: _string(j['status']) ?? '',
    roles: jsonStrings(j['roles']),
    salesUnitName: _string(j['sales_unit_name']),
    phoneVerifiedAt: _string(j['phone_verified_at']),
    emailVerifiedAt: _string(j['email_verified_at']),
    f2RequestedAt: _string(j['f2_requested_at']),
    f2RequestVersion: _int(j['f2_request_version']) ?? 0,
    f2Company: _string(j['f2_company']),
    address: _string(j['address']),
    requestedSalesUnitName: _string(j['requested_sales_unit_name']),
    requestedManagerName: _string(j['requested_manager_name']),
    f2RejectedReason: _string(j['f2_rejected_reason']),
    lastLoginAt: _string(j['last_login_at']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'status': status,
    'roles': roles,
    'sales_unit_name': salesUnitName,
    'phone_verified_at': phoneVerifiedAt,
    'email_verified_at': emailVerifiedAt,
    'f2_requested_at': f2RequestedAt,
    'f2_request_version': f2RequestVersion,
    'f2_company': f2Company,
    'address': address,
    'requested_sales_unit_name': requestedSalesUnitName,
    'requested_manager_name': requestedManagerName,
    'f2_rejected_reason': f2RejectedReason,
    'last_login_at': lastLoginAt,
  };
}

class SalesUnitRef {
  SalesUnitRef({required this.id, required this.name});
  final String id;
  final String name;
  factory SalesUnitRef.fromJson(Map<String, dynamic> j) => SalesUnitRef(
    id: _requiredString(j['id']),
    name: _requiredString(j['name']),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class ProfileBranch {
  ProfileBranch({
    required this.id,
    this.code,
    required this.name,
    this.province,
  });
  final String id;
  final String? code;
  final String name;
  final String? province;
  factory ProfileBranch.fromJson(Map<String, dynamic> j) => ProfileBranch(
    id: _requiredString(j['id']),
    code: _string(j['code']),
    name: _requiredString(j['name']),
    province: _string(j['province']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'province': province,
  };
}

class Profile {
  Profile({
    required this.id,
    this.email = '',
    this.fullName,
    this.phone,
    this.address,
    this.status = '',
    this.salesCode,
    List<String> roles = const [],
    this.branch,
    this.salesUnit,
    this.region,
    List<String> interestedProjectIds = const [],
  }) : roles = List.unmodifiable(roles),
       interestedProjectIds = List.unmodifiable(interestedProjectIds);
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? address;
  final String status;
  final String? salesCode;
  final List<String> roles;
  final ProfileBranch? branch;
  final SalesUnitRef? salesUnit;
  final String? region;
  final List<String> interestedProjectIds;
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: _requiredString(j['id']),
    email: _string(j['email']) ?? '',
    fullName: _string(j['full_name']),
    phone: _string(j['phone']),
    address: _string(j['address']),
    status: _string(j['status']) ?? '',
    salesCode: _string(j['sales_code']),
    roles: jsonStrings(j['roles']),
    branch: _nested(j['branch'], ProfileBranch.fromJson),
    salesUnit: _nested(j['sales_unit'], SalesUnitRef.fromJson),
    region: _string(j['region']),
    interestedProjectIds: jsonStrings(j['interested_project_ids']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'address': address,
    'status': status,
    'sales_code': salesCode,
    'roles': roles,
    'branch': branch?.toJson(),
    'sales_unit': salesUnit?.toJson(),
    'region': region,
    'interested_project_ids': interestedProjectIds,
  };
}

class Interests {
  Interests({this.region, List<String> interestedProjectIds = const []})
    : interestedProjectIds = List.unmodifiable(interestedProjectIds);
  final String? region;
  final List<String> interestedProjectIds;
  factory Interests.fromJson(Map<String, dynamic> j) => Interests(
    region: _string(j['region']),
    interestedProjectIds: jsonStrings(j['interested_project_ids']),
  );
  Map<String, dynamic> toJson() => {
    'region': region,
    'interested_project_ids': interestedProjectIds,
  };
}

class Device {
  Device({
    required this.id,
    this.kind,
    this.label,
    this.status = '',
    this.firstSeenAt,
    this.lastSeenAt,
    this.lastIp,
    this.expiresAt,
  });
  final String id;
  final String? kind;
  final String? label;
  final String status;
  final String? firstSeenAt;
  final String? lastSeenAt;
  final String? lastIp;
  final String? expiresAt;
  factory Device.fromJson(Map<String, dynamic> j) => Device(
    id: _requiredString(j['id']),
    kind: _string(j['kind']),
    label: _string(j['label']),
    status: _string(j['status']) ?? '',
    firstSeenAt: _string(j['first_seen_at']),
    lastSeenAt: _string(j['last_seen_at']),
    lastIp: _string(j['last_ip']),
    expiresAt: _string(j['expires_at']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'status': status,
    'first_seen_at': firstSeenAt,
    'last_seen_at': lastSeenAt,
    'last_ip': lastIp,
    'expires_at': expiresAt,
  };
}

class DownloadLog {
  DownloadLog({
    required this.id,
    this.documentId = '',
    this.documentTitle = '',
    this.docType,
    this.projectId = '',
    this.downloadedAt,
    this.expiresAt,
    this.requestedAt = '',
  });
  final String id;
  final String documentId;
  final String documentTitle;
  final String? docType;
  final String projectId;
  final String? downloadedAt;
  final String? expiresAt;
  final String requestedAt;
  factory DownloadLog.fromJson(Map<String, dynamic> j) => DownloadLog(
    id: _requiredString(j['id']),
    documentId: _string(j['document_id']) ?? '',
    documentTitle: _string(j['document_title']) ?? '',
    docType: _string(j['doc_type']),
    projectId: _string(j['project_id']) ?? '',
    downloadedAt: _string(j['downloaded_at']),
    expiresAt: _string(j['expires_at']),
    requestedAt: _string(j['requested_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'document_id': documentId,
    'document_title': documentTitle,
    'doc_type': docType,
    'project_id': projectId,
    'downloaded_at': downloadedAt,
    'expires_at': expiresAt,
    'requested_at': requestedAt,
  };
}

class AnomalyUser {
  AnomalyUser({required this.id, this.fullName, this.email = ''});
  final String id;
  final String? fullName;
  final String email;
  factory AnomalyUser.fromJson(Map<String, dynamic> j) => AnomalyUser(
    id: _requiredString(j['id']),
    fullName: _string(j['full_name']),
    email: _string(j['email']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
  };
}

class DeviceUser {
  DeviceUser({
    required this.id,
    this.fullName,
    this.email = '',
    this.salesUnit,
  });
  final String id;
  final String? fullName;
  final String email;
  final SalesUnitRef? salesUnit;
  factory DeviceUser.fromJson(Map<String, dynamic> j) => DeviceUser(
    id: _requiredString(j['id']),
    fullName: _string(j['full_name']),
    email: _string(j['email']) ?? '',
    salesUnit: _nested(j['sales_unit'], SalesUnitRef.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'sales_unit': salesUnit?.toJson(),
  };
}

class AdminDevice {
  AdminDevice({
    required this.id,
    this.kind,
    this.label,
    this.status = '',
    this.firstSeenAt,
    this.lastSeenAt,
    this.lastIp,
    this.expiresAt,
    this.revokedReason,
    this.user,
    this.self = false,
    this.rejected = false,
  });
  final String id;
  final String? kind;
  final String? label;
  final String status;
  final String? firstSeenAt;
  final String? lastSeenAt;
  final String? lastIp;
  final String? expiresAt;
  final String? revokedReason;
  final DeviceUser? user;
  final bool self;
  final bool rejected;
  factory AdminDevice.fromJson(Map<String, dynamic> j) => AdminDevice(
    id: _requiredString(j['id']),
    kind: _string(j['kind']),
    label: _string(j['label']),
    status: _string(j['status']) ?? '',
    firstSeenAt: _string(j['first_seen_at']),
    lastSeenAt: _string(j['last_seen_at']),
    lastIp: _string(j['last_ip']),
    expiresAt: _string(j['expires_at']),
    revokedReason: _string(j['revoked_reason']),
    user: _nested(j['user'], DeviceUser.fromJson),
    self: _bool(j['self']) ?? false,
    rejected: _bool(j['rejected']) ?? false,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'status': status,
    'first_seen_at': firstSeenAt,
    'last_seen_at': lastSeenAt,
    'last_ip': lastIp,
    'expires_at': expiresAt,
    'revoked_reason': revokedReason,
    'user': user?.toJson(),
    'self': self,
    'rejected': rejected,
  };
}

class SharedDevice {
  SharedDevice({required this.deviceId, List<AnomalyUser> users = const []})
    : users = List.unmodifiable(users);
  final String deviceId;
  final List<AnomalyUser> users;
  factory SharedDevice.fromJson(Map<String, dynamic> j) => SharedDevice(
    deviceId: _requiredString(j['device_id']),
    users: jsonList(j['users'], AnomalyUser.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'users': users.map((v) => v.toJson()).toList(),
  };
}

class IpNetwork {
  IpNetwork({this.user, List<String> networks = const []})
    : networks = List.unmodifiable(networks);
  final AnomalyUser? user;
  final List<String> networks;
  factory IpNetwork.fromJson(Map<String, dynamic> j) => IpNetwork(
    user: _nested(j['user'], AnomalyUser.fromJson),
    networks: jsonStrings(j['networks']),
  );
  Map<String, dynamic> toJson() => {
    'user': user?.toJson(),
    'networks': networks,
  };
}

class DeviceAnomalies {
  DeviceAnomalies({
    List<SharedDevice> sharedDevices = const [],
    List<IpNetwork> ipNetworks = const [],
  }) : sharedDevices = List.unmodifiable(sharedDevices),
       ipNetworks = List.unmodifiable(ipNetworks);
  final List<SharedDevice> sharedDevices;
  final List<IpNetwork> ipNetworks;
  factory DeviceAnomalies.fromJson(Map<String, dynamic> j) => DeviceAnomalies(
    sharedDevices: jsonList(j['shared_devices'], SharedDevice.fromJson),
    ipNetworks: jsonList(j['ip_networks'], IpNetwork.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'shared_devices': sharedDevices.map((v) => v.toJson()).toList(),
    'ip_networks': ipNetworks.map((v) => v.toJson()).toList(),
  };
}

class InventoryReportRow {
  InventoryReportRow({
    required this.projectId,
    this.project = '',
    Map<String, num> counts = const {},
    this.total = 0,
  }) : counts = Map.unmodifiable(counts);
  final String projectId;
  final String project;
  final Map<String, num> counts;
  final int total;
  factory InventoryReportRow.fromJson(Map<String, dynamic> j) =>
      InventoryReportRow(
        projectId: _requiredString(j['project_id']),
        project: _string(j['project']) ?? '',
        counts: _map(j['counts'], (v) => _num(v) ?? 0),
        total: _int(j['total']) ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'project': project,
    'counts': counts,
    'total': total,
  };
}

class AttentionBlock {
  AttentionBlock({this.count = 0, List<Object?> projects = const []})
    : projects = List.unmodifiable(projects);
  final int count;
  final List<Object?> projects;
  factory AttentionBlock.fromJson(Map<String, dynamic> j) => AttentionBlock(
    count: _int(j['count']) ?? 0,
    projects: List<Object?>.unmodifiable(_list(j['projects']).map(_freeze)),
  );
  Map<String, dynamic> toJson() => {'count': count, 'projects': projects};
}

class Attention {
  Attention({this.policiesNew, this.progressChanged});
  final AttentionBlock? policiesNew;
  final AttentionBlock? progressChanged;
  factory Attention.fromJson(Map<String, dynamic> j) => Attention(
    policiesNew: _nested(j['policies_new'], AttentionBlock.fromJson),
    progressChanged: _nested(j['progress_changed'], AttentionBlock.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'policies_new': policiesNew?.toJson(),
    'progress_changed': progressChanged?.toJson(),
  };
}

class RecentChange {
  RecentChange({
    required this.unitId,
    this.unitCode = '',
    this.projectId = '',
    this.project = '',
    this.projectCode,
    this.oldValue,
    this.newValue,
    this.source,
    this.changedAt = '',
    this.changedByName,
  });
  final String unitId;
  final String unitCode;
  final String projectId;
  final String project;
  final String? projectCode;
  final String? oldValue;
  final String? newValue;
  final String? source;
  final String changedAt;
  final String? changedByName;
  factory RecentChange.fromJson(Map<String, dynamic> j) => RecentChange(
    unitId: _requiredString(j['unit_id']),
    unitCode: _string(j['unit_code']) ?? '',
    projectId: _string(j['project_id']) ?? '',
    project: _string(j['project']) ?? '',
    projectCode: _string(j['project_code']),
    oldValue: _string(j['old_value']),
    newValue: _string(j['new_value']),
    source: _string(j['source']),
    changedAt: _string(j['changed_at']) ?? '',
    changedByName: _string(j['changed_by_name']),
  );
  Map<String, dynamic> toJson() => {
    'unit_id': unitId,
    'unit_code': unitCode,
    'project_id': projectId,
    'project': project,
    'project_code': projectCode,
    'old_value': oldValue,
    'new_value': newValue,
    'source': source,
    'changed_at': changedAt,
    'changed_by_name': changedByName,
  };
}

class BookingWeek {
  BookingWeek({this.weekStart = '', this.confirmed = 0, this.declared = 0});
  final String weekStart;
  final int confirmed;
  final int declared;
  factory BookingWeek.fromJson(Map<String, dynamic> j) => BookingWeek(
    weekStart: _string(j['week_start']) ?? '',
    confirmed: _int(j['confirmed']) ?? 0,
    declared: _int(j['declared']) ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'week_start': weekStart,
    'confirmed': confirmed,
    'declared': declared,
  };
}

class BookingsWeekly {
  BookingsWeekly({
    this.from = '',
    this.weeks = 0,
    List<BookingWeek> data = const [],
  }) : data = List.unmodifiable(data);
  final String from;
  final int weeks;
  final List<BookingWeek> data;
  factory BookingsWeekly.fromJson(Map<String, dynamic> j) => BookingsWeekly(
    from: _string(j['from']) ?? '',
    weeks: _int(j['weeks']) ?? 0,
    data: jsonList(j['data'], BookingWeek.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'from': from,
    'weeks': weeks,
    'data': data.map((v) => v.toJson()).toList(),
  };
}

class InventoryUpdateRow {
  InventoryUpdateRow({
    required this.projectId,
    this.project = '',
    this.lastUpdatedAt,
    this.updates = 0,
    this.daysWithUpdate = 0,
    this.days = 0,
    this.compliancePct,
  });
  final String projectId;
  final String project;
  final String? lastUpdatedAt;
  final int updates;
  final int daysWithUpdate;
  final int days;
  final num? compliancePct;
  factory InventoryUpdateRow.fromJson(Map<String, dynamic> j) =>
      InventoryUpdateRow(
        projectId: _requiredString(j['project_id']),
        project: _string(j['project']) ?? '',
        lastUpdatedAt: _string(j['last_updated_at']),
        updates: _int(j['updates']) ?? 0,
        daysWithUpdate: _int(j['days_with_update']) ?? 0,
        days: _int(j['days']) ?? 0,
        compliancePct: _num(j['compliance_pct']),
      );
  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'project': project,
    'last_updated_at': lastUpdatedAt,
    'updates': updates,
    'days_with_update': daysWithUpdate,
    'days': days,
    'compliance_pct': compliancePct,
  };
}

class InventoryUpdates {
  InventoryUpdates({
    this.from = '',
    this.to = '',
    this.days = 0,
    List<InventoryUpdateRow> data = const [],
  }) : data = List.unmodifiable(data);
  final String from;
  final String to;
  final int days;
  final List<InventoryUpdateRow> data;
  factory InventoryUpdates.fromJson(Map<String, dynamic> j) => InventoryUpdates(
    from: _string(j['from']) ?? '',
    to: _string(j['to']) ?? '',
    days: _int(j['days']) ?? 0,
    data: jsonList(j['data'], InventoryUpdateRow.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'days': days,
    'data': data.map((v) => v.toJson()).toList(),
  };
}

class ActiveSalesRole {
  ActiveSalesRole({this.role = '', this.users = 0});
  final String role;
  final int users;
  factory ActiveSalesRole.fromJson(Map<String, dynamic> j) => ActiveSalesRole(
    role: _string(j['role']) ?? '',
    users: _int(j['users']) ?? 0,
  );
  Map<String, dynamic> toJson() => {'role': role, 'users': users};
}

class ActiveSalesBranch {
  ActiveSalesBranch({
    this.branchId,
    this.branchCode,
    this.branch,
    this.users = 0,
  });
  final String? branchId;
  final String? branchCode;
  final String? branch;
  final int users;
  factory ActiveSalesBranch.fromJson(Map<String, dynamic> j) =>
      ActiveSalesBranch(
        branchId: _string(j['branch_id']),
        branchCode: _string(j['branch_code']),
        branch: _string(j['branch']),
        users: _int(j['users']) ?? 0,
      );
  Map<String, dynamic> toJson() => {
    'branch_id': branchId,
    'branch_code': branchCode,
    'branch': branch,
    'users': users,
  };
}

class ActiveSales {
  ActiveSales({
    this.from = '',
    this.to = '',
    List<ActiveSalesRole> byRole = const [],
    List<ActiveSalesBranch> byBranch = const [],
  }) : byRole = List.unmodifiable(byRole),
       byBranch = List.unmodifiable(byBranch);
  final String from;
  final String to;
  final List<ActiveSalesRole> byRole;
  final List<ActiveSalesBranch> byBranch;
  factory ActiveSales.fromJson(Map<String, dynamic> j) => ActiveSales(
    from: _string(j['from']) ?? '',
    to: _string(j['to']) ?? '',
    byRole: jsonList(j['by_role'], ActiveSalesRole.fromJson),
    byBranch: jsonList(j['by_branch'], ActiveSalesBranch.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'by_role': byRole.map((v) => v.toJson()).toList(),
    'by_branch': byBranch.map((v) => v.toJson()).toList(),
  };
}

class SurveyMissing {
  SurveyMissing({this.text = '', this.insertedAt = ''});
  final String text;
  final String insertedAt;
  factory SurveyMissing.fromJson(Map<String, dynamic> j) => SurveyMissing(
    text: _string(j['text']) ?? '',
    insertedAt: _string(j['inserted_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {'text': text, 'inserted_at': insertedAt};
}

class SurveyReport {
  SurveyReport({
    this.responses = 0,
    this.dismissed = 0,
    this.avgEase,
    this.referYes = 0,
    this.referNo = 0,
    Map<String, num> easeHistogram = const {},
    List<SurveyMissing> missing = const [],
  }) : easeHistogram = Map.unmodifiable(easeHistogram),
       missing = List.unmodifiable(missing);
  final int responses;
  final int dismissed;
  final num? avgEase;
  final int referYes;
  final int referNo;
  final Map<String, num> easeHistogram;
  final List<SurveyMissing> missing;
  factory SurveyReport.fromJson(Map<String, dynamic> j) => SurveyReport(
    responses: _int(j['responses']) ?? 0,
    dismissed: _int(j['dismissed']) ?? 0,
    avgEase: _num(j['avg_ease']),
    referYes: _int(j['refer_yes']) ?? 0,
    referNo: _int(j['refer_no']) ?? 0,
    easeHistogram: _map(j['ease_histogram'], (v) => _num(v) ?? 0),
    missing: jsonList(j['missing'], SurveyMissing.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'responses': responses,
    'dismissed': dismissed,
    'avg_ease': avgEase,
    'refer_yes': referYes,
    'refer_no': referNo,
    'ease_histogram': easeHistogram,
    'missing': missing.map((v) => v.toJson()).toList(),
  };
}

class ListingsUser {
  ListingsUser({
    required this.userId,
    this.fullName,
    this.salesCode,
    this.count = 0,
  });
  final String userId;
  final String? fullName;
  final String? salesCode;
  final int count;
  factory ListingsUser.fromJson(Map<String, dynamic> j) => ListingsUser(
    userId: _requiredString(j['user_id']),
    fullName: _string(j['full_name']),
    salesCode: _string(j['sales_code']),
    count: _int(j['count']) ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'full_name': fullName,
    'sales_code': salesCode,
    'count': count,
  };
}

class ListingsProject {
  ListingsProject({
    required this.projectId,
    this.name = '',
    this.code = '',
    this.count = 0,
  });
  final String projectId;
  final String name;
  final String code;
  final int count;
  factory ListingsProject.fromJson(Map<String, dynamic> j) => ListingsProject(
    projectId: _requiredString(j['project_id']),
    name: _string(j['name']) ?? '',
    code: _string(j['code']) ?? '',
    count: _int(j['count']) ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'name': name,
    'code': code,
    'count': count,
  };
}

class ListingsReport {
  ListingsReport({
    this.from = '',
    this.to = '',
    this.total = 0,
    this.usedGlobal = 0,
    List<ListingsUser> byUser = const [],
    List<ListingsProject> byProject = const [],
    Map<String, num> byChannel = const {},
  }) : byUser = List.unmodifiable(byUser),
       byProject = List.unmodifiable(byProject),
       byChannel = Map.unmodifiable(byChannel);
  final String from;
  final String to;
  final int total;
  final int usedGlobal;
  final List<ListingsUser> byUser;
  final List<ListingsProject> byProject;
  final Map<String, num> byChannel;
  factory ListingsReport.fromJson(Map<String, dynamic> j) => ListingsReport(
    from: _string(j['from']) ?? '',
    to: _string(j['to']) ?? '',
    total: _int(j['total']) ?? 0,
    usedGlobal: _int(j['used_global']) ?? 0,
    byUser: jsonList(j['by_user'], ListingsUser.fromJson),
    byProject: jsonList(j['by_project'], ListingsProject.fromJson),
    byChannel: _map(j['by_channel'], (v) => _num(v) ?? 0),
  );
  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'total': total,
    'used_global': usedGlobal,
    'by_user': byUser.map((v) => v.toJson()).toList(),
    'by_project': byProject.map((v) => v.toJson()).toList(),
    'by_channel': byChannel,
  };
}

typedef UnitStatus = String;
typedef PriceField = String;
typedef TopMode = String;
typedef ListingChannel = String;
typedef ActivityKind = String;

/// Common fields of both flat units and stack cells used by board filters.
abstract interface class Filterable {
  String get code;
  String get status;
  String? get unitType;
  String? get fund;
  String? get direction;
  int? get bedrooms;
  String? get axis;
}

/// Value equality for the scalar query maps used as Riverpod family keys.
class ApiParams {
  ApiParams([Map<String, dynamic> values = const {}])
    : values = Map.unmodifiable(values) {
    if (values.values.any(
      (v) => v != null && v is! String && v is! num && v is! bool,
    )) {
      throw ArgumentError('Query parameters must be scalar');
    }
  }
  final Map<String, dynamic> values;
  @override
  bool operator ==(Object other) =>
      other is ApiParams &&
      values.length == other.values.length &&
      values.entries.every(
        (e) =>
            other.values.containsKey(e.key) && other.values[e.key] == e.value,
      );
  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

const searchSorts = [
  ('', 'Mã căn'),
  ('price_list:asc', 'Giá thấp → cao'),
  ('price_list:desc', 'Giá cao → thấp'),
  ('price_per_sqm:asc', 'Đơn giá thấp → cao'),
  ('area_gross:desc', 'Diện tích lớn → nhỏ'),
];
const channels = [
  (value: 'batdongsan', label: 'Batdongsan.com.vn'),
  (value: 'facebook', label: 'Facebook'),
  (value: 'zalo', label: 'Zalo'),
  (value: 'generic', label: 'Chung'),
];

Map<String, dynamic> jsonObject(Object? value) => switch (value) {
  final Map<String, dynamic> map => map,
  _ => throw const FormatException('Expected JSON object'),
};

String _requiredString(Object? value) => switch (value) {
  String value => value,
  _ => throw const FormatException('Expected required string'),
};

String? _string(Object? value) => switch (value) {
  String value => value,
  num value => value.toString(),
  _ => null,
};

num? _num(Object? value) {
  final number = switch (value) {
    num value => value,
    String value => num.tryParse(value),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}

int? _int(Object? value) => _num(value)?.toInt();
bool? _bool(Object? value) => value is bool ? value : null;
Map<String, dynamic>? _object(Object? value) =>
    value is Map<String, dynamic> ? value : null;

T? _nested<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  final object = _object(value);
  return object == null ? null : parse(object);
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

List<T> jsonList<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    List<T>.unmodifiable(
      _list(value).whereType<Map<String, dynamic>>().map(parse),
    );
List<String> jsonStrings(Object? value) =>
    List<String>.unmodifiable(_list(value).whereType<String>());

Map<String, T> _map<T>(Object? value, T Function(Object?) read) =>
    Map<String, T>.unmodifiable(
      (_object(value) ?? const {}).map(
        (key, value) => MapEntry(key, read(value)),
      ),
    );

Object? _freeze(Object? value) => switch (value) {
  Map<String, dynamic> map => Map<String, dynamic>.unmodifiable(
    map.map((k, v) => MapEntry(k, _freeze(v))),
  ),
  List<dynamic> list => List<Object?>.unmodifiable(list.map(_freeze)),
  _ => value,
};

class Paged<T> {
  Paged({
    required List<T> data,
    required this.page,
    required this.perPage,
    required this.total,
  }) : data = List.unmodifiable(data);
  final List<T> data;
  final int page, perPage, total;
  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) parse,
  ) => Paged(
    data: jsonList(j['data'] ?? const [], parse),
    page: _int(j['page']) ?? 0,
    perPage: _int(j['per_page']) ?? 0,
    total: _int(j['total']) ?? 0,
  );
}

class Province {
  Province({required this.name, required List<String> oldNames})
    : oldNames = List.unmodifiable(oldNames);
  final String name;
  final List<String> oldNames;
  factory Province.fromJson(Map<String, dynamic> j) => Province(
    name: _requiredString(j['name']),
    oldNames: jsonStrings(j['old_names'] ?? const []),
  );
}

class PrivacyPolicy {
  const PrivacyPolicy({
    required this.version,
    required this.title,
    required this.url,
    required this.effectiveFrom,
  });
  final String version, title, effectiveFrom;
  final String? url;
  factory PrivacyPolicy.fromJson(Map<String, dynamic> j) => PrivacyPolicy(
    version: _requiredString(j['version']),
    title: _requiredString(j['title']),
    url: _string(j['url']),
    effectiveFrom: _string(j['effective_from']) ?? '',
  );
}

class FullPolicy {
  const FullPolicy({
    required this.version,
    required this.title,
    required this.effectiveFrom,
    required this.body,
  });
  final String version, body;
  final String? title, effectiveFrom;
  factory FullPolicy.fromJson(Map<String, dynamic> j) => FullPolicy(
    version: _requiredString(j['version']),
    title: _string(j['title']),
    effectiveFrom: _string(j['effective_from']),
    body: _string(j['body']) ?? '',
  );
}

class FooterLink {
  const FooterLink({
    required this.label,
    required this.href,
    required this.count,
  });
  final String label, href;
  final int count;
  factory FooterLink.fromJson(Map<String, dynamic> j) => FooterLink(
    label: _string(j['label']) ?? '',
    href: _string(j['href']) ?? '',
    count: _int(j['count']) ?? 0,
  );
}

class ProjectDeveloper {
  const ProjectDeveloper({
    required this.id,
    required this.name,
    this.logoUrl,
    this.slug,
  });
  final String id, name;
  final String? logoUrl, slug;
  factory ProjectDeveloper.fromJson(Map<String, dynamic> j) => ProjectDeveloper(
    id: _requiredString(j['id']),
    name: _requiredString(j['name']),
    logoUrl: _string(j['logo_url']),
    slug: _string(j['slug']),
  );
}

class PublicMedia {
  const PublicMedia({
    required this.id,
    required this.mediaType,
    required this.url,
    this.caption,
    this.displayOrder,
    this.embedUrl,
  });
  final String id, mediaType, url;
  final String? caption, embedUrl;
  final int? displayOrder;
  factory PublicMedia.fromJson(Map<String, dynamic> j) => PublicMedia(
    id: _requiredString(j['id']),
    mediaType: _string(j['media_type']) ?? '',
    url: _string(j['url']) ?? '',
    caption: _string(j['caption']),
    displayOrder: _int(j['display_order']),
    embedUrl: _string(j['embed_url']),
  );
}

class PublicDocument {
  const PublicDocument({this.name, this.url});
  final String? name, url;
  factory PublicDocument.fromJson(Map<String, dynamic> j) =>
      PublicDocument(name: _string(j['name']), url: _string(j['url']));
}

class PublicSubdivision {
  const PublicSubdivision({
    required this.name,
    this.code,
    this.description,
    this.coverUrl,
  });
  final String name;
  final String? code, description, coverUrl;
  factory PublicSubdivision.fromJson(Map<String, dynamic> j) =>
      PublicSubdivision(
        name: _requiredString(j['name']),
        code: _string(j['code']),
        description: _string(j['description']),
        coverUrl: _string(j['cover_url']),
      );
}

class PublicProgress {
  const PublicProgress({
    required this.title,
    this.occurredOn,
    this.body,
    this.imageUrl,
  });
  final String title;
  final String? occurredOn, body, imageUrl;
  factory PublicProgress.fromJson(Map<String, dynamic> j) => PublicProgress(
    title: _requiredString(j['title']),
    occurredOn: _string(j['occurred_on']),
    body: _string(j['body']),
    imageUrl: _string(j['image_url']),
  );
}

class PublicFaq {
  const PublicFaq({
    required this.id,
    required this.question,
    required this.answer,
    required this.position,
  });
  final String id, question, answer;
  final int position;
  factory PublicFaq.fromJson(Map<String, dynamic> j) => PublicFaq(
    id: _requiredString(j['id']),
    question: _string(j['question']) ?? '',
    answer: _string(j['answer']) ?? '',
    position: _int(j['position']) ?? 0,
  );
}

/// Common input shape for public and internal project filtering/cards.
class Browsable {
  const Browsable({
    this.id = '',
    required this.name,
    this.code,
    required this.status,
    this.projectType,
    this.province,
    this.district,
    this.address,
    this.priceFrom,
    this.developerName,
    this.developer,
    this.coverUrl,
    this.inventoryUpdatedAt,
    this.activity7d = 0,
    this.hasTour360 = false,
    this.isPublic,
  });
  final String id, name, status;
  final String? code,
      projectType,
      province,
      district,
      address,
      priceFrom,
      developerName,
      coverUrl,
      inventoryUpdatedAt;
  final ProjectDeveloper? developer;
  final int activity7d;
  final bool hasTour360;
  final bool? isPublic;
}

class PublicProject extends Browsable {
  PublicProject({
    required super.id,
    required super.name,
    required String code,
    required super.status,
    super.projectType,
    super.developer,
    super.province,
    super.district,
    this.ward,
    super.address,
    this.lat,
    this.lng,
    super.priceFrom,
    Map<String, dynamic>? overviewJson,
    List<PublicDocument> documents = const [],
    super.coverUrl,
    super.hasTour360 = false,
    this.tour360Url,
    super.activity7d = 0,
    this.provinceOld,
    this.districtOld,
    this.wardOld,
    List<PublicMedia>? media,
    List<PublicSubdivision>? subdivisions,
    List<PublicProgress>? progress,
    List<PublicFaq>? faqs,
  }) : overviewJson = overviewJson == null
           ? null
           : _freeze(overviewJson) as Map<String, dynamic>,
       documents = List.unmodifiable(documents),
       media = media == null ? null : List.unmodifiable(media),
       subdivisions = subdivisions == null
           ? null
           : List.unmodifiable(subdivisions),
       progress = progress == null ? null : List.unmodifiable(progress),
       faqs = faqs == null ? null : List.unmodifiable(faqs),
       super(code: code);
  @override
  String get code => super.code!;
  final String? ward, lat, lng, tour360Url, provinceOld, districtOld, wardOld;
  final Map<String, dynamic>? overviewJson;
  final List<PublicDocument> documents;
  final List<PublicMedia>? media;
  final List<PublicSubdivision>? subdivisions;
  final List<PublicProgress>? progress;
  final List<PublicFaq>? faqs;
  factory PublicProject.fromJson(Map<String, dynamic> j) => PublicProject(
    id: _requiredString(j['id']),
    name: _requiredString(j['name']),
    code: _requiredString(j['code']),
    status: _string(j['status']) ?? '',
    projectType: _string(j['project_type']),
    developer: _nested(j['developer'], ProjectDeveloper.fromJson),
    province: _string(j['province']),
    district: _string(j['district']),
    ward: _string(j['ward']),
    address: _string(j['address']),
    lat: _string(j['lat']),
    lng: _string(j['lng']),
    priceFrom: _string(j['price_from']),
    overviewJson: _object(j['overview_json']),
    documents: jsonList(j['documents'] ?? const [], PublicDocument.fromJson),
    coverUrl: _string(j['cover_url']),
    hasTour360: _bool(j['has_tour360']) ?? false,
    tour360Url: _string(j['tour360_url']),
    activity7d: _int(j['activity_7d']) ?? 0,
    provinceOld: _string(j['province_old']),
    districtOld: _string(j['district_old']),
    wardOld: _string(j['ward_old']),
    media: j['media'] == null
        ? null
        : jsonList(j['media'], PublicMedia.fromJson),
    subdivisions: j['subdivisions'] == null
        ? null
        : jsonList(j['subdivisions'], PublicSubdivision.fromJson),
    progress: j['progress'] == null
        ? null
        : jsonList(j['progress'], PublicProgress.fromJson),
    faqs: j['faqs'] == null ? null : jsonList(j['faqs'], PublicFaq.fromJson),
  );
}

class PublicDeveloper {
  PublicDeveloper({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    this.website,
    this.description,
    List<String> badges = const [],
  }) : badges = List.unmodifiable(badges);
  final String id, name;
  final String? slug, logoUrl, website, description;
  final List<String> badges;
  factory PublicDeveloper.fromJson(Map<String, dynamic> j) => PublicDeveloper(
    id: _requiredString(j['id']),
    name: _requiredString(j['name']),
    slug: _string(j['slug']),
    logoUrl: _string(j['logo_url']),
    website: _string(j['website']),
    description: _string(j['description']),
    badges: jsonStrings(j['badges'] ?? const []),
  );
}

class PublicContact {
  const PublicContact({this.hotline, this.zaloUrl});
  final String? hotline, zaloUrl;
  factory PublicContact.fromJson(Map<String, dynamic> j) => PublicContact(
    hotline: _string(j['hotline']),
    zaloUrl: _string(j['zalo_url']),
  );
}

class PublicStats {
  const PublicStats({
    required this.developers,
    required this.projectsSelling,
    required this.activity7dTotal,
    required this.contact,
  });
  final int developers, projectsSelling, activity7dTotal;
  final PublicContact contact;
  factory PublicStats.fromJson(Map<String, dynamic> j) => PublicStats(
    developers: _int(j['developers']) ?? 0,
    projectsSelling: _int(j['projects_selling']) ?? 0,
    activity7dTotal: _int(j['activity_7d_total']) ?? 0,
    contact: PublicContact.fromJson(
      (_object(j['contact']) ?? const <String, dynamic>{}),
    ),
  );
}

class PostProject {
  const PostProject({required this.id, required this.name, required this.code});
  final String id, name, code;
  factory PostProject.fromJson(Map<String, dynamic> j) => PostProject(
    id: _requiredString(j['id']),
    name: _requiredString(j['name']),
    code: _requiredString(j['code']),
  );
}

class PublicPost {
  const PublicPost({
    required this.id,
    required this.kind,
    required this.title,
    required this.slug,
    this.excerpt,
    this.coverUrl,
    this.publishedAt,
    this.eventAt,
    this.location,
    this.project,
    this.body,
  });
  final String id, kind, title, slug;
  final String? excerpt, coverUrl, publishedAt, eventAt, location, body;
  final PostProject? project;
  factory PublicPost.fromJson(Map<String, dynamic> j) => PublicPost(
    id: _requiredString(j['id']),
    kind: _string(j['kind']) ?? '',
    title: _requiredString(j['title']),
    slug: _requiredString(j['slug']),
    excerpt: _string(j['excerpt']),
    coverUrl: _string(j['cover_url']),
    publishedAt: _string(j['published_at']),
    eventAt: _string(j['event_at']),
    location: _string(j['location']),
    project: _nested(j['project'], PostProject.fromJson),
    body: _string(j['body']),
  );
}

class LoanTotals {
  const LoanTotals({
    required this.principal,
    required this.interest,
    required this.total,
  });
  final num principal, interest, total;
  factory LoanTotals.fromJson(Map<String, dynamic> j) => LoanTotals(
    principal: _num(j['principal']) ?? 0,
    interest: _num(j['interest']) ?? 0,
    total: _num(j['total']) ?? 0,
  );
}

class LoanPeriod {
  const LoanPeriod({
    required this.period,
    required this.principal,
    required this.interest,
    required this.total,
    required this.remaining,
  });
  final int period;
  final num principal, interest, total, remaining;
  factory LoanPeriod.fromJson(Map<String, dynamic> j) => LoanPeriod(
    period: _int(j['period']) ?? 0,
    principal: _num(j['principal']) ?? 0,
    interest: _num(j['interest']) ?? 0,
    total: _num(j['total']) ?? 0,
    remaining: _num(j['remaining']) ?? 0,
  );
}

/// Shared public and signed-in calculator response.
class LoanResult {
  LoanResult({
    required this.price,
    required this.loanAmount,
    required this.loanRatio,
    required this.termMonths,
    required this.graceMonths,
    required this.supportedRate,
    required this.floatingRate,
    required this.monthlyPayment,
    this.priceBasis,
    this.fund,
    this.policyId,
    this.projectId = "",
    this.termsSource = "default",
    this.overrides = const [],
    this.maxLoanRatio = 0,
    required this.totals,
    required List<LoanPeriod> schedule,
  }) : schedule = List.unmodifiable(schedule);
  final num price,
      loanAmount,
      loanRatio,
      supportedRate,
      floatingRate,
      monthlyPayment;
  final int termMonths, graceMonths;
  final String? priceBasis, fund, policyId;
  final String projectId, termsSource;
  final List<String> overrides;
  final num maxLoanRatio;
  final LoanTotals totals;
  final List<LoanPeriod> schedule;
  factory LoanResult.fromJson(Map<String, dynamic> j) => LoanResult(
    price: _num(j['price']) ?? 0,
    loanAmount: _num(j['loan_amount']) ?? 0,
    loanRatio: _num(j['loan_ratio']) ?? 0,
    termMonths: _int(j['term_months']) ?? 0,
    graceMonths: _int(j['grace_months']) ?? 0,
    supportedRate: _num(j['supported_rate']) ?? 0,
    floatingRate: _num(j['floating_rate']) ?? 0,
    monthlyPayment: _num(j['monthly_payment']) ?? 0,
    priceBasis: _string(j['price_basis']),
    fund: _string(j['fund']),
    policyId: _string(j['policy_id']),
    projectId: _string(j['project_id']) ?? '',
    termsSource: _string(j['terms_source']) ?? 'default',
    overrides: jsonStrings(j['overrides'] ?? const []),
    maxLoanRatio: _num(j['max_loan_ratio']) ?? 0,
    totals: LoanTotals.fromJson(
      (_object(j['totals']) ?? const <String, dynamic>{}),
    ),
    schedule: jsonList(j['schedule'] ?? const [], LoanPeriod.fromJson),
  );
}

// Signed-in response shapes from legacy-rn/src/api/{types,projects,units,sales,content}.ts.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.code,
    this.codePrefix,
    this.developerName,
    this.developerId,
    this.projectType = '',
    this.address,
    this.province,
    this.district,
    this.ward,
    this.lat,
    this.lng,
    this.priceFrom,
    this.description,
    this.status = '',
    this.isPublic = false,
    this.overviewJson,
    this.inventoryUpdatedAt,
    this.coverUrl,
    this.insertedAt = '',
    this.basketEmbedUrl,
  });
  final String id;
  final String name;
  final String code;
  final String? codePrefix;
  final String? developerName;
  final String? developerId;
  final String projectType;
  final String? address;
  final String? province;
  final String? district;
  final String? ward;
  final String? lat;
  final String? lng;
  final String? priceFrom;
  final String? description;
  final String status;
  final bool isPublic;
  final Map<String, dynamic>? overviewJson;
  final String? inventoryUpdatedAt;
  final String? coverUrl;
  final String insertedAt;
  final String? basketEmbedUrl;
  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: _requiredString(j['id']),
    name: _requiredString(j['name']),
    code: _requiredString(j['code']),
    codePrefix: _string(j['code_prefix']),
    developerName: _string(j['developer_name']),
    developerId: _string(j['developer_id']),
    projectType: _string(j['project_type']) ?? '',
    address: _string(j['address']),
    province: _string(j['province']),
    district: _string(j['district']),
    ward: _string(j['ward']),
    lat: _string(j['lat']),
    lng: _string(j['lng']),
    priceFrom: _string(j['price_from']),
    description: _string(j['description']),
    status: _string(j['status']) ?? '',
    isPublic: _bool(j['is_public']) ?? false,
    overviewJson: _nested(
      j['overview_json'],
      (v) => _freeze(v) as Map<String, dynamic>,
    ),
    inventoryUpdatedAt: _string(j['inventory_updated_at']),
    coverUrl: _string(j['cover_url']),
    insertedAt: _string(j['inserted_at']) ?? '',
    basketEmbedUrl: _string(j['basket_embed_url']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'code_prefix': codePrefix,
    'developer_name': developerName,
    'developer_id': developerId,
    'project_type': projectType,
    'address': address,
    'province': province,
    'district': district,
    'ward': ward,
    'lat': lat,
    'lng': lng,
    'price_from': priceFrom,
    'description': description,
    'status': status,
    'is_public': isPublic,
    'overview_json': overviewJson,
    'inventory_updated_at': inventoryUpdatedAt,
    'cover_url': coverUrl,
    'inserted_at': insertedAt,
    'basket_embed_url': basketEmbedUrl,
  };
}

class BlockRef {
  const BlockRef({required this.id, this.name = '', this.code});
  final String id;
  final String name;
  final String? code;
  factory BlockRef.fromJson(Map<String, dynamic> j) => BlockRef(
    id: _requiredString(j['id']),
    name: _string(j['name']) ?? '',
    code: _string(j['code']),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'code': code};
}

class Floor {
  const Floor({
    this.number = 0,
    this.name,
    this.totalUnits = 0,
    this.availableUnits = 0,
  });
  final int number;
  final String? name;
  final int totalUnits;
  final int availableUnits;
  factory Floor.fromJson(Map<String, dynamic> j) => Floor(
    number: _int(j['number']) ?? 0,
    name: _string(j['name']),
    totalUnits: _int(j['total_units']) ?? 0,
    availableUnits: _int(j['available_units']) ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'total_units': totalUnits,
    'available_units': availableUnits,
  };
}

class Block {
  const Block({
    required this.id,
    this.projectId = '',
    required this.name,
    this.code,
    this.position,
    this.floors = const [],
  });
  final String id;
  final String projectId;
  final String name;
  final String? code;
  final int? position;
  final List<Floor> floors;
  factory Block.fromJson(Map<String, dynamic> j) => Block(
    id: _requiredString(j['id']),
    projectId: _string(j['project_id']) ?? '',
    name: _requiredString(j['name']),
    code: _string(j['code']),
    position: _int(j['position']),
    floors: jsonList(j['floors'] ?? const [], Floor.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'name': name,
    'code': code,
    'position': position,
    'floors': floors.map((v) => v.toJson()).toList(),
  };
}

class ExtraPrice {
  const ExtraPrice({this.field = '', this.label = '', this.value = ''});
  final String field;
  final String label;
  final String value;
  factory ExtraPrice.fromJson(Map<String, dynamic> j) => ExtraPrice(
    field: _string(j['field']) ?? '',
    label: _string(j['label']) ?? '',
    value: _string(j['value']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'field': field,
    'label': label,
    'value': value,
  };
}

class Unit implements Filterable {
  const Unit({
    required this.id,
    this.projectId = '',
    this.blockId,
    this.floorId,
    required this.code,
    this.publicCode,
    this.title = '',
    this.floor,
    this.unitType,
    this.areaGross,
    this.areaNet,
    this.areaBucket,
    this.bedrooms,
    this.direction,
    this.view,
    this.basePrice,
    this.priceList,
    this.priceLoan,
    this.priceProgress,
    this.priceEarly,
    this.extraPrices = const [],
    this.priceMin,
    this.priceMinLabel,
    this.pricePerSqm,
    this.priceNote,
    this.priceBucket,
    this.axis,
    this.rowCode,
    this.fund,
    this.areaLand,
    this.handoverStandard,
    this.keySellingPoint,
    this.verifiedAt,
    this.updatedAt,
    this.status = '',
    this.version = 0,
    this.reservedByUserId,
    this.reservedUntil,
    this.reservedNote,
    this.topPick = false,
    this.heldBy,
    this.priceSheetNote,
    this.priceSheetUrl,
    this.attributes,
  });
  final String id;
  final String projectId;
  final String? blockId;
  final String? floorId;
  @override
  final String code;
  final String? publicCode;
  final String title;
  final int? floor;
  @override
  final String? unitType;
  final String? areaGross;
  final String? areaNet;
  final String? areaBucket;
  @override
  final int? bedrooms;
  @override
  final String? direction;
  final String? view;
  final String? basePrice;
  final String? priceList;
  final String? priceLoan;
  final String? priceProgress;
  final String? priceEarly;
  final List<ExtraPrice> extraPrices;
  final String? priceMin;
  final String? priceMinLabel;
  final String? pricePerSqm;
  final String? priceNote;
  final String? priceBucket;
  @override
  final String? axis;
  final String? rowCode;
  @override
  final String? fund;
  final String? areaLand;
  final String? handoverStandard;
  final String? keySellingPoint;
  final String? verifiedAt;
  final String? updatedAt;
  @override
  final String status;
  final int version;
  final String? reservedByUserId;
  final String? reservedUntil;
  final String? reservedNote;
  final bool topPick;
  final String? heldBy;
  final String? priceSheetNote;
  final String? priceSheetUrl;
  final Map<String, dynamic>? attributes;
  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
    id: _requiredString(j['id']),
    projectId: _string(j['project_id']) ?? '',
    blockId: _string(j['block_id']),
    floorId: _string(j['floor_id']),
    code: _requiredString(j['code']),
    publicCode: _string(j['public_code']),
    title: _string(j['title']) ?? '',
    floor: _int(j['floor']),
    unitType: _string(j['unit_type']),
    areaGross: _string(j['area_gross']),
    areaNet: _string(j['area_net']),
    areaBucket: _string(j['area_bucket']),
    bedrooms: _int(j['bedrooms']),
    direction: _string(j['direction']),
    view: _string(j['view']),
    basePrice: _string(j['base_price']),
    priceList: _string(j['price_list']),
    priceLoan: _string(j['price_loan']),
    priceProgress: _string(j['price_progress']),
    priceEarly: _string(j['price_early']),
    extraPrices: jsonList(j['extra_prices'] ?? const [], ExtraPrice.fromJson),
    priceMin: _string(j['price_min']),
    priceMinLabel: _string(j['price_min_label']),
    pricePerSqm: _string(j['price_per_sqm']),
    priceNote: _string(j['price_note']),
    priceBucket: _string(j['price_bucket']),
    axis: _string(j['axis']),
    rowCode: _string(j['row_code']),
    fund: _string(j['fund']),
    areaLand: _string(j['area_land']),
    handoverStandard: _string(j['handover_standard']),
    keySellingPoint: _string(j['key_selling_point']),
    verifiedAt: _string(j['verified_at']),
    updatedAt: _string(j['updated_at']),
    status: _string(j['status']) ?? '',
    version: _int(j['version']) ?? 0,
    reservedByUserId: _string(j['reserved_by_user_id']),
    reservedUntil: _string(j['reserved_until']),
    reservedNote: _string(j['reserved_note']),
    topPick: _bool(j['top_pick']) ?? false,
    heldBy: _string(j['held_by']),
    priceSheetNote: _string(j['price_sheet_note']),
    priceSheetUrl: _string(j['price_sheet_url']),
    attributes: _nested(
      j['attributes'],
      (v) => _freeze(v) as Map<String, dynamic>,
    ),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'block_id': blockId,
    'floor_id': floorId,
    'code': code,
    'public_code': publicCode,
    'title': title,
    'floor': floor,
    'unit_type': unitType,
    'area_gross': areaGross,
    'area_net': areaNet,
    'area_bucket': areaBucket,
    'bedrooms': bedrooms,
    'direction': direction,
    'view': view,
    'base_price': basePrice,
    'price_list': priceList,
    'price_loan': priceLoan,
    'price_progress': priceProgress,
    'price_early': priceEarly,
    'extra_prices': extraPrices.map((v) => v.toJson()).toList(),
    'price_min': priceMin,
    'price_min_label': priceMinLabel,
    'price_per_sqm': pricePerSqm,
    'price_note': priceNote,
    'price_bucket': priceBucket,
    'axis': axis,
    'row_code': rowCode,
    'fund': fund,
    'area_land': areaLand,
    'handover_standard': handoverStandard,
    'key_selling_point': keySellingPoint,
    'verified_at': verifiedAt,
    'updated_at': updatedAt,
    'status': status,
    'version': version,
    'reserved_by_user_id': reservedByUserId,
    'reserved_until': reservedUntil,
    'reserved_note': reservedNote,
    'top_pick': topPick,
    'held_by': heldBy,
    'price_sheet_note': priceSheetNote,
    'price_sheet_url': priceSheetUrl,
    'attributes': attributes,
  };
}

class RelatedUnit {
  const RelatedUnit({
    required this.code,
    this.unitType,
    this.priceMin,
    this.priceMinLabel,
  });
  final String code;
  final String? unitType;
  final String? priceMin;
  final String? priceMinLabel;
  factory RelatedUnit.fromJson(Map<String, dynamic> j) => RelatedUnit(
    code: _requiredString(j['code']),
    unitType: _string(j['unit_type']),
    priceMin: _string(j['price_min']),
    priceMinLabel: _string(j['price_min_label']),
  );
  Map<String, dynamic> toJson() => {
    'code': code,
    'unit_type': unitType,
    'price_min': priceMin,
    'price_min_label': priceMinLabel,
  };
}

class AxisMeta {
  const AxisMeta({
    this.unitType,
    this.areaGross,
    this.areaNet,
    this.direction,
    this.bedrooms,
  });
  final String? unitType;
  final String? areaGross;
  final String? areaNet;
  final String? direction;
  final int? bedrooms;
  factory AxisMeta.fromJson(Map<String, dynamic> j) => AxisMeta(
    unitType: _string(j['unit_type']),
    areaGross: _string(j['area_gross']),
    areaNet: _string(j['area_net']),
    direction: _string(j['direction']),
    bedrooms: _int(j['bedrooms']),
  );
  Map<String, dynamic> toJson() => {
    'unit_type': unitType,
    'area_gross': areaGross,
    'area_net': areaNet,
    'direction': direction,
    'bedrooms': bedrooms,
  };
}

class StackCell implements Filterable {
  const StackCell({
    this.axis = '',
    required this.id,
    required this.code,
    this.status = '',
    this.fund,
    this.priceMin,
    this.priceMinLabel,
    this.pricePerSqm,
    this.areaNet,
    this.version = 0,
    this.direction,
    this.bedrooms,
    this.unitType,
  });
  @override
  final String axis;
  final String id;
  @override
  final String code;
  @override
  final String status;
  @override
  final String? fund;
  final String? priceMin;
  final String? priceMinLabel;
  final String? pricePerSqm;
  final String? areaNet;
  final int version;
  @override
  final String? direction;
  @override
  final int? bedrooms;
  @override
  final String? unitType;
  factory StackCell.fromJson(Map<String, dynamic> j) => StackCell(
    axis: _string(j['axis']) ?? '',
    id: _requiredString(j['id']),
    code: _requiredString(j['code']),
    status: _string(j['status']) ?? '',
    fund: _string(j['fund']),
    priceMin: _string(j['price_min']),
    priceMinLabel: _string(j['price_min_label']),
    pricePerSqm: _string(j['price_per_sqm']),
    areaNet: _string(j['area_net']),
    version: _int(j['version']) ?? 0,
    direction: _string(j['direction']),
    bedrooms: _int(j['bedrooms']),
    unitType: _string(j['unit_type']),
  );
  Map<String, dynamic> toJson() => {
    'axis': axis,
    'id': id,
    'code': code,
    'status': status,
    'fund': fund,
    'price_min': priceMin,
    'price_min_label': priceMinLabel,
    'price_per_sqm': pricePerSqm,
    'area_net': areaNet,
    'version': version,
    'direction': direction,
    'bedrooms': bedrooms,
    'unit_type': unitType,
  };
}

class StackFloor {
  const StackFloor({this.floor = 0, this.name, this.cells = const []});
  final int floor;
  final String? name;
  final List<StackCell> cells;
  factory StackFloor.fromJson(Map<String, dynamic> j) => StackFloor(
    floor: _int(j['floor']) ?? 0,
    name: _string(j['name']),
    cells: jsonList(j['cells'] ?? const [], StackCell.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'floor': floor,
    'name': name,
    'cells': cells.map((v) => v.toJson()).toList(),
  };
}

class StackPlan {
  const StackPlan({
    required this.block,
    this.layout = '',
    this.axes = const [],
    this.axisMeta = const {},
    this.floors = const [],
  });
  final BlockRef block;
  final String layout;
  final List<String> axes;
  final Map<String, AxisMeta?> axisMeta;
  final List<StackFloor> floors;
  factory StackPlan.fromJson(Map<String, dynamic> j) => StackPlan(
    block: BlockRef.fromJson(
      (_object(j['block']) ?? const <String, dynamic>{}),
    ),
    layout: _string(j['layout']) ?? '',
    axes: jsonStrings(j['axes']),
    axisMeta: Map<String, AxisMeta?>.unmodifiable(
      (_object(j['axis_meta']) ?? const <String, dynamic>{}).map(
        (k, v) => MapEntry(k, _nested(v, AxisMeta.fromJson)),
      ),
    ),
    floors: jsonList(j['floors'] ?? const [], StackFloor.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'block': block.toJson(),
    'layout': layout,
    'axes': axes,
    'axis_meta': axisMeta.map((k, v) => MapEntry(k, v?.toJson())),
    'floors': floors.map((v) => v.toJson()).toList(),
  };
}

class Policy {
  const Policy({
    this.fund,
    required this.id,
    this.projectId = '',
    required this.title,
    this.summary,
    this.fileUrl,
    this.effectiveFrom = '',
    this.effectiveTo,
    this.visibleToPartner = false,
    this.loanTermsJson,
    this.insertedAt = '',
  });
  final String? fund;
  final String id;
  final String projectId;
  final String title;
  final String? summary;
  final String? fileUrl;
  final String effectiveFrom;
  final String? effectiveTo;
  final bool visibleToPartner;
  final Map<String, dynamic>? loanTermsJson;
  final String insertedAt;
  factory Policy.fromJson(Map<String, dynamic> j) => Policy(
    fund: _string(j['fund']),
    id: _requiredString(j['id']),
    projectId: _string(j['project_id']) ?? '',
    title: _requiredString(j['title']),
    summary: _string(j['summary']),
    fileUrl: _string(j['file_url']),
    effectiveFrom: _string(j['effective_from']) ?? '',
    effectiveTo: _string(j['effective_to']),
    visibleToPartner: _bool(j['visible_to_partner']) ?? false,
    loanTermsJson: _nested(
      j['loan_terms_json'],
      (v) => _freeze(v) as Map<String, dynamic>,
    ),
    insertedAt: _string(j['inserted_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'fund': fund,
    'id': id,
    'project_id': projectId,
    'title': title,
    'summary': summary,
    'file_url': fileUrl,
    'effective_from': effectiveFrom,
    'effective_to': effectiveTo,
    'visible_to_partner': visibleToPartner,
    'loan_terms_json': loanTermsJson,
    'inserted_at': insertedAt,
  };
}

class Doc {
  const Doc({
    required this.id,
    this.projectId = '',
    required this.title,
    this.docType,
    this.unitType,
    this.watermarkRequired = false,
    this.visibleToPartner = false,
    this.version = 0,
    this.insertedAt = '',
  });
  final String id;
  final String projectId;
  final String title;
  final String? docType;
  final String? unitType;
  final bool watermarkRequired;
  final bool visibleToPartner;
  final int version;
  final String insertedAt;
  factory Doc.fromJson(Map<String, dynamic> j) => Doc(
    id: _requiredString(j['id']),
    projectId: _string(j['project_id']) ?? '',
    title: _requiredString(j['title']),
    docType: _string(j['doc_type']),
    unitType: _string(j['unit_type']),
    watermarkRequired: _bool(j['watermark_required']) ?? false,
    visibleToPartner: _bool(j['visible_to_partner']) ?? false,
    version: _int(j['version']) ?? 0,
    insertedAt: _string(j['inserted_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'title': title,
    'doc_type': docType,
    'unit_type': unitType,
    'watermark_required': watermarkRequired,
    'visible_to_partner': visibleToPartner,
    'version': version,
    'inserted_at': insertedAt,
  };
}

class MediaItem {
  const MediaItem({
    required this.id,
    this.url = '',
    this.caption,
    this.mediaType = '',
    this.embedUrl,
  });
  final String id;
  final String url;
  final String? caption;
  final String mediaType;
  final String? embedUrl;
  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
    id: _requiredString(j['id']),
    url: _string(j['url']) ?? '',
    caption: _string(j['caption']),
    mediaType: _string(j['media_type']) ?? '',
    embedUrl: _string(j['embed_url']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'caption': caption,
    'media_type': mediaType,
    'embed_url': embedUrl,
  };
}

class ProgressItem {
  const ProgressItem({
    required this.id,
    this.projectId = '',
    this.occurredOn,
    this.title,
    this.body,
    this.photoUrl,
  });
  final String id;
  final String projectId;
  final String? occurredOn;
  final String? title;
  final String? body;
  final String? photoUrl;
  factory ProgressItem.fromJson(Map<String, dynamic> j) => ProgressItem(
    id: _requiredString(j['id']),
    projectId: _string(j['project_id']) ?? '',
    occurredOn: _string(j['occurred_on']),
    title: _string(j['title']),
    body: _string(j['body']),
    photoUrl: _string(j['photo_url']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'occurred_on': occurredOn,
    'title': title,
    'body': body,
    'photo_url': photoUrl,
  };
}

class Faq {
  const Faq({required this.id, this.question = '', this.answer = ''});
  final String id;
  final String question;
  final String answer;
  factory Faq.fromJson(Map<String, dynamic> j) => Faq(
    id: _requiredString(j['id']),
    question: _string(j['question']) ?? '',
    answer: _string(j['answer']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
  };
}

class Contact {
  const Contact({required this.fullName, this.roleLabel = '', this.phone = ''});
  final String fullName;
  final String roleLabel;
  final String phone;
  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    fullName: _requiredString(j['full_name']),
    roleLabel: _string(j['role_label']) ?? '',
    phone: _string(j['phone']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'role_label': roleLabel,
    'phone': phone,
  };
}

class Booking {
  const Booking({
    required this.id,
    this.projectId = '',
    this.unitId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.status = '',
    this.reason,
    this.insertedAt = '',
    this.updatedAt = '',
    this.unitPublicCode,
    this.googleFormUrl,
  });
  final String id;
  final String projectId;
  final String unitId;
  final String customerName;
  final String customerPhone;
  final String status;
  final String? reason;
  final String insertedAt;
  final String updatedAt;
  final String? unitPublicCode;
  final String? googleFormUrl;
  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: _requiredString(j['id']),
    projectId: _string(j['project_id']) ?? '',
    unitId: _string(j['unit_id']) ?? '',
    customerName: _string(j['customer_name']) ?? '',
    customerPhone: _string(j['customer_phone']) ?? '',
    status: _string(j['status']) ?? '',
    reason: _string(j['reason']),
    insertedAt: _string(j['inserted_at']) ?? '',
    updatedAt: _string(j['updated_at']) ?? '',
    unitPublicCode: _string(j['unit_public_code']),
    googleFormUrl: _string(j['google_form_url']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'unit_id': unitId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'status': status,
    'reason': reason,
    'inserted_at': insertedAt,
    'updated_at': updatedAt,
    'unit_public_code': unitPublicCode,
    'google_form_url': googleFormUrl,
  };
}

class SaleRef {
  const SaleRef({required this.id, this.fullName, this.salesCode});
  final String id;
  final String? fullName;
  final String? salesCode;
  factory SaleRef.fromJson(Map<String, dynamic> j) => SaleRef(
    id: _requiredString(j['id']),
    fullName: _string(j['full_name']),
    salesCode: _string(j['sales_code']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'sales_code': salesCode,
  };
}

class AdminBooking {
  const AdminBooking({
    required this.id,
    this.status = '',
    this.reason,
    this.customerName = '',
    this.customerPhone = '',
    this.insertedAt = '',
    this.updatedAt = '',
    this.project,
    this.unit,
    this.sale,
  });
  final String id;
  final String status;
  final String? reason;
  final String customerName;
  final String customerPhone;
  final String insertedAt;
  final String updatedAt;
  final Project? project;
  final UnitRef? unit;
  final SaleRef? sale;
  factory AdminBooking.fromJson(Map<String, dynamic> j) => AdminBooking(
    id: _requiredString(j['id']),
    status: _string(j['status']) ?? '',
    reason: _string(j['reason']),
    customerName: _string(j['customer_name']) ?? '',
    customerPhone: _string(j['customer_phone']) ?? '',
    insertedAt: _string(j['inserted_at']) ?? '',
    updatedAt: _string(j['updated_at']) ?? '',
    project: _nested(j['project'], Project.fromJson),
    unit: _nested(j['unit'], UnitRef.fromJson),
    sale: _nested(j['sale'], SaleRef.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'reason': reason,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'inserted_at': insertedAt,
    'updated_at': updatedAt,
    'project': project?.toJson(),
    'unit': unit?.toJson(),
    'sale': sale?.toJson(),
  };
}

class HistoryRow {
  const HistoryRow({
    required this.id,
    this.unitId = '',
    this.field = '',
    this.oldValue,
    this.newValue,
    this.source = '',
    this.changedAt = '',
  });
  final String id;
  final String unitId;
  final String field;
  final String? oldValue;
  final String? newValue;
  final String source;
  final String changedAt;
  factory HistoryRow.fromJson(Map<String, dynamic> j) => HistoryRow(
    id: _requiredString(j['id']),
    unitId: _string(j['unit_id']) ?? '',
    field: _string(j['field']) ?? '',
    oldValue: _string(j['old_value']),
    newValue: _string(j['new_value']),
    source: _string(j['source']) ?? '',
    changedAt: _string(j['changed_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'unit_id': unitId,
    'field': field,
    'old_value': oldValue,
    'new_value': newValue,
    'source': source,
    'changed_at': changedAt,
  };
}

class SearchProject {
  const SearchProject({
    required this.id,
    this.name = '',
    this.code = '',
    this.province,
  });
  final String id;
  final String name;
  final String code;
  final String? province;
  factory SearchProject.fromJson(Map<String, dynamic> j) => SearchProject(
    id: _requiredString(j['id']),
    name: _string(j['name']) ?? '',
    code: _string(j['code']) ?? '',
    province: _string(j['province']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'province': province,
  };
}

class SearchRow {
  const SearchRow({
    required this.id,
    required this.code,
    this.publicCode,
    this.title = '',
    this.floor,
    this.axis,
    this.unitType,
    this.areaGross,
    this.areaNet,
    this.bedrooms,
    this.direction,
    this.view,
    this.fund,
    this.priceList,
    this.priceMin,
    this.priceMinLabel,
    this.priceBucket,
    this.areaBucket,
    this.status = '',
    this.project,
    this.block,
    this.heldBy,
  });
  final String id;
  final String code;
  final String? publicCode;
  final String title;
  final int? floor;
  final String? axis;
  final String? unitType;
  final String? areaGross;
  final String? areaNet;
  final int? bedrooms;
  final String? direction;
  final String? view;
  final String? fund;
  final String? priceList;
  final String? priceMin;
  final String? priceMinLabel;
  final String? priceBucket;
  final String? areaBucket;
  final String status;
  final SearchProject? project;
  final BlockRef? block;
  final String? heldBy;
  factory SearchRow.fromJson(Map<String, dynamic> j) => SearchRow(
    id: _requiredString(j['id']),
    code: _requiredString(j['code']),
    publicCode: _string(j['public_code']),
    title: _string(j['title']) ?? '',
    floor: _int(j['floor']),
    axis: _string(j['axis']),
    unitType: _string(j['unit_type']),
    areaGross: _string(j['area_gross']),
    areaNet: _string(j['area_net']),
    bedrooms: _int(j['bedrooms']),
    direction: _string(j['direction']),
    view: _string(j['view']),
    fund: _string(j['fund']),
    priceList: _string(j['price_list']),
    priceMin: _string(j['price_min']),
    priceMinLabel: _string(j['price_min_label']),
    priceBucket: _string(j['price_bucket']),
    areaBucket: _string(j['area_bucket']),
    status: _string(j['status']) ?? '',
    project: _nested(j['project'], SearchProject.fromJson),
    block: _nested(j['block'], BlockRef.fromJson),
    heldBy: _string(j['held_by']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'public_code': publicCode,
    'title': title,
    'floor': floor,
    'axis': axis,
    'unit_type': unitType,
    'area_gross': areaGross,
    'area_net': areaNet,
    'bedrooms': bedrooms,
    'direction': direction,
    'view': view,
    'fund': fund,
    'price_list': priceList,
    'price_min': priceMin,
    'price_min_label': priceMinLabel,
    'price_bucket': priceBucket,
    'area_bucket': areaBucket,
    'status': status,
    'project': project?.toJson(),
    'block': block?.toJson(),
    'held_by': heldBy,
  };
}

class SavedFilter {
  const SavedFilter({
    required this.id,
    required this.name,
    this.params = const {},
    this.insertedAt = '',
  });
  final String id;
  final String name;
  final Map<String, String> params;
  final String insertedAt;
  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
    id: _requiredString(j['id']),
    name: _requiredString(j['name']),
    params: _map(j['params'], (v) => _string(v) ?? ''),
    insertedAt: _string(j['inserted_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'params': params,
    'inserted_at': insertedAt,
  };
}

class Enums {
  const Enums({
    this.unitType = const [],
    this.direction = const [],
    this.directionLabels = const {},
    this.areaBuckets = const [],
    this.priceBuckets = const [],
    this.handoverStandards = const [],
    this.funds = const [],
    this.fundLabels = const {},
    this.fundColors = const {},
    this.fundVisibleToFree = const {},
    this.fundIds = const {},
  });
  final List<String> unitType;
  final List<String> direction;
  final Map<String, String> directionLabels;
  final List<String> areaBuckets;
  final List<String> priceBuckets;
  final List<String> handoverStandards;
  final List<String> funds;
  final Map<String, String> fundLabels;
  final Map<String, String?> fundColors;
  final Map<String, bool> fundVisibleToFree;
  final Map<String, String> fundIds;
  factory Enums.fromJson(Map<String, dynamic> j) => Enums(
    unitType: jsonStrings(j['unit_type']),
    direction: jsonStrings(j['direction']),
    directionLabels: _map(j['direction_labels'], (v) => _string(v) ?? ''),
    areaBuckets: jsonStrings(j['area_buckets']),
    priceBuckets: jsonStrings(j['price_buckets']),
    handoverStandards: jsonStrings(j['handover_standards']),
    funds: jsonStrings(j['funds']),
    fundLabels: _map(j['fund_labels'], (v) => _string(v) ?? ''),
    fundColors: _map(j['fund_colors'], _string),
    fundVisibleToFree: _map(
      j['fund_visible_to_free'],
      (v) => _bool(v) ?? false,
    ),
    fundIds: _map(j['fund_ids'], (v) => _string(v) ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'unit_type': unitType,
    'direction': direction,
    'direction_labels': directionLabels,
    'area_buckets': areaBuckets,
    'price_buckets': priceBuckets,
    'handover_standards': handoverStandards,
    'funds': funds,
    'fund_labels': fundLabels,
    'fund_colors': fundColors,
    'fund_visible_to_free': fundVisibleToFree,
    'fund_ids': fundIds,
  };
}

class Plan {
  const Plan({
    required this.id,
    this.projectId = '',
    this.blockId,
    this.rowCode,
    this.floorNumbers = const [],
    this.mediaItemId = '',
    this.title,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.version = 0,
    this.isActive = false,
    this.imageUrl,
  });
  final String id;
  final String projectId;
  final String? blockId;
  final String? rowCode;
  final List<int> floorNumbers;
  final String mediaItemId;
  final String? title;
  final int imageWidth;
  final int imageHeight;
  final int version;
  final bool isActive;
  final String? imageUrl;
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    id: _requiredString(j['id']),
    projectId: _string(j['project_id']) ?? '',
    blockId: _string(j['block_id']),
    rowCode: _string(j['row_code']),
    floorNumbers: List<int>.unmodifiable(
      _list(j['floor_numbers']).map(_int).whereType<int>(),
    ),
    mediaItemId: _string(j['media_item_id']) ?? '',
    title: _string(j['title']),
    imageWidth: _int(j['image_width']) ?? 0,
    imageHeight: _int(j['image_height']) ?? 0,
    version: _int(j['version']) ?? 0,
    isActive: _bool(j['is_active']) ?? false,
    imageUrl: _string(j['image_url']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'block_id': blockId,
    'row_code': rowCode,
    'floor_numbers': floorNumbers,
    'media_item_id': mediaItemId,
    'title': title,
    'image_width': imageWidth,
    'image_height': imageHeight,
    'version': version,
    'is_active': isActive,
    'image_url': imageUrl,
  };
}

class Point {
  const Point({this.x = 0, this.y = 0});
  final num x;
  final num y;
  factory Point.fromJson(Map<String, dynamic> j) =>
      Point(x: _num(j['x']) ?? 0, y: _num(j['y']) ?? 0);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class Pin {
  const Pin({
    required this.id,
    this.unitId,
    this.blockId,
    this.rowCode,
    this.targetPlanId,
    this.points = const [],
    this.label,
    this.code,
    this.status,
    this.fund,
    this.priceMin,
    this.priceMinLabel,
    this.areaNet,
    this.bedrooms,
    this.direction,
  });
  final String id;
  final String? unitId;
  final String? blockId;
  final String? rowCode;
  final String? targetPlanId;
  final List<Point> points;
  final String? label;
  final String? code;
  final String? status;
  final String? fund;
  final String? priceMin;
  final String? priceMinLabel;
  final String? areaNet;
  final int? bedrooms;
  final String? direction;
  factory Pin.fromJson(Map<String, dynamic> j) => Pin(
    id: _requiredString(j['id']),
    unitId: _string(j['unit_id']),
    blockId: _string(j['block_id']),
    rowCode: _string(j['row_code']),
    targetPlanId: _string(j['target_plan_id']),
    points: jsonList(j['points'] ?? const [], Point.fromJson),
    label: _string(j['label']),
    code: _string(j['code']),
    status: _string(j['status']),
    fund: _string(j['fund']),
    priceMin: _string(j['price_min']),
    priceMinLabel: _string(j['price_min_label']),
    areaNet: _string(j['area_net']),
    bedrooms: _int(j['bedrooms']),
    direction: _string(j['direction']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'unit_id': unitId,
    'block_id': blockId,
    'row_code': rowCode,
    'target_plan_id': targetPlanId,
    'points': points.map((v) => v.toJson()).toList(),
    'label': label,
    'code': code,
    'status': status,
    'fund': fund,
    'price_min': priceMin,
    'price_min_label': priceMinLabel,
    'area_net': areaNet,
    'bedrooms': bedrooms,
    'direction': direction,
  };
}

class ListingImage {
  const ListingImage({this.mediaId = '', this.url = '', this.expiresIn = 0});
  final String mediaId;
  final String url;
  final int expiresIn;
  factory ListingImage.fromJson(Map<String, dynamic> j) => ListingImage(
    mediaId: _string(j['media_id']) ?? '',
    url: _string(j['url']) ?? '',
    expiresIn: _int(j['expires_in']) ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'media_id': mediaId,
    'url': url,
    'expires_in': expiresIn,
  };
}

class ListingTemplate {
  const ListingTemplate({required this.id, this.scope = ''});
  final String id;
  final String scope;
  factory ListingTemplate.fromJson(Map<String, dynamic> j) => ListingTemplate(
    id: _requiredString(j['id']),
    scope: _string(j['scope']) ?? '',
  );
  Map<String, dynamic> toJson() => {'id': id, 'scope': scope};
}

class Listing {
  const Listing({
    required this.title,
    this.body = '',
    this.publicCode,
    this.channel = '',
    this.images = const [],
    this.skippedExternal = 0,
    this.failedImages = 0,
    this.template,
    this.usedGlobal = false,
  });
  final String title;
  final String body;
  final String? publicCode;
  final String channel;
  final List<ListingImage> images;
  final int skippedExternal;
  final int failedImages;
  final ListingTemplate? template;
  final bool usedGlobal;
  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
    title: _requiredString(j['title']),
    body: _string(j['body']) ?? '',
    publicCode: _string(j['public_code']),
    channel: _string(j['channel']) ?? '',
    images: jsonList(j['images'] ?? const [], ListingImage.fromJson),
    skippedExternal: _int(j['skipped_external']) ?? 0,
    failedImages: _int(j['failed_images']) ?? 0,
    template: _nested(j['template'], ListingTemplate.fromJson),
    usedGlobal: _bool(j['used_global']) ?? false,
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'public_code': publicCode,
    'channel': channel,
    'images': images.map((v) => v.toJson()).toList(),
    'skipped_external': skippedExternal,
    'failed_images': failedImages,
    'template': template?.toJson(),
    'used_global': usedGlobal,
  };
}

class Notification {
  const Notification({
    required this.id,
    this.kind = '',
    required this.title,
    this.href,
    this.readAt,
    this.insertedAt = '',
  });
  final String id;
  final String kind;
  final String title;
  final String? href;
  final String? readAt;
  final String insertedAt;
  factory Notification.fromJson(Map<String, dynamic> j) => Notification(
    id: _requiredString(j['id']),
    kind: _string(j['kind']) ?? '',
    title: _requiredString(j['title']),
    href: _string(j['href']),
    readAt: _string(j['read_at']),
    insertedAt: _string(j['inserted_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'href': href,
    'read_at': readAt,
    'inserted_at': insertedAt,
  };
}

class Notifications {
  const Notifications({this.data = const [], this.unread = 0});
  final List<Notification> data;
  final int unread;
  factory Notifications.fromJson(Map<String, dynamic> j) => Notifications(
    data: jsonList(j['data'] ?? const [], Notification.fromJson),
    unread: _int(j['unread']) ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'data': data.map((v) => v.toJson()).toList(),
    'unread': unread,
  };
}

class AnnouncementSummary {
  const AnnouncementSummary({
    required this.id,
    required this.title,
    this.publishedAt = '',
    this.updatedAt = '',
  });
  final String id;
  final String title;
  final String publishedAt;
  final String updatedAt;
  factory AnnouncementSummary.fromJson(Map<String, dynamic> j) =>
      AnnouncementSummary(
        id: _requiredString(j['id']),
        title: _requiredString(j['title']),
        publishedAt: _string(j['published_at']) ?? '',
        updatedAt: _string(j['updated_at']) ?? '',
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'published_at': publishedAt,
    'updated_at': updatedAt,
  };
}

class ManagerOption {
  const ManagerOption({
    required this.id,
    required this.fullName,
    this.salesUnit,
  });
  final String id;
  final String fullName;
  final BlockRef? salesUnit;
  factory ManagerOption.fromJson(Map<String, dynamic> j) => ManagerOption(
    id: _requiredString(j['id']),
    fullName: _requiredString(j['full_name']),
    salesUnit: _nested(j['sales_unit'], BlockRef.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'sales_unit': salesUnit?.toJson(),
  };
}

class TeamMember {
  const TeamMember({
    required this.id,
    this.fullName,
    this.salesCode,
    this.roles = const [],
    this.status = '',
    this.lastLoginAt,
  });
  final String id;
  final String? fullName;
  final String? salesCode;
  final List<String> roles;
  final String status;
  final String? lastLoginAt;
  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    id: _requiredString(j['id']),
    fullName: _string(j['full_name']),
    salesCode: _string(j['sales_code']),
    roles: jsonStrings(j['roles']),
    status: _string(j['status']) ?? '',
    lastLoginAt: _string(j['last_login_at']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'sales_code': salesCode,
    'roles': roles,
    'status': status,
    'last_login_at': lastLoginAt,
  };
}

class Team {
  const Team({this.data = const [], this.salesUnit});
  final List<TeamMember> data;
  final BlockRef? salesUnit;
  factory Team.fromJson(Map<String, dynamic> j) => Team(
    data: jsonList(j['data'] ?? const [], TeamMember.fromJson),
    salesUnit: _nested(j['sales_unit'], BlockRef.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'data': data.map((v) => v.toJson()).toList(),
    'sales_unit': salesUnit?.toJson(),
  };
}

class ProcessPage {
  const ProcessPage({
    required this.id,
    required this.slug,
    required this.title,
    this.summary,
    this.status,
    this.projectId,
    this.projectName,
    this.updatedAt = '',
    this.coverUrl,
  });
  final String id;
  final String slug;
  final String title;
  final String? summary;
  final String? status;
  final String? projectId;
  final String? projectName;
  final String updatedAt;
  final String? coverUrl;
  factory ProcessPage.fromJson(Map<String, dynamic> j) => ProcessPage(
    id: _requiredString(j['id']),
    slug: _requiredString(j['slug']),
    title: _requiredString(j['title']),
    summary: _string(j['summary']),
    status: _string(j['status']),
    projectId: _string(j['project_id']),
    projectName: _string(j['project_name']),
    updatedAt: _string(j['updated_at']) ?? '',
    coverUrl: _string(j['cover_url']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'summary': summary,
    'status': status,
    'project_id': projectId,
    'project_name': projectName,
    'updated_at': updatedAt,
    'cover_url': coverUrl,
  };
}

class TopUnit {
  const TopUnit({
    required this.id,
    required this.code,
    this.publicCode,
    this.blockId,
    this.blockName,
    this.floor,
    this.axis,
    this.priceMin,
    this.priceMinLabel,
    this.area,
    this.areaField,
    this.score,
    this.why = const [],
  });
  final String id;
  final String code;
  final String? publicCode;
  final String? blockId;
  final String? blockName;
  final int? floor;
  final String? axis;
  final String? priceMin;
  final String? priceMinLabel;
  final String? area;
  final String? areaField;
  final num? score;
  final List<String> why;
  factory TopUnit.fromJson(Map<String, dynamic> j) => TopUnit(
    id: _requiredString(j['id']),
    code: _requiredString(j['code']),
    publicCode: _string(j['public_code']),
    blockId: _string(j['block_id']),
    blockName: _string(j['block_name']),
    floor: _int(j['floor']),
    axis: _string(j['axis']),
    priceMin: _string(j['price_min']),
    priceMinLabel: _string(j['price_min_label']),
    area: _string(j['area']),
    areaField: _string(j['area_field']),
    score: _num(j['score']),
    why: switch (j['why']) {
      String reason => [reason],
      final value => jsonStrings(value),
    },
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'public_code': publicCode,
    'block_id': blockId,
    'block_name': blockName,
    'floor': floor,
    'axis': axis,
    'price_min': priceMin,
    'price_min_label': priceMinLabel,
    'area': area,
    'area_field': areaField,
    'score': score,
    'why': why,
  };
}

class TopUnitGroup {
  const TopUnitGroup({
    this.unitType,
    this.bedrooms,
    this.available = 0,
    this.units = const [],
  });
  final String? unitType;
  final int? bedrooms;
  final int available;
  final List<TopUnit> units;
  factory TopUnitGroup.fromJson(Map<String, dynamic> j) => TopUnitGroup(
    unitType: _string(j['unit_type']),
    bedrooms: _int(j['bedrooms']),
    available: _int(j['available']) ?? 0,
    units: jsonList(j['units'] ?? const [], TopUnit.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'unit_type': unitType,
    'bedrooms': bedrooms,
    'available': available,
    'units': units.map((v) => v.toJson()).toList(),
  };
}

class TopUnits {
  const TopUnits({
    this.mode = '',
    this.n = 0,
    this.hasBedrooms = false,
    this.unitTypes = const [],
    this.bedrooms = const [],
    this.groups = const [],
  });
  final String mode;
  final int n;
  final bool hasBedrooms;
  final List<String> unitTypes;
  final List<int> bedrooms;
  final List<TopUnitGroup> groups;
  factory TopUnits.fromJson(Map<String, dynamic> j) => TopUnits(
    mode: _string(j['mode']) ?? '',
    n: _int(j['n']) ?? 0,
    hasBedrooms: _bool(j['has_bedrooms']) ?? false,
    unitTypes: jsonStrings(j['unit_types']),
    bedrooms: List<int>.unmodifiable(
      _list(j['bedrooms']).map(_int).whereType<int>(),
    ),
    groups: jsonList(j['groups'] ?? const [], TopUnitGroup.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'mode': mode,
    'n': n,
    'has_bedrooms': hasBedrooms,
    'unit_types': unitTypes,
    'bedrooms': bedrooms,
    'groups': groups.map((v) => v.toJson()).toList(),
  };
}

class Subdivision {
  const Subdivision({
    required this.blockId,
    required this.name,
    this.code,
    this.description,
    this.coverUrl,
    this.totalUnits = 0,
    this.priceMin,
    this.priceMax,
  });
  final String blockId;
  final String name;
  final String? code;
  final String? description;
  final String? coverUrl;
  final int totalUnits;
  final String? priceMin;
  final String? priceMax;
  factory Subdivision.fromJson(Map<String, dynamic> j) => Subdivision(
    blockId: _requiredString(j['block_id']),
    name: _requiredString(j['name']),
    code: _string(j['code']),
    description: _string(j['description']),
    coverUrl: _string(j['cover_url']),
    totalUnits: _int(j['total_units']) ?? 0,
    priceMin: _string(j['price_min']),
    priceMax: _string(j['price_max']),
  );
  Map<String, dynamic> toJson() => {
    'block_id': blockId,
    'name': name,
    'code': code,
    'description': description,
    'cover_url': coverUrl,
    'total_units': totalUnits,
    'price_min': priceMin,
    'price_max': priceMax,
  };
}

class ShareLink {
  const ShareLink({
    required this.id,
    this.token = '',
    this.urlPath = '',
    this.projectId = '',
    this.blockId,
    this.expiresAt,
    this.revokedAt,
    this.viewCount = 0,
    this.leadCount = 0,
    this.insertedAt = '',
    this.createdByName,
  });
  final String id;
  final String token;
  final String urlPath;
  final String projectId;
  final String? blockId;
  final String? expiresAt;
  final String? revokedAt;
  final int viewCount;
  final int leadCount;
  final String insertedAt;
  final String? createdByName;
  factory ShareLink.fromJson(Map<String, dynamic> j) => ShareLink(
    id: _requiredString(j['id']),
    token: _string(j['token']) ?? '',
    urlPath: _string(j['url_path']) ?? '',
    projectId: _string(j['project_id']) ?? '',
    blockId: _string(j['block_id']),
    expiresAt: _string(j['expires_at']),
    revokedAt: _string(j['revoked_at']),
    viewCount: _int(j['view_count']) ?? 0,
    leadCount: _int(j['lead_count']) ?? 0,
    insertedAt: _string(j['inserted_at']) ?? '',
    createdByName: _string(j['created_by_name']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'url_path': urlPath,
    'project_id': projectId,
    'block_id': blockId,
    'expires_at': expiresAt,
    'revoked_at': revokedAt,
    'view_count': viewCount,
    'lead_count': leadCount,
    'inserted_at': insertedAt,
    'created_by_name': createdByName,
  };
}

class PresentationBoard {
  const PresentationBoard({this.project, this.blocks = const [], this.blockId});
  final Project? project;
  final List<BlockRef> blocks;
  final String? blockId;
  factory PresentationBoard.fromJson(Map<String, dynamic> j) =>
      PresentationBoard(
        project: _nested(j['project'], Project.fromJson),
        blocks: jsonList(j['blocks'] ?? const [], BlockRef.fromJson),
        blockId: _string(j['block_id']),
      );
  Map<String, dynamic> toJson() => {
    'project': project?.toJson(),
    'blocks': blocks.map((v) => v.toJson()).toList(),
    'block_id': blockId,
  };
}

class UnitImage {
  const UnitImage({required this.id, this.url = ''});
  final String id;
  final String url;
  factory UnitImage.fromJson(Map<String, dynamic> j) =>
      UnitImage(id: _requiredString(j['id']), url: _string(j['url']) ?? '');
  Map<String, dynamic> toJson() => {'id': id, 'url': url};
}

class PriceSheet {
  const PriceSheet({required this.id, this.url = '', this.insertedAt = ''});
  final String id;
  final String url;
  final String insertedAt;
  factory PriceSheet.fromJson(Map<String, dynamic> j) => PriceSheet(
    id: _requiredString(j['id']),
    url: _string(j['url']) ?? '',
    insertedAt: _string(j['inserted_at']) ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'inserted_at': insertedAt,
  };
}

class UnitImages {
  const UnitImages({this.data = const [], this.priceSheet});
  final List<UnitImage> data;
  final PriceSheet? priceSheet;
  factory UnitImages.fromJson(Map<String, dynamic> j) => UnitImages(
    data: jsonList(j['data'] ?? const [], UnitImage.fromJson),
    priceSheet: _nested(j['price_sheet'], PriceSheet.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'data': data.map((v) => v.toJson()).toList(),
    'price_sheet': priceSheet?.toJson(),
  };
}

class ComparePolicy {
  const ComparePolicy({required this.name, this.url});
  final String name;
  final String? url;
  factory ComparePolicy.fromJson(Map<String, dynamic> j) =>
      ComparePolicy(name: _requiredString(j['name']), url: _string(j['url']));
  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}

class CompareSet {
  const CompareSet({this.units = const [], this.removed = const []});
  final List<CompareUnit> units;
  final List<String> removed;
  factory CompareSet.fromJson(Map<String, dynamic> j) => CompareSet(
    units: jsonList(j['units'] ?? const [], CompareUnit.fromJson),
    removed: jsonStrings(j['removed']),
  );
  Map<String, dynamic> toJson() => {
    'units': units.map((v) => v.toJson()).toList(),
    'removed': removed,
  };
}

class Branch {
  const Branch({
    required this.id,
    required this.code,
    required this.name,
    this.entity,
    this.province,
  });
  final String id;
  final String code;
  final String name;
  final String? entity;
  final String? province;
  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
    id: _requiredString(j['id']),
    code: _requiredString(j['code']),
    name: _requiredString(j['name']),
    entity: _string(j['entity']),
    province: _string(j['province']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'entity': entity,
    'province': province,
  };
}

/// Daily activity row used by the pure sales-tools aggregation test in RN.
class ProjectViewRow {
  const ProjectViewRow({
    required this.projectId,
    required this.project,
    this.day = '',
    this.viewerType = '',
    this.views = 0,
    this.uniqueVisitors = 0,
    this.ctaClicks = 0,
    this.leads = 0,
    this.conversion,
  });
  final String projectId, project, day, viewerType;
  final int views, uniqueVisitors, ctaClicks, leads;
  final num? conversion;
  factory ProjectViewRow.fromJson(Map<String, dynamic> j) => ProjectViewRow(
    projectId: _requiredString(j['project_id']),
    project: _string(j['project']) ?? '',
    day: _string(j['day']) ?? '',
    viewerType: _string(j['viewer_type']) ?? '',
    views: _int(j['views']) ?? 0,
    uniqueVisitors: _int(j['unique_visitors']) ?? 0,
    ctaClicks: _int(j['cta_clicks']) ?? 0,
    leads: _int(j['leads']) ?? 0,
    conversion: _num(j['conversion']),
  );
  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'project': project,
    'day': day,
    'viewer_type': viewerType,
    'views': views,
    'unique_visitors': uniqueVisitors,
    'cta_clicks': ctaClicks,
    'leads': leads,
    'conversion': conversion,
  };
}

class UnitRef {
  const UnitRef({required this.id, required this.code});
  final String id, code;
  factory UnitRef.fromJson(Map<String, dynamic> j) =>
      UnitRef(id: _requiredString(j['id']), code: _requiredString(j['code']));
  Map<String, dynamic> toJson() => {'id': id, 'code': code};
}

class RolesResult {
  const RolesResult({this.roles = const []});
  final List<String> roles;
  factory RolesResult.fromJson(Map<String, dynamic> j) =>
      RolesResult(roles: jsonStrings(j['roles'] ?? const []));
  Map<String, dynamic> toJson() => {'roles': roles};
}

class F2Request {
  const F2Request({this.f2RequestedAt = ''});
  final String f2RequestedAt;
  factory F2Request.fromJson(Map<String, dynamic> j) =>
      F2Request(f2RequestedAt: _string(j['f2_requested_at']) ?? '');
  Map<String, dynamic> toJson() => {'f2_requested_at': f2RequestedAt};
}

class NotificationsRead {
  const NotificationsRead({this.read = 0});
  final int read;
  factory NotificationsRead.fromJson(Map<String, dynamic> j) =>
      NotificationsRead(read: _int(j['read']) ?? 0);
  Map<String, dynamic> toJson() => {'read': read};
}

class ConsultResult {
  const ConsultResult({this.ok = false});
  final bool ok;
  factory ConsultResult.fromJson(Map<String, dynamic> j) =>
      ConsultResult(ok: _bool(j['ok']) ?? false);
  Map<String, dynamic> toJson() => {'ok': ok};
}

class ProcessAccessResult {
  const ProcessAccessResult({this.status = ''});
  final String status;
  factory ProcessAccessResult.fromJson(Map<String, dynamic> j) =>
      ProcessAccessResult(status: _string(j['status']) ?? '');
  Map<String, dynamic> toJson() => {'status': status};
}

class UnitDetail extends Unit {
  UnitDetail._(Unit value, this.block, this.related)
    : super(
        id: value.id,
        projectId: value.projectId,
        blockId: value.blockId,
        floorId: value.floorId,
        code: value.code,
        publicCode: value.publicCode,
        title: value.title,
        floor: value.floor,
        unitType: value.unitType,
        areaGross: value.areaGross,
        areaNet: value.areaNet,
        areaBucket: value.areaBucket,
        bedrooms: value.bedrooms,
        direction: value.direction,
        view: value.view,
        basePrice: value.basePrice,
        priceList: value.priceList,
        priceLoan: value.priceLoan,
        priceProgress: value.priceProgress,
        priceEarly: value.priceEarly,
        extraPrices: value.extraPrices,
        priceMin: value.priceMin,
        priceMinLabel: value.priceMinLabel,
        pricePerSqm: value.pricePerSqm,
        priceNote: value.priceNote,
        priceBucket: value.priceBucket,
        axis: value.axis,
        rowCode: value.rowCode,
        fund: value.fund,
        areaLand: value.areaLand,
        handoverStandard: value.handoverStandard,
        keySellingPoint: value.keySellingPoint,
        verifiedAt: value.verifiedAt,
        updatedAt: value.updatedAt,
        status: value.status,
        version: value.version,
        reservedByUserId: value.reservedByUserId,
        reservedUntil: value.reservedUntil,
        reservedNote: value.reservedNote,
        topPick: value.topPick,
        heldBy: value.heldBy,
        priceSheetNote: value.priceSheetNote,
        priceSheetUrl: value.priceSheetUrl,
        attributes: value.attributes,
      );
  final BlockRef? block;
  final List<RelatedUnit> related;
  factory UnitDetail.fromJson(Map<String, dynamic> j) => UnitDetail._(
    Unit.fromJson(j),
    _nested(j['block'], BlockRef.fromJson),
    jsonList(j['related'] ?? const [], RelatedUnit.fromJson),
  );
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'block': block?.toJson(),
    'related': related.map((v) => v.toJson()).toList(),
  };
}

class CompareUnit extends SearchRow {
  CompareUnit._(SearchRow value, this.pricePerSqm, this.areaLand, this.policy)
    : super(
        id: value.id,
        code: value.code,
        publicCode: value.publicCode,
        title: value.title,
        floor: value.floor,
        axis: value.axis,
        unitType: value.unitType,
        areaGross: value.areaGross,
        areaNet: value.areaNet,
        bedrooms: value.bedrooms,
        direction: value.direction,
        view: value.view,
        fund: value.fund,
        priceList: value.priceList,
        priceMin: value.priceMin,
        priceMinLabel: value.priceMinLabel,
        priceBucket: value.priceBucket,
        areaBucket: value.areaBucket,
        status: value.status,
        project: value.project,
        block: value.block,
        heldBy: value.heldBy,
      );
  final String? pricePerSqm;
  final String? areaLand;
  final ComparePolicy? policy;
  factory CompareUnit.fromJson(Map<String, dynamic> j) => CompareUnit._(
    SearchRow.fromJson(j),
    _string(j['price_per_sqm']),
    _string(j['area_land']),
    _nested(j['policy'], ComparePolicy.fromJson),
  );
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'price_per_sqm': pricePerSqm,
    'area_land': areaLand,
    'policy': policy?.toJson(),
  };
}

class AnnouncementDetail extends AnnouncementSummary {
  AnnouncementDetail._(AnnouncementSummary value, this.body)
    : super(
        id: value.id,
        title: value.title,
        publishedAt: value.publishedAt,
        updatedAt: value.updatedAt,
      );
  final String body;
  factory AnnouncementDetail.fromJson(Map<String, dynamic> j) =>
      AnnouncementDetail._(
        AnnouncementSummary.fromJson(j),
        _string(j['body']) ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'body': body};
}

/// A join snapshot may omit identity and price fields. Presence is retained.
class PartialUnit {
  PartialUnit.fromJson(Map<String, dynamic> json)
    : _json = _freeze(json) as Map<String, dynamic>;
  final Map<String, dynamic> _json;
  bool contains(String key) => _json.containsKey(key);
  Map<String, dynamic> toJson() => Map.of(_json);
  String? get id => _string(_json['id']);
  String? get projectId => _string(_json['project_id']);
  String? get blockId => _string(_json['block_id']);
  String? get floorId => _string(_json['floor_id']);
  String? get code => _string(_json['code']);
  String? get publicCode => _string(_json['public_code']);
  String? get title => _string(_json['title']);
  int? get floor => _int(_json['floor']);
  String? get unitType => _string(_json['unit_type']);
  String? get areaGross => _string(_json['area_gross']);
  String? get areaNet => _string(_json['area_net']);
  String? get areaBucket => _string(_json['area_bucket']);
  int? get bedrooms => _int(_json['bedrooms']);
  String? get direction => _string(_json['direction']);
  String? get view => _string(_json['view']);
  String? get basePrice => _string(_json['base_price']);
  String? get priceList => _string(_json['price_list']);
  String? get priceLoan => _string(_json['price_loan']);
  String? get priceProgress => _string(_json['price_progress']);
  String? get priceEarly => _string(_json['price_early']);
  String? get priceMin => _string(_json['price_min']);
  String? get priceMinLabel => _string(_json['price_min_label']);
  String? get pricePerSqm => _string(_json['price_per_sqm']);
  String? get priceNote => _string(_json['price_note']);
  String? get priceBucket => _string(_json['price_bucket']);
  String? get axis => _string(_json['axis']);
  String? get rowCode => _string(_json['row_code']);
  String? get fund => _string(_json['fund']);
  String? get areaLand => _string(_json['area_land']);
  String? get handoverStandard => _string(_json['handover_standard']);
  String? get keySellingPoint => _string(_json['key_selling_point']);
  String? get verifiedAt => _string(_json['verified_at']);
  String? get updatedAt => _string(_json['updated_at']);
  String? get status => _string(_json['status']);
  int? get version => _int(_json['version']);
  String? get reservedByUserId => _string(_json['reserved_by_user_id']);
  String? get reservedUntil => _string(_json['reserved_until']);
  String? get reservedNote => _string(_json['reserved_note']);
  bool? get topPick => _bool(_json['top_pick']);
  String? get heldBy => _string(_json['held_by']);
  String? get priceSheetNote => _string(_json['price_sheet_note']);
  String? get priceSheetUrl => _string(_json['price_sheet_url']);
  List<ExtraPrice>? get extraPrices => _json['extra_prices'] == null
      ? null
      : jsonList(_json['extra_prices'], ExtraPrice.fromJson);
  Map<String, dynamic>? get attributes => _object(_json['attributes']);
}

/// The allowlisted status event fields; fund may be omitted or explicitly null.
class UnitPatch extends PartialUnit {
  UnitPatch({
    required String unitId,
    required String status,
    required int version,
    String? reservedUntil,
    String? fund,
    bool hasFund = false,
    String? reservedByUserId,
  }) : this.fromJson({
         'unit_id': unitId,
         'status': status,
         'version': version,
         'reserved_until': reservedUntil,
         if (hasFund || fund != null) 'fund': fund,
         'reserved_by_user_id': ?reservedByUserId,
       });
  UnitPatch.fromJson(super.json) : super.fromJson() {
    if (_json['unit_id'] is! String ||
        _json['status'] is! String ||
        _json['version'] is! int) {
      throw const FormatException('Invalid unit patch');
    }
  }
  String get unitId => _requiredString(_json['unit_id']);
  @override
  String get status => _requiredString(_json['status']);
  @override
  int get version => _int(_json['version'])!;
  bool get hasFund => contains('fund');
}
