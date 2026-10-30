import 'api/api_client.dart';
import 'core/config/api_config.dart';
import 'feeding.dart';
import 'models.dart';

/// One page of a server list, with the extras the API sends beside it.
class DepartmentPage {
  const DepartmentPage({required this.rows, required this.total, required this.lastPage, this.summary});

  final List<Map<String, dynamic>> rows;
  final int total;
  final int lastPage;

  /// `summary` from `/attendance`: total, present, absent, late, excused,
  /// missing_checkout.
  final Map<String, dynamic>? summary;
}

/// What a department's heads look like (`GET /departments/{id}/heads`).
class DepartmentHeadsInfo {
  const DepartmentHeadsInfo({
    required this.heads,
    required this.canManageMain,
    required this.canManageAssistants,
    required this.assistantPermissions,
  });

  final List<EditableDepartmentHead> heads;
  final bool canManageMain;
  final bool canManageAssistants;

  /// Everything an assistant can be given: name, label, group.
  final List<Map<String, dynamic>> assistantPermissions;
}

class EditableDepartmentHead {
  EditableDepartmentHead({
    required this.staffId,
    required this.fullName,
    this.phone = '',
    this.isMain = false,
    this.notifyScans = false,
    this.notifySms = false,
    Set<String>? permissions,
  }) : permissions = permissions ?? {};

  factory EditableDepartmentHead.fromJson(Map<String, dynamic> json) => EditableDepartmentHead(
        staffId: '${json['staff_id']}',
        fullName: textOf(json['full_name']) ?? 'Staff member',
        phone: textOf(json['phone']) ?? '',
        isMain: json['is_main'] == true || json['is_main'] == 1,
        notifyScans: json['notify_scans'] == true || json['notify_scans'] == 1,
        notifySms: json['notify_sms'] == true || json['notify_sms'] == 1,
        permissions: {for (final p in (json['permissions'] as List? ?? const [])) '$p'},
      );

  final String staffId;
  final String fullName;
  final String phone;
  bool isMain;
  bool notifyScans;
  bool notifySms;
  final Set<String> permissions;

  /// The body the API takes: SMS only goes with scan alerts, and a main head
  /// has every power, so no ticks are sent for one.
  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
        'is_main': isMain,
        'notify_scans': notifyScans,
        'notify_sms': notifyScans && notifySms,
        'permissions': isMain ? const <String>[] : (permissions.toList()..sort()),
      };
}

class DepartmentApi {
  static final _api = ApiClient.instance;

  static Future<DepartmentPage> _list(String path, Map<String, String> query) async {
    final body = await _api.get(path, query: query);
    final map = body is Map ? body : const {};
    final meta = map['meta'] is Map ? map['meta'] as Map : const {};
    final rows = FeedingApi.rows(body is List ? body : map['data']);
    return DepartmentPage(
      rows: rows,
      total: meta['total'] == null ? rows.length : intOf(meta['total']),
      lastPage: meta['last_page'] == null ? 1 : intOf(meta['last_page']),
      summary: map['summary'] is Map ? Map<String, dynamic>.from(map['summary'] as Map) : null,
    );
  }

  /// The server already limits a head's lists to their department.
  static Future<DepartmentPage> students({String search = '', String classId = '', int page = 1, int perPage = 50}) => _list('students', {
        'status': 'active',
        'sort': 'name',
        'per_page': '$perPage',
        'page': '$page',
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (classId.isNotEmpty) 'class_id': classId,
      });

  static Future<DepartmentPage> staff({String search = '', int page = 1, int perPage = 50}) => _list(ApiConfig.staffPath, {
        'status': 'active',
        'per_page': '$perPage',
        'page': '$page',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      });

  static Future<DepartmentPage> classes() => _list(ApiConfig.schoolClassesPath, const {'per_page': '100'});

  static Future<DepartmentPage> attendance({
    required String date,
    required String personType,
    String status = 'all',
    String classId = '',
    int page = 1,
    int perPage = 50,
  }) =>
      _list('attendance', {
        'date': date,
        'person_type': personType,
        'per_page': '$perPage',
        'page': '$page',
        if (status != 'all') 'status': status,
        if (classId.isNotEmpty) 'class_id': classId,
      });

  static Future<DepartmentHeadsInfo> heads(String departmentId) async {
    final body = await _api.get(ApiConfig.departmentHeadsPath(departmentId));
    final map = body is Map ? body : const {};
    return DepartmentHeadsInfo(
      heads: [for (final row in FeedingApi.rows(map['data'])) EditableDepartmentHead.fromJson(row)],
      canManageMain: map['can_manage_main'] == true,
      canManageAssistants: map['can_manage_assistants'] == true,
      assistantPermissions: FeedingApi.rows(map['assistant_permissions']),
    );
  }

  static Future<void> saveHeads(String departmentId, List<EditableDepartmentHead> heads) =>
      _api.put(ApiConfig.departmentHeadsPath(departmentId), {
        'heads': [for (final head in heads) head.toJson()],
      });
}

/// Keeps "My department" to the head's own departments. The server does this
/// already, but it also hands a teacher their own classes outside it, so
/// anything a row says belongs elsewhere is dropped here. A row that says
/// nothing about its department is the server's call.
class DepartmentScope {
  DepartmentScope(this.heads) : ids = {for (final h in heads) h.departmentId};

  final List<DepartmentHeadship> heads;
  final Set<String> ids;

  bool _matches(Map<String, dynamic> row) {
    if (!row.containsKey('department_id') && !row.containsKey('department') && !row.containsKey('departments')) return true;
    final found = <String>{
      if (textOf(row['department_id']) != null) '${row['department_id']}',
      if (row['department'] is Map) '${(row['department'] as Map)['id']}',
      for (final d in FeedingApi.rows(row['departments'])) '${d['id']}',
    };
    return found.any(ids.contains);
  }

  bool hasClass(Map<String, dynamic> row) => _matches(row);

  bool hasStaff(Map<String, dynamic> row) => _matches(row);
}

/// A class's name with its stream ("JHS 2 A").
String departmentClassName(Map<String, dynamic> row) {
  final name = textOf(row['name']) ?? 'Class';
  final stream = textOf(row['stream']);
  return stream == null ? name : '$name $stream';
}

/// A student's class id, whichever way the row carries it.
String departmentStudentClassId(Map<String, dynamic> row) {
  final direct = textOf(row['class_id']) ?? textOf(row['school_class_id']);
  if (direct != null) return direct;
  for (final key in ['current_class', 'school_class', 'class']) {
    final value = row[key];
    if (value is Map && textOf(value['id']) != null) return '${value['id']}';
  }
  final enrollment = row['current_enrollment'];
  if (enrollment is Map) return textOf(enrollment['class_id']) ?? textOf(enrollment['school_class_id']) ?? '';
  return '';
}

/// How an attendance status reads, and its badge colour.
(String, String) departmentAttendanceStatus(dynamic status) => switch ('${status ?? ''}'.toLowerCase()) {
      'present' => ('Present', 'green'),
      'late' => ('Late', 'amber'),
      'absent' => ('Absent', 'red'),
      'authorized_absence' || 'excused' => ('Excused', 'blue'),
      'early_departure' => ('Left early', 'amber'),
      '' => ('No record', 'gray'),
      final other => (other[0].toUpperCase() + other.substring(1).replaceAll('_', ' '), 'gray'),
    };
