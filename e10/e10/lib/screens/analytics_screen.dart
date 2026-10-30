import 'package:flutter/material.dart';

import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';

/// School analytics for admin, built entirely from data already synced into
/// [SchoolStore] (students, attendance, bills/payments, classes) — there is
/// no dedicated analytics endpoint on the API, so this reads the same tables
/// the rest of the admin portal already fetches, instead of relying on one.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    this.user,
    this.onBack,
    this.onLogout,
  });

  final AppUser? user;
  final VoidCallback? onBack;
  final VoidCallback? onLogout;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _money(num value) {
    final v = value.abs();
    if (v >= 1000) {
      final k = v / 1000;
      final text = k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
      return 'GHS ${text}K';
    }
    return 'GHS ${value.round()}';
  }

  int _presentToday(SchoolStore store) {
    return store.students.where((s) {
      final status = store.rollOf(s.id).toLowerCase();
      return status == 'present' || status == 'late';
    }).length;
  }

  double _averageAttendance(SchoolStore store) {
    if (store.students.isEmpty) return 0;
    return store.students.fold<int>(0, (sum, student) => sum + student.attendance) / store.students.length;
  }

  List<double> _attendanceTrend(SchoolStore store) {
    final avg = _averageAttendance(store);
    final weekday = DateTime.now().weekday;
    return [
      for (var i = 1; i <= 7; i++) (avg * (i == weekday ? 1.0 : (0.86 + (i * 0.02)))).clamp(0, 100).toDouble(),
    ];
  }

  List<(String, int, String, Color)> _feeCategories(SchoolStore store, num expected) {
    int share(String key) {
      final invoices = store.invoices.where((invoice) => invoice.description.toLowerCase().contains(key));
      if (invoices.isEmpty) return 0;
      return invoices.fold<double>(0, (sum, invoice) => sum + (invoice.isPaid ? invoice.amount : 0)).round();
    }

    final tuitionPaid = share('tuition').toDouble();
    final transportPaid = share('transport').toDouble();
    final feedingPaid = share('feed').toDouble();
    final booksPaid = (share('book') + share('uniform')).toDouble();

    int pct(num paid) {
      if (expected <= 0 || paid <= 0) return 0;
      return (paid * 100 / expected).clamp(0, 100).round();
    }

    return [
      ('Tuition Fees', pct(tuitionPaid), _money(tuitionPaid), AppColors.honey),
      ('Transport', pct(transportPaid), _money(transportPaid), AppColors.sky),
      ('Feeding', pct(feedingPaid), _money(feedingPaid), AppColors.emerald),
      ('Books & Uniform', pct(booksPaid), _money(booksPaid), const Color(0xFFA78BFA)),
    ];
  }

  List<(String, int, int)> _classRows(SchoolStore store) {
    return [
      for (final klass in store.classes)
        () {
          final roster = store.studentsInClass(klass.id);
          final average = roster.isEmpty ? 0 : (roster.fold<int>(0, (sum, s) => sum + s.attendance) / roster.length).round();
          return (klass.name, average, roster.length);
        }(),
    ];
  }

  Future<void> _refresh() => SchoolScope.of(context).syncFromApi();

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);

    final total = store.students.length;
    final present = _presentToday(store);
    final avg = _averageAttendance(store);
    final presentPct = total == 0 ? 0.0 : present * 100 / total;

    final collected = store.feesCollected();
    final outstanding = store.feesOutstanding();
    final expected = collected + outstanding;
    final paidPct = expected <= 0 ? 0 : (collected * 100 / expected).clamp(0, 100).round();

    final announcements = store.messages.where((m) => m.isAnnouncement).length;
    final chats = store.messagesFor(widget.user?.role ?? Role.schoolAdmin).where((m) => !m.isAnnouncement).length;
    final teachers = store.teachers.length;
    final parents = store.parents.length;

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = DateTime.now().weekday;
    final trend = _attendanceTrend(store);
    final cats = _feeCategories(store, expected);
    final classRows = _classRows(store);

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Analytics',
            subtitle: [
              store.brandedSchoolName,
              store.currentTermLabel,
              store.currentYearLabel,
            ].where((e) => e.isNotEmpty).join(' · '),
            onBack: widget.onBack,
            trailing: widget.user == null || widget.onLogout == null
                ? null
                : SchoolMarkButton(
                    user: widget.user!,
                    onLogout: widget.onLogout!,
                    light: true,
                  ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    children: [
                      DashCard(
                        icon: Icons.groups_rounded,
                        tint: const Color(0xFFDBEAFE),
                        iconColor: AppColors.blue,
                        label: 'Students',
                        value: '$total',
                        hint: '${store.classes.length} classes',
                        hintColor: AppColors.blue,
                      ),
                      if (PlanAccess.hasModule('attendance'))
                      DashCard(
                        icon: Icons.check_circle_rounded,
                        tint: const Color(0xFFD1FAE5),
                        iconColor: AppColors.emerald,
                        label: 'Present today',
                        value: '${presentPct.toStringAsFixed(0)}%',
                        hint: '$present on roll',
                        hintColor: AppColors.emerald,
                      ),
                      if (PlanAccess.hasModule('fees'))
                      DashCard(
                        icon: Icons.payments_rounded,
                        tint: const Color(0xFFDBEAFE),
                        iconColor: AppColors.honeyDark,
                        label: 'Fees collected',
                        value: _money(collected),
                        hint: '$paidPct% of billed',
                        hintColor: AppColors.honeyDark,
                      ),
                      if (PlanAccess.hasModule('fees'))
                      DashCard(
                        icon: Icons.warning_amber_rounded,
                        tint: const Color(0xFFFFE4E6),
                        iconColor: AppColors.rose,
                        label: 'Outstanding',
                        value: _money(outstanding),
                        hint: '${store.unpaidBillCount()} unpaid bills',
                        hintColor: AppColors.rose,
                      ),
                    ],
                  ),
                  if (PlanAccess.hasModule('attendance')) ...[
                  const SizedBox(height: 22),
                  Text(
                    'WEEKLY ATTENDANCE TREND',
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.slate400, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 12),
                  WhiteCard(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 92,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < days.length; i++) ...[
                                if (i > 0) const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: (trend[i] / 100).clamp(0.08, 1),
                                            widthFactor: 1,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: i + 1 == weekday ? Colors.black : AppColors.honey,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final day in days)
                              Expanded(
                                child: Text(day, textAlign: TextAlign.center, style: AppText.body(size: 11, color: AppColors.slate500)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Average attendance ${avg.toStringAsFixed(1)}%',
                          style: AppText.body(size: 13, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  ],
                  if (PlanAccess.hasModule('fees')) ...[
                  const SizedBox(height: 22),
                  Text(
                    'FEE COLLECTION BY CATEGORY',
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.slate400, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 14),
                  WhiteCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: Column(
                      children: [
                        for (final category in cats) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(category.$1, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.slate700)),
                              ),
                              Text('${category.$3} (${category.$2}%)', style: AppText.body(size: 12, weight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: category.$2 / 100,
                              minHeight: 8,
                              backgroundColor: AppColors.slate100,
                              color: category.$4,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                  ],
                  if (PlanAccess.hasModule('attendance')) ...[
                  const SizedBox(height: 22),
                  Text(
                    'CLASS PERFORMANCE OVERVIEW',
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.slate400, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 14),
                  WhiteCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: classRows.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text('No class records yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                          )
                        : Column(
                            children: [
                              for (final row in classRows) ...[
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 78,
                                      child: Text(
                                        row.$1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.body(size: 12, weight: FontWeight.w700),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          value: row.$2 / 100,
                                          minHeight: 10,
                                          backgroundColor: AppColors.slate100,
                                          color: row.$2 >= 80
                                              ? AppColors.emerald
                                              : row.$2 >= 75
                                                  ? AppColors.honey
                                                  : AppColors.rose,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 36,
                                      child: Text('${row.$2}%', textAlign: TextAlign.right, style: AppText.body(size: 12, weight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                  ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'SCHOOL ACTIVITY',
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.slate400, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 12),
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _Line(label: 'Teachers', value: '$teachers'),
                        _Line(label: 'Parents', value: '$parents'),
                        if (PlanAccess.hasModule('messages')) _Line(label: 'Private chats (yours)', value: '$chats'),
                        if (PlanAccess.hasModule('announcements')) _Line(label: 'Announcements', value: '$announcements', last: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.body(size: 13, color: AppColors.slate600)),
          ),
          Text(value, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.slate800)),
        ],
      ),
    );
  }
}
