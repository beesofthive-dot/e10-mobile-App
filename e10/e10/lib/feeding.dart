import 'dart:typed_data';

import 'api/api_client.dart';
import 'api/api_exception.dart';
import 'api/api_session.dart';
import 'core/config/api_config.dart';
import 'models.dart';
import 'plan_access.dart';

/// The cashier counter (school fees + feeding) and the parent feeding
/// history, on the same live endpoints the website uses. Nothing here is
/// school-specific: rates, feeding days and what a user may do all come
/// from the server for whichever school is signed in.
class FeedingApi {
  static final _api = ApiClient.instance;

  static Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic>
      ? v
      : v is Map
          ? Map<String, dynamic>.from(v)
          : <String, dynamic>{};

  static Map<String, dynamic> _data(dynamic body) => _map(_map(body)['data']);

  static List<Map<String, dynamic>> rows(dynamic v) => [
        if (v is List)
          for (final item in v)
            if (item is Map) Map<String, dynamic>.from(item),
      ];

  // Counter (school fees + feeding takings).
  static Future<Map<String, dynamic>> cashierMyDay() async => _data(await _api.get('cashier/my-day'));

  static Future<List<Map<String, dynamic>>> cashierStudents(String search) async =>
      rows(_map(await _api.get('cashier/students', query: {'search': search}))['data']);

  static Future<Map<String, dynamic>> cashierStudent(String id) async => _data(await _api.get('cashier/students/$id'));

  static Future<Map<String, dynamic>> recordFeePayment(Map<String, dynamic> body) async =>
      _data(await _api.post('cashier/fee-payments', body));

  // Feeding.
  static Future<Map<String, dynamic>> settings() async => _data(await _api.get('feeding/settings'));

  static Future<Map<String, dynamic>> today({String classId = '', String search = ''}) async => _data(await _api.get(
        'feeding/today',
        query: {
          if (search.trim().length >= 2) 'search': search.trim() else if (classId.isNotEmpty) 'class_id': classId,
        },
      ));

  static Future<Map<String, dynamic>> quote(Map<String, dynamic> body) async => _data(await _api.post('feeding/quote', body));

  static Future<Map<String, dynamic>> recordFeedingPayment(Map<String, dynamic> body) async =>
      _data(await _api.post('feeding/payments', body));

  static Future<Map<String, dynamic>> feedingMyDay() async => _data(await _api.get('feeding/my-day'));

  // Bursar / admin.
  static Future<Map<String, dynamic>> feedingPayments(Map<String, String> query) async =>
      _map(await _api.get('feeding/payments', query: query));

  static Future<void> voidFeedingPayment(String id, String reason) => _api.post('feeding/payments/$id/void', {'reason': reason});

  static Future<List<Map<String, dynamic>>> cashups(String date) async =>
      rows(_data(await _api.get('feeding/cashups', query: {'date': date}))['rows']);

  static Future<void> saveCashup(Map<String, dynamic> body) => _api.post('feeding/cashups', body);

  static Future<Map<String, dynamic>> report() async => _data(await _api.get('feeding/report'));

  static Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async =>
      _data(await _api.put('feeding/settings', body));

  static Future<Map<String, dynamic>> saveRates(List<Map<String, dynamic>> rates) async =>
      _data(await _api.put('feeding/rates', {'rates': rates}));

  // Expenses.
  static Future<List<Map<String, dynamic>>> expenseCategories() async =>
      rows(_map(await _api.get('expense-categories'))['data']);

  static Future<void> createExpenseCategory(String name) => _api.post('expense-categories', {'name': name});

  static Future<void> updateExpenseCategory(String id, Map<String, dynamic> body) => _api.put('expense-categories/$id', body);

  static Future<Map<String, dynamic>> expenses(Map<String, String> query) async => _map(await _api.get('expenses', query: query));

  /// Create (no [id]) or update an expense; the receipt is optional.
  static Future<void> saveExpense({
    String? id,
    required Map<String, String> fields,
    ({List<int> bytes, String filename})? receipt,
  }) =>
      _api.postMultipartFiles(
        id == null ? 'expenses' : 'expenses/$id',
        fileField: 'receipt',
        files: [if (receipt != null) receipt],
        fields: fields,
      );

  static Future<void> voidExpense(String id, String reason) => _api.post('expenses/$id/void', {'reason': reason});

  static Future<Uint8List> expenseReceipt(String id) =>
      _api.getBytes(ApiConfig.url('expenses/$id/receipt'), accept: 'application/pdf,image/*');

  static Future<List<Map<String, dynamic>>> academicTerms() async =>
      rows(_map(await _api.get('academic-terms', query: {'per_page': '100'}))['data']);

  // Parent.
  static Future<Map<String, dynamic>> studentFeedingHistory(String studentId, String month) async =>
      _data(await _api.get('students/$studentId/feeding/history', query: {'month': month}));

  // Parent online feeding payment — the school-fees MoMo flow, for feeding:
  // start a pay-intent, then poll `/payment-intents/{id}` until it settles.
  // The live server doesn't have this route yet (see
  // docs/feeding_online_payment_api.md); [parentPayAvailable] asks once and
  // the Pay button stays hidden until the server answers.
  static bool? _payAvailable;

  static String feedingPayIntentPath(String studentId) => 'students/$studentId/feeding/pay-intents';

  /// True when the server has the feeding pay-intent route. An empty request
  /// is refused (422) by a server that has it and "not found" (404/405) by
  /// one that doesn't; nothing is charged either way.
  static Future<bool> parentPayAvailable(String studentId) async {
    final known = _payAvailable;
    if (known != null) return known;
    try {
      await _api.post(feedingPayIntentPath(studentId), const {});
      return _payAvailable = true;
    } on ApiException catch (e) {
      if (e.status == 404 || e.status == 405) return _payAvailable = false;
      if (e.status == 422 || e.status == 400) return _payAvailable = true;
      return false; // Network trouble or auth: ask again next time.
    } catch (_) {
      return false;
    }
  }

  static void resetPayAvailability() => _payAvailable = null;

  static Future<Map<String, dynamic>> startParentFeedingPayment({
    required String studentId,
    required String provider,
    required String payerPhone,
    required String option,
    String mode = 'arrears_first',
    int? days,
    double? amount,
  }) async =>
      _data(await _api.post(feedingPayIntentPath(studentId), {
        'provider': provider,
        'payer_phone': payerPhone,
        'option': option,
        'mode': mode,
        if (days != null) 'days': days,
        if (amount != null) 'amount': double.parse(amount.toStringAsFixed(2)),
      }));

  static Future<Map<String, dynamic>> paymentIntent(String id) async => _data(await _api.get('payment-intents/$id'));

  // Staff "My attendance".
  static Future<Map<String, dynamic>> myAttendance({required String from, required String to, int page = 1}) async =>
      _map(await _api.get(ApiConfig.myAttendancePath, query: {'from': from, 'to': to, 'per_page': '50', 'page': '$page'}));

  /// A receipt PDF: the server's `receipt_url` when it gave one (fees),
  /// otherwise the feeding receipt for [paymentId].
  static Future<Uint8List> receipt({String? url, String paymentId = ''}) {
    final path = (url ?? '').trim().isNotEmpty ? url!.trim() : '/api/feeding-payments/$paymentId/receipt';
    final absolute = path.startsWith('http') ? path : Uri.parse(ApiConfig.baseUrl).resolve(path).toString();
    return _api.getBytes(absolute, accept: 'application/pdf');
  }
}

/// What the signed-in user may do at the counter — the same checks as the
/// website: a permission from the server plus the module in the school's plan.
class FeedingAccess {
  static bool _can(AppUser user, String permission) => user.permissions.contains(permission);

  static bool collectFees(AppUser user) => _can(user, 'payments.collect') && PlanAccess.hasModule('fees');
  static bool collectFeeding(AppUser user) => _can(user, 'feeding.collect') && PlanAccess.hasModule('feeding');
  static bool viewFeeding(AppUser user) =>
      (_can(user, 'feeding.collect') || _can(user, 'feeding.view') || _can(user, 'feeding.settings')) &&
      PlanAccess.hasModule('feeding');

  // The bursar's Feeding tabs, as on the website.
  static bool seeAllFeeding(AppUser user) => _can(user, 'feeding.view') && PlanAccess.hasModule('feeding');
  static bool voidFeeding(AppUser user) => _can(user, 'feeding.void');
  static bool cashup(AppUser user) => _can(user, 'feeding.cashup') && PlanAccess.hasModule('feeding');
  static bool feedingSettings(AppUser user) => _can(user, 'feeding.settings') && PlanAccess.hasModule('feeding');

  static bool viewExpenses(AppUser user) => _can(user, 'expenses.view') && PlanAccess.hasModule('fees');
  static bool createExpense(AppUser user) => _can(user, 'expenses.create');
  static bool updateExpense(AppUser user) => _can(user, 'expenses.update');
  static bool voidExpense(AppUser user) => _can(user, 'expenses.void');
  static bool expenseCategories(AppUser user) => _can(user, 'expenses.categories');
}

/// The school's currency from the login reply (`school.currency_code`).
String schoolCurrency() {
  final school = ApiSession.instance.user?['school'];
  final code = school is Map ? '${school['currency_code'] ?? ''}'.trim() : '';
  return code.isEmpty ? 'GHS' : code;
}

double numOf(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

int intOf(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String money(dynamic v, String currency) {
  final value = numOf(v);
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$currency ${value < 0 ? '-' : ''}$whole.${parts[1]}';
}

String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

String? textOf(dynamic v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty || s == 'null' ? null : s;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Mon, 26 Oct" for a yyyy-mm-dd date.
String dayLabel(dynamic raw) {
  final s = textOf(raw);
  if (s == null) return '—';
  final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
  if (d == null) return s;
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// "October 2026" for a yyyy-mm month.
String monthLabel(String month) {
  final d = DateTime.tryParse('$month-01');
  return d == null ? month : '${_monthNames[d.month - 1]} ${d.year}';
}

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

String shiftMonth(String month, int by) {
  final d = DateTime.tryParse('$month-01') ?? DateTime.now();
  return monthKey(DateTime(d.year, d.month + by));
}

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "09:41" in local time for an ISO timestamp.
String timeLabel(dynamic raw) {
  final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
  if (d == null) return '—';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// "Mon, 26 Oct · 09:41" for an ISO timestamp.
String stampLabel(dynamic raw) {
  final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
  if (d == null) return '—';
  return '${dayLabel(dateKey(d))} · ${timeLabel(raw)}';
}

/// How a counter payment was made.
const counterMethods = [
  ('cash', 'Cash'),
  ('mtn_momo', 'MTN MoMo'),
  ('telecel_cash', 'Telecel Cash'),
  ('airteltigo_money', 'AirtelTigo Money'),
];

String methodLabel(dynamic method) {
  final m = '${method ?? ''}';
  for (final (value, label) in counterMethods) {
    if (value == m) return label;
  }
  if (m == 'mobile_money') return 'MoMo';
  if (m == 'cash') return 'Cash';
  return m;
}
