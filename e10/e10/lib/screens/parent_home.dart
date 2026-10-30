import 'package:flutter/material.dart';

import '../auth.dart';
import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/home_cards.dart';
import '../widgets/dash_cards.dart';
import '../widgets/student_profile_sheet.dart';
import '../widgets/txn_tiles.dart';
import '../widgets/motion.dart';

/// ===============================================================
/// PARENT HOME
/// ===============================================================

class ParentHome extends StatefulWidget {
  const ParentHome({
    super.key,
    required this.user,
    required this.onNav,
    required this.onLogout,
  });

  final AppUser user;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _AttendanceGrid extends StatelessWidget {
  const _AttendanceGrid({required this.child, required this.store, required this.onViewAll});

  final Student child;
  final SchoolStore store;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final summary = store.attendanceTermSummaryFor(child.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHead(
          title: 'Attendance · ${store.currentTermLabel}',
          action: 'View all',
          onAction: onViewAll,
        ),
        if (summary.totalDays == 0)
          WhiteCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Attendance will appear here after the school records it.',
              style: AppText.body(size: 12, color: AppSurface.ink(context)),
            ),
          )
        else
          AttendanceStatGrid(
            totalLabel: '${summary.totalDays} days recorded this term',
            stats: [
              (label: 'Present', value: summary.present, icon: Icons.check_circle_rounded, color: AppColors.emerald),
              (label: 'Absent', value: summary.absent, icon: Icons.cancel_rounded, color: AppColors.rose),
              (label: 'Late', value: summary.late, icon: Icons.timer_outlined, color: AppColors.amber),
              (label: 'Excused', value: summary.excused, icon: Icons.event_busy_rounded, color: AppColors.blue),
            ],
          ),
      ],
    );
  }
}

class _ParentSchoolPicker extends StatelessWidget {
  const _ParentSchoolPicker({required this.children, required this.selectedSchoolId, required this.onChanged});

  final List<Student> children;
  final String selectedSchoolId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final schools = <String, String>{
      for (final child in children)
        if (child.schoolId.isNotEmpty) child.schoolId: child.schoolName.isEmpty ? child.schoolId : child.schoolName,
    };
    if (!schools.containsKey(selectedSchoolId)) return const SizedBox.shrink();
    return WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedSchoolId,
          icon: const Icon(Icons.expand_more_rounded),
          items: [
            for (final entry in schools.entries)
              DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null && value != selectedSchoolId) onChanged(value);
          },
        ),
      ),
    );
  }
}

/// The child's attendance today in one line, from today's record: palm
/// check-in/out for day students, the class teacher's mark for boarders.
(String, Color) _todayStatus(SchoolStore store, Student child) {
  final now = DateTime.now();
  final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  Map<String, dynamic>? row;
  for (final r in store.attendanceRowsFor(child.id)) {
    if ('${r['date'] ?? ''}'.startsWith(today)) {
      row = r;
      break;
    }
  }
  final name = child.name.split(' ').first;
  if (row == null) {
    return child.boarder
        ? ('$name: not marked yet today', AppColors.slate500)
        : ('$name: not in yet today', AppColors.slate500);
  }
  final status = '${row['status'] ?? ''}'.toLowerCase();
  final inAt = SchoolStore.clockOf(row['check_in_at']);
  final outAt = SchoolStore.clockOf(row['check_out_at']);
  final how = SchoolStore.isPalmRecord(row) ? ' · palm scan' : '';
  if (status == 'absent') return ('$name: absent today', AppColors.rose);
  if (status == 'excused' || status == 'authorized_absence') return ('$name: excused today', AppColors.blue);
  final late = status == 'late';
  final color = late ? AppColors.amber : AppColors.emerald;
  if (outAt.isNotEmpty) return ('$name: in $inAt, left $outAt$how', color);
  if (inAt.isNotEmpty) return ('$name: arrived $inAt${late ? ' (late)' : ''}$how', color);
  return ('$name: ${late ? 'late' : 'present'} today', color);
}

class _ParentHomeState extends State<ParentHome> {
  bool _loadingApi = false;
  String? _schoolApiMessage;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadParentData();
    });
  }

  /// =============================================================
  /// LOAD PARENT DATA
  /// =============================================================

  Future<void> _loadParentData() async {
    final store = SchoolScope.of(context);

    // Refresh the guardian-child links from the API BEFORE reading them —
    // `linkedChildren` is sourced from `ApiSession.instance.user['guardian']
    // ['students']`, which is only as fresh as the last login or this call.
    // Reading it first (as this used to) would prefetch fees for whatever
    // children were linked at last login, missing anyone linked since.
    try {
      setState(() {
        _loadingApi = true;
        _schoolApiMessage = null;
      });

      final result = await Auth.currentUser();

      if (!mounted) return;

      if (!result.ok && result.error?.contains('Session expired') == true) {
        setState(() {
          _schoolApiMessage =
              'Your session has expired. Please log in again.';
        });
      } else if (result.ok) {
        setState(() {
          _schoolApiMessage = null;
        });
      } else {
        setState(() {
          _schoolApiMessage =
              result.error ??
              'Unable to refresh your account.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _schoolApiMessage =
            'Unable to connect to the school server.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingApi = false;
        });
      }
    }

    if (!mounted) return;

    // `Auth.currentUser()` above only refreshes the session/guardian-child
    // links — it never re-fetches `/school` or the bootstrap tables, so
    // admin edits (school profile, classes, timetable, teachers, ...) never
    // reached an already-signed-in parent until they force-quit and
    // relaunched the app. A full syncFromApi() here makes pull-to-refresh
    // actually pick those up.
    await store.syncFromApi(budget: const Duration(seconds: 12));
    if (!mounted) return;

    final kids = store.linkedChildren(Role.parent);

    final child = store.focusedChild(Role.parent);

    if (child != null && store.focusedChildId != child.id) {
      store.focusChild(child.id);
    }

    await Future.wait([
      for (final kid in kids) store.refreshChildFees(kid.id),
    ]);
  }

  List<Student> _schoolChildren(SchoolStore store) => [
        for (final child in store.linkedChildren(Role.parent))
          if (child.schoolId.trim().isNotEmpty || child.schoolName.trim().isNotEmpty) child,
      ];

  Future<void> _selectSchool(SchoolStore store, String schoolId) async {
    final child = store.linkedChildren(Role.parent).where((item) => item.schoolId == schoolId).firstOrNull;
    if (child == null) return;
    store.focusChild(child.id);
    final result = await Auth.guardianEnterSchool(schoolId);
    if (!mounted) return;
    if (!result.ok) {
      setState(() => _schoolApiMessage = result.error ?? 'Could not enter that school.');
      return;
    }
    store.applyUserSchool(result.user!);
    await store.syncFromApi(budget: const Duration(seconds: 12));
    if (mounted) setState(() => _schoolApiMessage = null);
  }

  /// =============================================================
  /// SCHOOL DISPLAY
  /// =============================================================

  String _schoolLine(SchoolStore store) {
    final term = store.currentTermLabel;
    final year = store.currentYearLabel;

    final parts = [
      store.brandedSchoolName,
      if (term.isNotEmpty && year.isNotEmpty)
        '$term, $year'
      else if (term.isNotEmpty)
        term
      else if (year.isNotEmpty)
        year,
    ];

    return parts.join(' · ');
  }

  /// =============================================================
  /// TODAY'S TIMETABLE
  /// =============================================================


  /// =============================================================
  /// TIME
  /// =============================================================



  /// =============================================================
  /// BUILD
  /// =============================================================

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);

    final kids =
        store.linkedChildren(Role.parent);

    final child =
        store.focusedChild(Role.parent) ??
            const Student(
              id: '',
              name: 'No linked child',
              klass: '',
              avatar: 'S',
              attendance: 0,
              fees: 0,
              outstanding: 0,
              status: 'active',
            );

    final messages = store.messagesFor(Role.parent);

    final apiHint = _schoolApiMessage;

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          /// ======================================================
          /// HEADER
          /// ======================================================

          DashAccountHeader(
            user: widget.user,
            subtitle: _schoolLine(store),
            onLogout: widget.onLogout,
            onTapSchool: () => widget.onNav(AppScreen.schoolProfile),
          ),
          const SyncBar(),

          // Its own child-data load; hidden while the shared bar above shows.
          if (_loadingApi && !store.loading)
            const LinearProgressIndicator(
              minHeight: 2,
            ),

          if (_schoolChildren(store).map((child) => child.schoolId).toSet().length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _ParentSchoolPicker(
                children: _schoolChildren(store),
                selectedSchoolId: child.schoolId,
                onChanged: (schoolId) => _selectSchool(store, schoolId),
              ),
            ),

          /// ======================================================
          /// BODY
          /// ======================================================

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadParentData,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24,
              ),
              children: dashboardChildren(context, [
                /// ==================================================
                /// API MESSAGE
                /// ==================================================

                if (apiHint != null &&
                    apiHint.isNotEmpty) ...[
                  WhiteCard(
                    padding:
                        const EdgeInsets.all(12),
                    child: Text(
                      apiHint,
                      style: AppText.body(
                        size: 12,
                        color: AppSurface.ink(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                /// ==================================================
                /// NO CHILD
                /// ==================================================

                if (kids.isEmpty)
                  WhiteCard(
                    padding:
                        const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No child linked yet',
                          style: AppText.body(
                            size: 15,
                            weight: FontWeight.w700,
                            color:
                                AppSurface.ink(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Once the school office links a child to this account, tap the arrow in the header to switch between children.',
                          style: AppText.body(
                            size: 14,
                            color:
                                AppSurface.ink(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                /// ==================================================
                /// CHILD FINANCE
                /// ==================================================

                if (child.id.isNotEmpty) ...[
                  if (PlanAccess.allows(AppScreen.attendance)) ...[
                  _AttendanceGrid(
                    child: child,
                    store: store,
                    onViewAll: () => widget.onNav(AppScreen.attendance),
                  ),
                  const SizedBox(height: 20),
                  ],
                  SectionLabel(text: PlanAccess.allows(AppScreen.payments) ? 'Payments' : 'My child'),
                  Builder(
                    builder: (context) {
                      final finance =
                          store.studentFinance(
                        child.id,
                      );

                      final recent =
                          store.paymentsForStudent(
                        child.id,
                      );

                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          AppRadius.lg,
                        ),
                        child: ColoredBox(
                          color:
                              AppSurface.card(context),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              /// CHILD HEADER
                              GestureDetector(
                                onTap: () => showStudentProfileSheet(context, child),
                                child: Container(
                                width:
                                    double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      'MY CHILD',
                                      style:
                                          AppText.body(
                                        size: 11,
                                        weight:
                                            FontWeight
                                                .w800,
                                        color: AppSurface.ink(context),
                                        letterSpacing:
                                            0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        'Student ID: ${store.studentDisplayId(child)}',
                                        if (child.klass.isNotEmpty) child.klass,
                                      ].join(' · '),
                                      style: AppText.body(
                                        size: 13,
                                        color: AppSurface.ink(context),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.badge_outlined,
                                          size: 14,
                                          color: AppSurface.muted(context),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'View profile',
                                          style: AppText.body(
                                            size: 12,
                                            weight: FontWeight.w700,
                                            color: AppSurface.ink(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                ),
                              ),

                              /// FINANCE
                              if (PlanAccess.allows(AppScreen.payments))
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Row(
                                      children: [
                                        _HomeMoney(
                                          label:
                                              'Total bill',
                                          value:
                                              finance.charges,
                                          color:
                                              AppColors
                                                  .blue,
                                        ),
                                        _HomeMoney(
                                          label: 'Paid',
                                          value:
                                              finance.paid,
                                          color:
                                              AppColors
                                                  .emerald,
                                        ),
                                        _HomeMoney(
                                          label:
                                              'Outstanding',
                                          value:
                                              finance.balance,
                                          color: finance
                                                      .balance >
                                                  0.009
                                              ? AppColors
                                                  .rose
                                              : AppColors
                                                  .emerald,
                                        ),
                                      ],
                                    ),

                                    if (finance.balance > 0.009) ...[
                                      const SizedBox(height: 14),
                                      HoneyButton(
                                        label: 'Pay fees',
                                        color: AppColors.blue,
                                        onPressed: () {
                                          store.focusChild(child.id);
                                          widget.onNav(AppScreen.payments);
                                        },
                                      ),
                                    ],

                                    /// RECENT TRANSACTION
                                    if (recent.isNotEmpty) ...[
                                      const SizedBox(
                                        height: 18,
                                      ),
                                      Text(
                                        'RECENT TRANSACTION',
                                        style:
                                            AppText.body(
                                          size: 11,
                                          weight:
                                              FontWeight
                                                  .w800,
                                          color:
                                              AppSurface.ink(context),
                                          letterSpacing:
                                              0.6,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      ChildTxnCard(
                                        txn:
                                            recent.first,
                                        childName:
                                            child.name,
                                        schoolName: store
                                            .brandedSchoolName,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  if (child.id.isNotEmpty && store.isEarlyYearsChild(child) && PlanAccess.allows(AppScreen.parentDailyReport)) ...[
                    DailyReportHomeCard(
                      child: child,
                      onOpen: () {
                        store.focusChild(child.id);
                        widget.onNav(AppScreen.parentDailyReport);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (PlanAccess.allows(AppScreen.teacherAnnouncements)) ...[
                  LatestAnnouncementsCard(onOpen: () => widget.onNav(AppScreen.teacherAnnouncements)),
                  const SizedBox(height: 16),
                  ],

                  if (child.id.isNotEmpty && PlanAccess.allows(AppScreen.parentReports)) ...[
                    ExamsReportsHomeCard(
                      child: child,
                      onOpenExams: () {
                        store.focusChild(child.id);
                        widget.onNav(AppScreen.teacherExams);
                      },
                      onOpenReports: () {
                        store.focusChild(child.id);
                        widget.onNav(AppScreen.parentReports);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (PlanAccess.allows(AppScreen.attendance)) ...[
                  Builder(builder: (context) {
                    final (status, color) = _todayStatus(store, child);
                    return AttendanceAlertsCard(
                      items: store.attendanceNoticesToday(Role.parent),
                      status: child.id.isEmpty ? null : status,
                      statusColor: color,
                      onOpen: () {
                        store.focusChild(child.id);
                        widget.onNav(AppScreen.attendance);
                      },
                    );
                  }),

                  const SizedBox(
                    height: 16,
                  ),
                  ],

                  /// =================================================
                  /// QUICK ACTIONS
                  /// =================================================

                  const SectionLabel(
                    text: 'Jump in',
                  ),

                  Row(
                    children: [
                      if (PlanAccess.allows(AppScreen.payments))
                      SquareQuickAction(
                        color: AppColors.iconPalette[0],
                        icon: Icons.receipt_long_rounded,
                        label: 'Pay fees',
                        onTap: () {
                          store.focusChild(child.id);
                          widget.onNav(AppScreen.payments);
                        },
                      ),

                      // Crèche / KG children get their Daily report here;
                      // everyone else keeps the Timetable.
                      if (store.isEarlyYearsChild(child) && PlanAccess.allows(AppScreen.parentDailyReport))
                        SquareQuickAction(
                          color: AppColors.iconPalette[1],
                          icon: Icons.child_care_rounded,
                          label: 'Daily report',
                          onTap: () {
                            store.focusChild(child.id);
                            widget.onNav(AppScreen.parentDailyReport);
                          },
                        )
                      else if (PlanAccess.allows(AppScreen.adminTimetable))
                        SquareQuickAction(
                          color: AppColors.iconPalette[2],
                          icon: Icons.calendar_month_rounded,
                          label: 'Timetable',
                          onTap: () {
                            store.focusChild(child.id);
                            widget.onNav(AppScreen.adminTimetable);
                          },
                        ),

                      if (PlanAccess.allows(AppScreen.homework))
                      SquareQuickAction(
                        color:
                            AppColors.iconPalette[3],
                        icon:
                            Icons.menu_book_rounded,
                        label: 'Homework',
                        onTap: () {
                          widget.onNav(
                            AppScreen.homework,
                          );
                        },
                      ),

                      SquareQuickAction(
                        color:
                            AppColors.iconPalette[4],
                        icon: Icons
                            .dashboard_customize_rounded,
                        label: 'School life',
                        onTap: () {
                          widget.onNav(
                            AppScreen.schoolLife,
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 16,
                  ),
                ],

                if (PlanAccess.allows(AppScreen.messages)) ...[
                SectionHead(
                  title: 'Open chats',
                  action: 'Messages',
                  onAction: () => widget.onNav(AppScreen.messages),
                ),
                if (messages.isEmpty)
                  const WhiteCard(
                    padding: EdgeInsets.all(14),
                    child: Text('No conversations yet.'),
                  )
                else
                  for (final message in messages.take(3))
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message.from, style: AppText.body(size: 13, weight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(message.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: AppSurface.ink(context))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(message.unread ? 'Unread' : 'Read', style: AppText.body(size: 11, color: AppSurface.ink(context))),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),
                ],

                /// ==================================================
                /// TODAY
                /// ==================================================

                if (PlanAccess.allows(AppScreen.adminTimetable))
                WeekTimetableCard(
                  title: 'Timetable',
                  slots: kids.isEmpty ? const <TimeSlot>[] : store.timetable.where((slot) => store.slotMatchesChild(slot, child)).toList(),
                  emptyText: 'No classes on the board yet. Check back in a bit.',
                  onOpen: () => widget.onNav(AppScreen.adminTimetable),
                ),
              ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// MONEY CARD
/// ===============================================================

class _HomeMoney extends StatelessWidget {
  const _HomeMoney({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppText.body(
              size: 10,
              weight: FontWeight.w800,
              color:
                  AppSurface.ink(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'GHS ${value.toStringAsFixed(2)}',
            style: AppText.body(
              size: 13,
              weight: FontWeight.w800,
              color: AppSurface.ink(context),
            ),
          ),
        ],
      ),
    );
  }
}
