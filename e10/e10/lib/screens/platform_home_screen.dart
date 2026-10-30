import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/dash_cards.dart';
import '../widgets/motion.dart';

/// Landing screen for a BeeSoft Hive platform super admin (`is_super_admin`
/// on the logged-in user) — a hub across every school on e10, not just one.
class PlatformHomeScreen extends StatefulWidget {
  const PlatformHomeScreen({super.key, required this.user, required this.onNav, required this.onLogout});

  final AppUser user;
  final ValueChanged<AppScreen> onNav;
  final VoidCallback onLogout;

  @override
  State<PlatformHomeScreen> createState() => _PlatformHomeScreenState();
}

class _PlatformHomeScreenState extends State<PlatformHomeScreen> {
  bool _loading = true;
  int _schoolCount = 0;
  int _pendingSignups = 0;
  int _unreadMessages = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final store = SchoolScope.of(context);
    final results = await Future.wait([
      store.fetchPlatformSchools(),
      store.fetchPlatformSignupRequests(),
      store.fetchPlatformContactMessages(),
    ]);
    if (!mounted) return;
    final schools = results[0];
    final signups = results[1];
    final messages = results[2];
    setState(() {
      _schoolCount = schools.length;
      _pendingSignups = signups.where((r) => '${r['status'] ?? 'new'}'.toLowerCase() == 'new').length;
      _unreadMessages = messages.where((m) => m['read_at'] == null).length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          DashAccountHeader(
            user: widget.user,
            subtitle: 'BeeSoft Hive · every school on e10',
            onLogout: widget.onLogout,
          ),
          const SyncBar(),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text('Jump in', style: AppText.display(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  NavListRow(
                    title: 'Schools',
                    subtitle: '$_schoolCount on the platform',
                    icon: Icons.apartment_rounded,
                    tint: const Color(0xFFE0F2FE),
                    iconColor: AppColors.blue,
                    onTap: () => widget.onNav(AppScreen.platformSchools),
                  ),
                  const SizedBox(height: 8),
                  NavListRow(
                    title: 'Signup requests',
                    subtitle: _pendingSignups == 0 ? 'None waiting' : '$_pendingSignups waiting for review',
                    icon: Icons.playlist_add_check_rounded,
                    tint: const Color(0xFFFFF7ED),
                    iconColor: AppColors.orange,
                    onTap: () => widget.onNav(AppScreen.platformSignupRequests),
                  ),
                  const SizedBox(height: 8),
                  NavListRow(
                    title: 'Contact messages',
                    subtitle: _unreadMessages == 0 ? 'All caught up' : '$_unreadMessages unread',
                    icon: Icons.mail_outline_rounded,
                    tint: const Color(0xFFECFDF5),
                    iconColor: AppColors.emerald,
                    onTap: () => widget.onNav(AppScreen.platformContactMessages),
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
