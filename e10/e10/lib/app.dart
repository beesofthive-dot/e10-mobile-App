import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';
import 'api/api_session.dart';
import 'data.dart';
import 'models.dart';
import 'school_store.dart';
import 'screens/cashier_counter_screen.dart';
import 'screens/department_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/feeding_today_screen.dart';
import 'screens/my_attendance_screen.dart';
import 'screens/parent_feeding_screen.dart';
import 'screens/parent_report_cards_screen.dart';
import 'screens/staff_report_cards_screen.dart';
import 'screens/admin_academics.dart';
import 'screens/admin_forms.dart' show showSnack;
import 'screens/admin_home.dart';
import 'screens/staff_attendance_screen.dart';
import 'screens/admin_manage.dart';
import 'screens/admin_records.dart';
import 'screens/admin_reports.dart';
import 'screens/admin_roles.dart';
import 'screens/admin_timetable.dart';
import 'screens/analytics_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/clinic_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/homework_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/library_screen.dart';
import 'screens/login_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/parent_home.dart';
import 'screens/payments_screen.dart';
import 'plan_access.dart';
import 'screens/plan_locked_screen.dart';
import 'screens/platform_contact_messages_screen.dart';
import 'screens/platform_home_screen.dart';
import 'screens/platform_schools_screen.dart';
import 'screens/platform_signup_requests_screen.dart';
import 'screens/school_affairs_screen.dart';
import 'screens/school_life_screen.dart';
import 'screens/school_profile_screen.dart';
import 'screens/school_signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/staff_home.dart';
import 'screens/students_screen.dart';
import 'screens/teacher_classes.dart';
import 'screens/teacher_daily_reports_screen.dart';
import 'screens/teacher_home.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/teacher_drawer.dart';

class E10App extends StatefulWidget {
  const E10App({super.key, this.debugUser, this.debugScreen});

  /// Tests only: open straight onto [debugScreen] as [debugUser], skipping
  /// splash/login and the saved-session restore.
  @visibleForTesting
  final AppUser? debugUser;
  @visibleForTesting
  final AppScreen? debugScreen;

  @override
  State<E10App> createState() => _E10AppState();
}

class _E10AppState extends State<E10App> with WidgetsBindingObserver {
  AppScreen _screen = AppScreen.splash;
  AppUser? _user;
  final List<AppScreen> _history = [];

  /// Signed-in users are logged out after this long without a tap, scroll
  /// or key press — also while the app is closed or in the background.
  static const _idleLimit = Duration(minutes: 3);
  static const _lastActiveKey = 'e10.last_active_at';
  Timer? _idleTimer;
  DateTime _lastActive = DateTime.now();
  DateTime? _lastActiveSaved;

  bool get _idleWatch => _user != null && widget.debugUser == null;

  /// Any interaction restarts the 3-minute countdown.
  void _touch() {
    if (!_idleWatch) return;
    _lastActive = DateTime.now();
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleLimit, _idleLogout);
    final saved = _lastActiveSaved;
    if (saved == null || _lastActive.difference(saved) > const Duration(seconds: 20)) _saveLastActive();
  }

  void _saveLastActive() {
    _lastActiveSaved = _lastActive;
    unawaited(
        SharedPreferences.getInstance().then((p) => p.setInt(_lastActiveKey, _lastActive.millisecondsSinceEpoch)).catchError((_) => false));
  }

  Future<void> _idleLogout() async {
    if (!_idleWatch) return;
    await _logout();
    if (mounted) showSnack(context, 'Signed out after 3 minutes without activity. Sign in again to continue.');
  }

  bool _onKey(KeyEvent _) {
    _touch();
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    if (widget.debugUser != null) {
      _user = widget.debugUser;
      _screen = widget.debugScreen ?? homeFor(widget.debugUser!.role);
      return;
    }
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app pulls everything fresh straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_idleWatch && (state == AppLifecycleState.paused || state == AppLifecycleState.hidden)) _saveLastActive();
    if (state == AppLifecycleState.resumed && _idleWatch && DateTime.now().difference(_lastActive) >= _idleLimit) {
      unawaited(_idleLogout());
      return;
    }
    if (state == AppLifecycleState.resumed && _user != null) {
      // Coming back is not activity: keep counting from the last real tap.
      if (_idleWatch) {
        _idleTimer?.cancel();
        _idleTimer = Timer(_idleLimit - DateTime.now().difference(_lastActive), _idleLogout);
      }
      unawaited(SchoolScope.read(context).syncFromApi(budget: const Duration(seconds: 30)));
    }
  }

  /// Reopening the app goes straight back to the saved account's dashboard,
  /// then checks the login with the server in the background. Only a real
  /// "session expired" (401, which clears the saved token) signs the user
  /// out — a slow or unreachable server used to throw the login away too,
  /// forcing a fresh sign-in on almost every restart.
  Future<void> _restoreSession() async {
    await ApiSession.instance.restore();
    if (!mounted || !ApiSession.instance.isSignedIn) return;
    // Closed for longer than the idle limit: that session is over.
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastActiveKey);
    if (last != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) >= _idleLimit) {
      await Auth.logout();
      await prefs.remove(_lastActiveKey);
      return;
    }
    if (!mounted) return;
    final saved = ApiSession.instance.user;
    if (saved != null) await _login(Auth.userFromApi(saved));
    final result = await Auth.currentUser();
    if (!mounted) return;
    if (result.ok) {
      final fresh = result.user!;
      if (_user == null || _user!.role != fresh.role) {
        await _login(fresh);
      } else {
        setState(() => _user = fresh);
      }
    } else if (!ApiSession.instance.isSignedIn) {
      SchoolScope.read(context).clear();
      setState(() {
        _user = null;
        _history.clear();
        _screen = AppScreen.landing;
      });
    }
  }

  /// The splash moves on by itself; a saved session restored meanwhile has
  /// already switched to the dashboard, so only a signed-out user goes to login.
  void _leaveSplash() {
    if (_screen != AppScreen.splash) return;
    final user = _user;
    _go(user == null ? AppScreen.landing : homeFor(user.role));
  }

  bool get _atHome {
    final user = _user;
    return user == null || _screen == homeFor(user.role);
  }

  void _go(AppScreen screen) {
    final user = _user;
    if (user != null && !user.canOpen(screen)) {
      screen = screen == AppScreen.adminRoles ? AppScreen.adminManage : homeFor(user.role);
    }
    if (screen == _screen) return;
    setState(() {
      final home = user == null ? AppScreen.login : homeFor(user.role);
      if (screen == home || screen == AppScreen.login || screen == AppScreen.splash) {
        _history.clear();
      } else if (_screen != AppScreen.splash && _screen != AppScreen.login) {
        _history.add(_screen);
        if (_history.length > 24) _history.removeAt(0);
      }
      _screen = screen;
    });
  }

  void _back() {
    final user = _user;
    if (user == null) {
      // Signed out: back from sign-in (or school sign-up) returns to the landing page.
      if (_screen == AppScreen.login || _screen == AppScreen.schoolSignup) _go(AppScreen.landing);
      return;
    }
    final home = homeFor(user.role);
    setState(() {
      while (_history.isNotEmpty) {
        final prev = _history.removeLast();
        if (prev != _screen && user.canOpen(prev)) {
          _screen = prev;
          return;
        }
      }
      _history.clear();
      _screen = home;
    });
  }

  Future<void> _login(AppUser user) async {
    setState(() {
      _user = user;
      _history.clear();
      _screen = homeFor(user.role);
    });
    _lastActiveSaved = null;
    _touch();
    final store = SchoolScope.read(context);
    store.applyUserSchool(user);
    unawaited(store.syncFromApi(budget: const Duration(seconds: 20)));
  }

  Future<void> _logout() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    unawaited(SharedPreferences.getInstance().then((p) => p.remove(_lastActiveKey)).catchError((_) => false));
    await Auth.logout();
    if (!mounted) return;
    SchoolScope.of(context).clear();
    setState(() {
      _user = null;
      _history.clear();
      _screen = AppScreen.landing;
    });
  }

  /// A cashier only gets Messages when the school grants `messages.view`
  /// (the API refuses message threads otherwise); other roles as before.
  bool get _mayMessage => _user?.role != Role.cashier || _user!.permissions.contains('messages.view');

  bool get _showNav => _screen != AppScreen.splash && _screen != AppScreen.login && _user != null;

  String? _parentLockClass(BuildContext context) {
    final klass = SchoolScope.read(context).focusedChild(Role.parent)?.klass.trim();
    return klass == null || klass.isEmpty ? null : klass;
  }

  /// On every home dashboard, text without its own colour is plain black
  /// (see AppSurface.ink); the icons keep their colours.
  Widget _dashboardText(Widget child) {
    final user = _user;
    if (user == null || _screen != homeFor(user.role)) return child;
    return DefaultTextStyle.merge(style: TextStyle(color: AppSurface.ink(context)), child: child);
  }

  Widget _body() {
    final user = _user;
    if (user == null) {
      return switch (_screen) {
        AppScreen.splash => SplashScreen(onDone: _leaveSplash),
        AppScreen.landing => LandingScreen(
            onGetStarted: () => _go(AppScreen.login),
            onRegisterSchool: () => _go(AppScreen.schoolSignup),
          ),
        AppScreen.login => LoginScreen(
            onLogin: _login,
            onRegisterSchool: () => _go(AppScreen.schoolSignup),
          ),
        AppScreen.schoolSignup => SchoolSignupScreen(onBack: () => _go(AppScreen.login)),
        _ => SplashScreen(onDone: _leaveSplash),
      };
    }

    // Subscription gates: a locked school or a module outside the school's
    // plan explains itself instead of opening onto an empty screen.
    if (_screen != AppScreen.splash && _screen != AppScreen.login && user.accessLevel == 'none') {
      return SchoolLockedScreen(user: user, onLogout: _logout);
    }
    final lockedModule = lockedPlanModule(user, _screen);
    if (lockedModule != null) {
      return PlanLockedScreen(user: user, module: lockedModule, onBack: _back, onLogout: _logout);
    }

    return switch (_screen) {
      AppScreen.splash || AppScreen.landing => SplashScreen(onDone: _leaveSplash),
      AppScreen.login => LoginScreen(onLogin: _login),
      AppScreen.schoolSignup => SchoolSignupScreen(onBack: () => _go(homeFor(user.role))),
      AppScreen.schoolProfile => SchoolProfileScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.parentHome => ParentHome(user: user, onNav: _go, onLogout: _logout),
      AppScreen.adminHome => AdminHome(user: user, onNav: _go, onLogout: _logout),
      AppScreen.platformHome => PlatformHomeScreen(user: user, onNav: _go, onLogout: _logout),
      AppScreen.platformSchools => PlatformSchoolsScreen(
          onBack: _back,
          onLogout: _logout,
          onEnterSchool: _login,
        ),
      AppScreen.platformSignupRequests => PlatformSignupRequestsScreen(onBack: _back, onLogout: _logout),
      AppScreen.platformContactMessages => PlatformContactMessagesScreen(onBack: _back, onLogout: _logout),
      AppScreen.teacherHome => TeacherHome(user: user, onNav: _go, onLogout: _logout),
      AppScreen.teacherClasses => TeacherClassesScreen(onBack: _back, onLogout: _logout),
      AppScreen.payments => PaymentsScreen(
          user: user,
          onBack: _back,
          onLogout: _logout,
        ),
      AppScreen.staffAttendance => StaffAttendanceScreen(onBack: _back),
      AppScreen.attendance || AppScreen.teacherAttendance => AttendanceScreen(
          onBack: _back,
          onOpenStaff: user.role.isAdminPortal ? () => _go(AppScreen.staffAttendance) : null,
          role: user.role,
          user: user,
          onLogout: _logout,
        ),
      AppScreen.homework => HomeworkScreen(
          user: user,
          onBack: _back,
          onLogout: () => _logout(),
        ),
      AppScreen.teacherDailyReports => TeacherDailyReportsScreen(
          user: user,
          onBack: _back,
          onLogout: _logout,
        ),
      AppScreen.schoolLife => SchoolLifeScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.parentDailyReport => SchoolLifeScreen(user: user, onBack: _back, onLogout: _logout, initialTab: 'Daily report'),
      AppScreen.teacherExams => SchoolLifeScreen(user: user, onBack: _back, onLogout: _logout, initialTab: 'Exams'),
      AppScreen.teacherAnnouncements => AnnouncementsScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.messages => MessagesScreen(
          user: user,
          onBack: _back,
          onLogout: _logout,
        ),
      AppScreen.notifications => NotificationsScreen(
          user: user,
          role: user.role,
          onBack: _back,
          onLogout: _logout,
        ),
      AppScreen.inbox => InboxScreen(
          user: user,
          onBack: _back,
          onLogout: _logout,
        ),
      AppScreen.auditLog => NotificationsScreen(
          role: user.role,
          title: 'Audit log',
          onBack: _back,
          onLogout: _logout,
        ),
      AppScreen.adminStudents => StudentsScreen(
          onBack: _back,
          onLogout: _logout,
          viewOnly: user.role == Role.parent || user.role.isAdminPortal,
        ),
      AppScreen.adminFinance => FinanceScreen(
          onBack: _back,
          onLogout: _logout,
          viewOnly: user.role.isAdminPortal,
        ),
      AppScreen.analytics => AnalyticsScreen(onBack: _back, onLogout: _logout),
      // Report cards follow the website: class teachers fill and submit,
      // admins publish, parents see the published card.
      AppScreen.teacherReports || AppScreen.teacherMyReports =>
        StaffReportCardsScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.parentReports => ParentReportCardsScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.adminManage => AdminManageScreen(
          role: user.role,
          canManageRoles: user.canManageRoles,
          onNav: _go,
          onBack: _back,
          onLogout: _logout,
        ),
      AppScreen.adminRoles => user.canManageRoles
          ? AdminRolesScreen(onBack: _back, onLogout: _logout)
          : AdminManageScreen(role: user.role, canManageRoles: user.canManageRoles, onNav: _go, onBack: _back, onLogout: _logout),
      AppScreen.catalog => CatalogScreen(onBack: _back, onLogout: _logout),
      AppScreen.adminTeachers => AdminRecordsScreen(
          kind: AdminRecordKind.teachers,
          onBack: _back,
          onLogout: _logout,
          viewOnly: user.role.isAdminPortal,
        ),
      AppScreen.adminAccountants => AdminRecordsScreen(kind: AdminRecordKind.accountants, onBack: _back, onLogout: _logout),
      AppScreen.adminParents => AdminRecordsScreen(kind: AdminRecordKind.parents, onBack: _back, onLogout: _logout, viewOnly: false),
      AppScreen.adminClasses => AdminRecordsScreen(kind: AdminRecordKind.classes, onBack: _back, onLogout: _logout),
      AppScreen.adminDepartments => AdminRecordsScreen(
          kind: AdminRecordKind.departments,
          onBack: _back,
          onLogout: _logout,
          canManageHeads: user.role == Role.schoolAdmin || user.permissions.contains('departments.update'),
        ),
      AppScreen.adminTimetable => AdminTimetableScreen(
          onBack: _back,
          onLogout: _logout,
          // Only the school's admins change the timetable (the server allows
          // teachers to view it, not edit it).
          viewOnly: !user.role.isAdminPortal,
          teacherView: user.role == Role.teacher,
          opensOnToday: user.role == Role.teacher || user.role == Role.parent,
          // A parent should only ever see their focused child's own class
          // timetable, never the whole school's class list — the school-wide
          // picker below is for staff.
          lockClass: user.role == Role.parent ? (_parentLockClass(context) ?? '') : null,
        ),
      AppScreen.adminAcademics => AdminAcademicsScreen(onBack: _back, onLogout: _logout, viewOnly: user.role != Role.teacher),
      AppScreen.schoolAffairs => SchoolAffairsScreen(onNav: _go, onBack: _back, onLogout: _logout),
      AppScreen.adminReports => AdminReportsScreen(onBack: _back, onLogout: _logout, viewOnly: user.role.isAdminPortal),
      AppScreen.library => LibraryScreen(onBack: _back, onLogout: _logout),
      AppScreen.clinic => ClinicScreen(onBack: _back, onLogout: _logout),
      AppScreen.staffHome => StaffHome(user: user, onNav: _go, onLogout: _logout),
      AppScreen.cashierCounter => CashierCounterScreen(user: user, onNav: _go, onLogout: _logout),
      AppScreen.feedingToday => FeedingTodayScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.myAttendance => MyAttendanceScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.parentFeeding => ParentFeedingScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.expenses => ExpensesScreen(user: user, onBack: _back, onLogout: _logout),
      AppScreen.departmentHome => DepartmentHomeScreen(user: user, onNav: _go, onBack: _back),
      AppScreen.departmentStudents => DepartmentStudentsScreen(user: user, onBack: _back),
      AppScreen.departmentStaff => DepartmentStaffScreen(user: user, onBack: _back),
      AppScreen.departmentClasses => DepartmentClassesScreen(user: user, onBack: _back),
      AppScreen.departmentAttendance => DepartmentAttendanceScreen(user: user, onBack: _back),
      AppScreen.departmentHeads => DepartmentHeadsScreen(user: user, onBack: _back),
      AppScreen.studentDetail => ColoredBox(
          color: AppColors.navy,
          child: Center(
            child: Text('Coming soon', style: AppText.display(color: Colors.white)),
          ),
        ),
    };
  }

  Map<String, dynamic>? _seenProfile;

  /// `/auth/me` is re-read every couple of minutes, so a staff member the
  /// admin has just made a department head (or whose permissions changed)
  /// gets their new menus without signing in again. A changed role still
  /// goes through a new login.
  void _adoptFreshProfile() {
    final user = _user;
    final profile = ApiSession.instance.user;
    if (user == null || widget.debugUser != null || profile == null || identical(profile, _seenProfile)) return;
    _seenProfile = profile;
    final fresh = Auth.userFromApi(profile, password: user.password);
    if (fresh.role != user.role) return;
    _user = fresh;
    if (!fresh.canOpen(_screen)) {
      _history.clear();
      _screen = homeFor(fresh.role);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.read(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        _adoptFreshProfile();
        PlanAccess.user = _user;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: AppSurface.dark(context) ? AppColors.night : AppColors.navLight,
            systemNavigationBarIconBrightness: AppSurface.dark(context) ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: AppSurface.dark(context) ? AppColors.night : AppColors.navLight,
          ),
          child: PopScope(
            // On web there is only ever one route in the framework's own
            // Navigator (screen switches go through `_screen`/`_history`
            // above, not Navigator.push), so letting the system actually
            // pop it — as `canPop: true` did at home/login — crashes with
            // "_history.isNotEmpty is not true" the moment the browser back
            // button fires with nothing left underneath. Native platforms
            // still need `canPop: true` at home so the back button/gesture
            // exits the app as expected.
            canPop: kIsWeb ? false : (!_showNav || _atHome),
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (!_atHome) _back();
            },
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _touch(),
              onPointerSignal: (_) => _touch(),
              child: AppChrome(
                messageCount: _user == null ? 0 : store.unreadMessageCountFor(_user!.role),
                onMessages: PlanAccess.allows(AppScreen.messages) && _mayMessage ? () => _go(AppScreen.messages) : null,
                // Parents' header menu is Messages and Notifications only
                // (announcements reach them on the home screen).
                onAnnouncements: PlanAccess.allows(AppScreen.teacherAnnouncements) && _user?.role != Role.parent
                    ? () => _go(AppScreen.teacherAnnouncements)
                    : null,
                notificationCount: _user == null ? 0 : store.unreadNoticeCount(_user!.role),
                onNotifications: () => _go(AppScreen.notifications),
                showComms: _user != null &&
                    (_user!.role == Role.cashier ||
                        (_user!.role.canOpen(AppScreen.messages) && _user!.role.canOpen(AppScreen.teacherAnnouncements))),
                child: Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  drawer: _user?.role == Role.teacher ? TeacherDrawer(user: _user!, active: _screen, onNav: _go, onLogout: _logout) : null,
                  body: Column(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.03),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          // Every top-level screen swap in the app used to be an
                          // instant cut — no fade, no motion — because `_body()`
                          // was returned directly. Keying on `_screen` gives
                          // every navigation the same soft cross-fade + rise,
                          // system-wide, from one place.
                          child: KeyedSubtree(key: ValueKey(_screen), child: _dashboardText(_body())),
                        ),
                      ),
                      if (_showNav && _user != null) BottomNav(active: _screen, role: _user!.role, onNav: _go),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
