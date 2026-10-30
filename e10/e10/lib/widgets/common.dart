import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_prefs.dart';
import '../data.dart';
import '../models.dart';
import '../plan_access.dart';
import '../school_store.dart';
import '../theme.dart';
import 'popups.dart';

/// Turns a server timestamp (`2026-09-24T14:30:00.000000Z`) into what people
/// read: "Today, 2:30 PM", "Yesterday, 9:05 AM" or "24 Sept 2026, 2:30 PM".
/// A date with no time shows just the date. Anything that isn't a timestamp
/// ("Just now", "08:00") is returned unchanged.
String formatStamp(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text == 'null') return '';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final t = parsed.toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
  final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final String dayLabel;
  if (day == today) {
    dayLabel = 'Today';
  } else if (day == today.subtract(const Duration(days: 1))) {
    dayLabel = 'Yesterday';
  } else {
    dayLabel = '${t.day} ${months[t.month - 1]} ${t.year}';
  }
  if (dateOnly) return dayLabel;
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$dayLabel, $h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

class HoneycombBg extends StatelessWidget {
  const HoneycombBg({super.key, this.opacity = 0.05});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HoneycombPainter(opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _HoneycombPainter extends CustomPainter {
  _HoneycombPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.honey.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    const w = 60.0;
    const h = 52.0;
    for (var row = 0; row < size.height / h + 2; row++) {
      for (var col = 0; col < size.width / w + 2; col++) {
        final dx = col * w + (row.isOdd ? w / 2 : 0);
        final dy = row * h * 0.75;
        canvas.drawPath(_hex(Offset(dx, dy), 16), paint);
      }
    }
  }

  Path _hex(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (math.pi / 3) * i - math.pi / 6;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HoneycombPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 999,
    this.padding,
    this.light = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: light
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

class Glossy extends StatelessWidget {
  const Glossy({
    super.key,
    required this.child,
    this.radius = 16,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 48,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's main action button. When [onPressed] is async (a save, a send)
/// the button shows a spinner and ignores further taps until it finishes,
/// so a double tap can't save twice or close the form twice.
class HoneyButton extends StatefulWidget {
  const HoneyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;

  @override
  State<HoneyButton> createState() => _HoneyButtonState();
}

class _HoneyButtonState extends State<HoneyButton> {
  bool _running = false;

  Future<void> _tap() async {
    final action = widget.onPressed;
    if (action == null || _running) return;
    final result = action();
    if (result is! Future) return;
    setState(() => _running = true);
    try {
      await result;
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loading || _running;
    final onPressed = widget.onPressed;
    final color = widget.color;
    final icon = widget.icon;
    final label = widget.label;
    final night = AppSurface.dark(context);
    final fill = night ? AppColors.night : (color ?? AppSurface.brand(context));
    return Opacity(
      opacity: onPressed == null ? 0.7 : 1,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: night ? AppSurface.line(context) : Colors.transparent),
        ),
        child: InkWell(
          onTap: loading || onPressed == null ? null : _tap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              gradient: night || color != null ? null : (SchoolScope.maybeOf(context)?.brandGradient ?? AppGradients.header),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            width: double.infinity,
            height: 44,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: night ? AppSurface.text(context) : Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: night ? AppSurface.text(context) : Colors.white, size: AppIconSize.button),
                          const SizedBox(width: 6),
                        ],
                        Text(label, style: AppType.button.copyWith(color: night ? AppSurface.text(context) : Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80, this.width, this.radius = 0});

  final double size;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final image = Image.asset(
      'assets/logo.png',
      width: w,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => _FallbackLogo(
        width: w,
        height: size,
      ),
    );
    if (radius <= 0) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: Colors.black,
        child: image,
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppGradients.honey,
        shape: BoxShape.circle,
      ),
      child: Text(
        'e10',
        style: AppText.display(
          size: height * 0.32,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = AppIconSize.page, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? AppSurface.brand(context),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = AvatarSize.md,
    this.tone = Tone.honey,
    this.soft = false,
  });

  final String name;
  final AvatarSize size;
  final Tone tone;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final dim = switch (size) {
      AvatarSize.sm => 32.0,
      AvatarSize.md => 40.0,
      AvatarSize.lg => 72.0,
    };
    final font = switch (size) {
      AvatarSize.sm => 11.0,
      AvatarSize.md => 13.0,
      AvatarSize.lg => 22.0,
    };
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();
    return Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: soft ? const Color(0xFFD1FAE5) : AppColors.navy,
        border: Border.all(color: tone.from.withValues(alpha: 0), width: 0),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppText.display(
          size: font,
          weight: FontWeight.w700,
          color: soft ? AppColors.emerald : Colors.white,
        ),
      ),
    );
  }
}

enum AvatarSize { sm, md, lg }

class SchoolMark extends StatelessWidget {
  const SchoolMark({super.key, this.size = 44, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.maybeOf(context);
    final bytes = store?.schoolLogoBytes;
    final name = store?.brandedSchoolName ?? 'School';
    final radius = BorderRadius.circular(size * 0.28);
    final initials = name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && word[0].toUpperCase() != word[0].toLowerCase())
        .where((word) => !const {'of', 'the', 'and', 'for'}.contains(word.toLowerCase()))
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    final Widget child = bytes != null
        ? Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => _initials(initials),
            ),
          )
        : _initials(initials);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: light ? AppColors.border : Colors.white24),
        boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 8, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _initials(String initials) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFD1FAE5),
      child: Text(
        initials.isEmpty ? 'S' : initials,
        style: AppText.display(size: size * 0.36, weight: FontWeight.w800, color: AppColors.emerald),
      ),
    );
  }
}

class SchoolMarkButton extends StatelessWidget {
  const SchoolMarkButton({
    super.key,
    required this.user,
    required this.onLogout,
    this.size = 44,
    this.light = false,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Account, settings and log out',
      child: GestureDetector(
        onTap: () => showAccountSheet(context, user: user, onLogout: onLogout),
        child: SchoolMark(size: size, light: light),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, required this.tone});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tone.softBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.slate700),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.stat});

  final AdminStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppSurface.line(context)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              AppIcon(iconFor(stat.icon), size: AppIconSize.card),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stat.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.number.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.formLabel.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onNotif,
    this.onLogout,
    this.onAdd,
    this.notifCount = 0,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onNotif;
  final VoidCallback? onLogout;
  final VoidCallback? onAdd;
  final int notifCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: SchoolScope.maybeOf(context)?.brandGradient ?? AppGradients.header),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 6,
          16,
          10,
        ),
        child: Row(
          children: [
            if (onBack != null) ...[
              _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack!, color: Colors.white),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(size: 18, weight: FontWeight.w700, color: Colors.white)),
                  if (subtitle != null)
                    Text(subtitle!, style: AppType.caption.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            if (onAdd != null) ...[
              Tooltip(
                message: 'Add',
                child: _RoundIcon(icon: Icons.add_rounded, onTap: onAdd!, color: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
            if (onNotif != null) BellButton(count: notifCount, onTap: onNotif!, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: AppIcon(icon, size: AppIconSize.page, color: color)),
        ),
      ),
    );
  }
}

class AppChrome extends InheritedWidget {
  const AppChrome({
    super.key,
    required this.messageCount,
    this.onMessages,
    this.onAnnouncements,
    this.notificationCount = 0,
    this.onNotifications,
    this.showComms = true,
    required super.child,
  });

  final int messageCount;
  /// Null when the school's plan leaves that module out — the menu then
  /// doesn't list it.
  final VoidCallback? onMessages;
  final VoidCallback? onAnnouncements;

  /// Unread school notifications (`/notifications`, the website's bell).
  final int notificationCount;
  final VoidCallback? onNotifications;

  /// False for roles that can't open Announcements/Messages (platform admin),
  /// so the header doesn't offer a menu that only bounces back home.
  final bool showComms;

  static AppChrome? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppChrome>();

  @override
  bool updateShouldNotify(AppChrome old) =>
      messageCount != old.messageCount ||
      notificationCount != old.notificationCount ||
      showComms != old.showComms ||
      (onMessages == null) != (old.onMessages == null) ||
      (onAnnouncements == null) != (old.onAnnouncements == null);
}

/// The header's single communication entry point everywhere in the app —
/// there is no separate bell/alert/notification icon anywhere alongside
/// this one: every role's "you have something new" signal (a posted
/// announcement or an unread message) lives behind this one icon and its
/// popup, never a second icon.
class CommsMenuButton extends StatelessWidget {
  const CommsMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChrome.maybeOf(context);
    if (chrome == null || !chrome.showComms) return const SizedBox.shrink();
    if (chrome.onMessages == null && chrome.onAnnouncements == null && chrome.onNotifications == null) {
      return const SizedBox.shrink();
    }
    final messageCount = chrome.onMessages == null ? 0 : chrome.messageCount;
    return Builder(
      builder: (anchor) => _ChromeIcon(
        icon: Icons.chat_bubble_outline_rounded,
        count: messageCount + chrome.notificationCount,
        tooltip: 'Announcements, messages & notifications',
        onTap: () => showActionSheet(
          context: anchor,
          actions: [
            if (chrome.onAnnouncements != null)
              SheetAction(
                label: 'Announcements',
                icon: Icons.campaign_outlined,
                onTap: chrome.onAnnouncements!,
              ),
            if (chrome.onMessages != null)
              SheetAction(
                label: 'Messages',
                icon: Icons.chat_bubble_outline_rounded,
                badge: chrome.messageCount,
                onTap: chrome.onMessages!,
              ),
            if (chrome.onNotifications != null)
              SheetAction(
                label: 'Notifications',
                icon: Icons.notifications_none_rounded,
                badge: chrome.notificationCount,
                onTap: chrome.onNotifications!,
              ),
          ],
        ),
      ),
    );
  }
}

class HeaderChromeActions extends StatelessWidget {
  const HeaderChromeActions({super.key, this.onMore, this.onMenu});

  final VoidCallback? onMore;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMenu != null)
          _ChromeIcon(
            icon: Icons.menu_rounded,
            onTap: onMenu,
            tooltip: 'Menu',
          ),
        const CommsMenuButton(),
        if (onMore != null)
          _ChromeIcon(
            icon: Icons.more_vert_rounded,
            onTap: onMore,
            tooltip: 'Account',
          ),
      ],
    );
  }
}

class _ChromeIcon extends StatelessWidget {
  const _ChromeIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.count = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: count > 0 ? '$tooltip · $count' : tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              if (count > 0)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.active,
    required this.role,
    required this.onNav,
  });

  final AppScreen active;
  final Role role;
  final ValueChanged<AppScreen> onNav;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final kgSession = role == Role.teacher && store.sessionIsKgTeacher;
    // Parents get four tabs: Feeding takes Timetable's place when the
    // school's plan has feeding (Timetable stays on the home screen).
    final parentFeeding = role == Role.parent && PlanAccess.allows(AppScreen.parentFeeding);
    final items = [
      for (final item in navFor(role))
        if (!(role == Role.parent && (parentFeeding ? item.screen == AppScreen.adminTimetable : item.screen == AppScreen.parentFeeding)))
        if (!(role == Role.teacher && item.screen == AppScreen.teacherAttendance && !store.sessionIsClassTeacher))
          if (kgSession && item.screen == AppScreen.homework)
            const NavItem(screen: AppScreen.teacherDailyReports, label: 'Daily report', icon: Icons.child_care_rounded)
          else
            item,
    ].where((item) => PlanAccess.allows(item.screen)).toList();
    final dark = AppSurface.dark(context);
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        child: ColoredBox(
          color: dark ? AppColors.night : AppColors.navLight,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: _NavButton(
                        item: item,
                        active: navItemActive(item.screen, active),
                        badge: item.screen == AppScreen.messages
                            ? SchoolScope.of(context).unreadMessageCountFor(role)
                            : item.screen == AppScreen.notifications
                                ? SchoolScope.of(context).unreadNoticeCount(role)
                                : 0,
                        onTap: () => onNav(item.screen),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final dark = AppSurface.dark(context);
    final idle = dark ? const Color(0xFF7B93B3) : const Color(0xFF7A93B0);
    final on = AppColors.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? (dark ? const Color(0xFF123056) : AppColors.accentSoft) : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: active && dark ? Border.all(color: AppColors.accent.withValues(alpha: 0.55)) : null,
                    boxShadow: active && dark ? AppShadows.blueGlow : const [],
                  ),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    tween: Tween(begin: active ? 0.8 : 1.0, end: active ? 1.0 : 1.0),
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Icon(item.icon, size: 20, color: active ? on : idle),
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -2,
                    right: 2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 11, weight: FontWeight.w600, color: active ? on : idle),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.text,
    this.action,
    this.onAction,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppType.section)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.accent)),
            ),
        ],
      ),
    );
  }
}

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({
    super.key,
    required this.actions,
    required this.onNav,
  });

  final List<QuickAction> actions;
  final ValueChanged<AppScreen> onNav;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final action in actions)
          if (PlanAccess.allows(action.screen))
          Expanded(
            child: GestureDetector(
              onTap: () => onNav(action.screen),
              child: Column(
                children: [
                  AppIcon(action.icon, size: AppIconSize.card),
                  const SizedBox(height: 6),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.slate600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.text,
    required this.time,
    required this.icon,
    required this.color,
    this.unread = false,
    this.showReadStatus = false,
  });

  final String text;
  final String time;
  final String icon;
  final String color;
  final bool unread;
  final bool showReadStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: unread ? AppColors.accentSoft : AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: unread ? AppColors.honey.withValues(alpha: 0.35) : AppSurface.line(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(iconFor(icon), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppText.body(
                    size: 13,
                    weight: unread ? FontWeight.w600 : FontWeight.w400,
                    color: AppColors.slate700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(formatStamp(time), style: AppType.caption),
              ],
            ),
          ),
          if (showReadStatus) ReadStatusChip(unread: unread),
        ],
      ),
    );
  }
}

class ReadStatusChip extends StatelessWidget {
  const ReadStatusChip({super.key, required this.unread, this.count});

  final bool unread;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final label = unread ? (count != null && count! > 0 ? 'Unread · $count' : 'Unread') : 'Read';
    final brand = AppSurface.brand(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: unread ? brand.withValues(alpha: 0.12) : AppColors.slate100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: unread ? brand : AppColors.border),
      ),
      child: Text(
        label,
        style: AppText.body(
          size: 10,
          weight: FontWeight.w700,
          color: unread ? brand : AppColors.slate500,
        ),
      ),
    );
  }
}

class WhiteCard extends StatelessWidget {
  const WhiteCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppSurface.line(context)),
        boxShadow: AppSurface.dark(context)
            ? const []
            : AppShadows.card,
      ),
      child: child,
    );
  }
}

/// A single stat card (icon, big number, label) — the shared building block
/// behind every attendance grid in the app (parent dashboard, the full
/// attendance screen, and the admin/teacher class roll) so Total/Present/
/// Absent/Late/Excused look like the same design everywhere, not a
/// different treatment per screen.
class AttendanceStatTile extends StatelessWidget {
  const AttendanceStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          Text('$value', style: AppText.display(size: 22, weight: FontWeight.w800, color: AppSurface.text(context))),
          const SizedBox(height: 2),
          Text(label, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.muted(context))),
        ],
      ),
    );
  }
}

/// A single stat definition for [AttendanceStatGrid].
typedef AttendanceStat = ({String label, int value, IconData icon, Color color});

/// Lays a set of [AttendanceStatTile]s out two-per-row, with an optional
/// bold "N recorded" header line above (used for the Total count instead of
/// making it just another tile).
class AttendanceStatGrid extends StatelessWidget {
  const AttendanceStatGrid({super.key, required this.stats, this.totalLabel});

  final List<AttendanceStat> stats;

  /// e.g. "42 days recorded this term" — shown above the grid when set.
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              totalLabel!,
              style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.muted(context)),
            ),
          ),
        for (var i = 0; i < stats.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < stats.length ? 12 : 0),
            child: Row(
              children: [
                Expanded(child: AttendanceStatTile(
                  label: stats[i].label,
                  value: stats[i].value,
                  icon: stats[i].icon,
                  color: stats[i].color,
                )),
                const SizedBox(width: 12),
                if (i + 1 < stats.length)
                  Expanded(child: AttendanceStatTile(
                    label: stats[i + 1].label,
                    value: stats[i + 1].value,
                    icon: stats[i + 1].icon,
                    color: stats[i + 1].color,
                  ))
                else
                  const Spacer(),
              ],
            ),
          ),
      ],
    );
  }
}

class ScreenPad extends StatelessWidget {
  const ScreenPad({
    super.key,
    required this.child,
    this.bottom,
  });

  final Widget child;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    final pad = AppLayout.page(context);
    return SingleChildScrollView(
      padding: bottom == null ? pad : pad.copyWith(bottom: bottom),
      child: child,
    );
  }
}

class NavyHeader extends StatelessWidget {
  const NavyHeader({super.key, required this.child, this.bottom = 32});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: SchoolScope.maybeOf(context)?.brandGradient ?? AppGradients.header),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 16,
          16,
          bottom,
        ),
        child: child,
      ),
    );
  }
}

class BellButton extends StatelessWidget {
  const BellButton({super.key, required this.count, required this.onTap, this.color, this.badgeColor});

  final int count;
  final VoidCallback onTap;
  final Color? color;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: count > 0 ? '$count unread' : 'Inbox',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _RoundIcon(icon: Icons.notifications_outlined, onTap: onTap, color: color),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor ?? AppColors.honey,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                constraints: const BoxConstraints(minWidth: 14),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                        style: AppText.body(size: 11, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key, required this.onTap, this.color});

  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Log out',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('portal-logout'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: AppIcon(Icons.logout_rounded, size: AppIconSize.page, color: color)),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmLogout(BuildContext context) {
  return showAppConfirm(
    context: context,
    title: 'Log out?',
    message: 'You will leave this portal and return to the login screen.',
    cancelLabel: 'Stay',
    confirmLabel: 'Log out',
  );
}

void showAccountSheet(
  BuildContext context, {
  required AppUser user,
  required VoidCallback onLogout,
}) {
  showAppSheet<void>(
    context: context,
    title: 'Account',
    builder: (sheetContext) {
      return ListenableBuilder(
        listenable: AppPrefs.of(sheetContext),
        builder: (sheetContext, _) {
          final prefs = AppPrefs.of(sheetContext);
          return SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SchoolMark(size: 72, light: true),
            const SizedBox(height: 12),
            Text(user.displayName, style: AppText.display(size: 20, weight: FontWeight.w800)),
            Text(user.role.label, style: AppText.body(size: 13, color: AppColors.slate500)),
            if ((SchoolScope.maybeOf(sheetContext)?.brandedSchoolName ?? '').isNotEmpty)
              Text(SchoolScope.of(sheetContext).brandedSchoolName, style: AppText.body(size: 13, color: AppColors.slate500)),
            if (user.email.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(user.email, style: AppText.body(size: 14, color: AppColors.slate600)),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFB91C1C)),
              title: Text('Log out', style: AppText.body(size: 15, weight: FontWeight.w700, color: const Color(0xFFB91C1C))),
              subtitle: const Text('Return to the login screen'),
              onTap: () {
                closeRoute(sheetContext);
                onLogout();
              },
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Settings', style: AppText.body(size: 15, weight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              subtitle: const Text('Same layout. One dark colour, lighter writing.'),
              value: prefs.dark,
              onChanged: (v) => prefs.setDark(v),
            ),

          ],
        ),
            ),
          );
        },
      );
    },
  );
}

class PortalHeader extends StatelessWidget {
  const PortalHeader({
    super.key,
    required this.user,
    required this.alertCount,
    required this.onAlerts,
    this.onLogout,
    this.schoolLine,
    this.showSubtitle = false,
    this.extra,
    this.caption,
    this.bottom = 32,
    this.tone = Tone.honey,
    this.light = false,
    this.stacked = false,
  });

  final AppUser user;
  final int alertCount;
  final VoidCallback onAlerts;
  final VoidCallback? onLogout;
  final String? schoolLine;
  final bool showSubtitle;
  final Widget? extra;
  final String? caption;
  final double bottom;
  final Tone tone;
  final bool light;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final onDark = !light;
    final nameColor = onDark ? Colors.white : AppColors.navy;
    final subColor = onDark ? Colors.white70 : AppColors.slate500;
    final greetColor = onDark ? AppColors.jumpD : AppColors.slate500;
    final iconColor = onDark ? Colors.white : AppColors.navy;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 0),
      child: Container(
        padding: light ? const EdgeInsets.fromLTRB(4, 8, 4, 8) : const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: light
            ? null
            : BoxDecoration(
                gradient: AppGradients.chrome,
                borderRadius: BorderRadius.circular(24),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onLogout != null)
                  SchoolMarkButton(user: user, onLogout: onLogout!, size: 44, light: light)
                else
                  SchoolMark(size: 44, light: light),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onLogout == null ? null : () => showAccountSheet(context, user: user, onLogout: onLogout!),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stacked) ...[
                          Text(timeGreeting(), style: AppText.body(size: 13, color: greetColor)),
                          Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 17, weight: FontWeight.w800, color: nameColor),
                          ),
                          if (user.email.trim().isNotEmpty)
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(size: 12, color: subColor),
                            ),
                        ] else
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${timeGreeting()}, ',
                                  style: AppText.body(size: 15, color: greetColor),
                                ),
                                TextSpan(
                                  text: user.displayName,
                                  style: AppText.body(size: 15, weight: FontWeight.w800, color: nameColor),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          caption ??
                              [
                                user.role.label,
                                if (schoolLine != null && schoolLine!.trim().isNotEmpty) schoolLine!,
                              ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: subColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                BellButton(
                  count: alertCount,
                  onTap: onAlerts,
                  color: iconColor,
                  badgeColor: light ? const Color(0xFFEF4444) : AppColors.honey,
                ),
              ],
            ),
            if (extra != null) ...[
              const SizedBox(height: 10),
              extra!,
            ],
          ],
        ),
      ),
    );
  }
}

class PeriodRow extends StatelessWidget {
  const PeriodRow({
    super.key,
    required this.period,
    this.last = false,
    this.trailing,
  });

  final Period period;
  final bool last;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: period.active ? AppColors.accentSoft : AppSurface.card(context),
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  period.time,
                  style: AppText.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: period.active ? AppColors.honeyDark : AppColors.slate500,
                  ),
                ),
                Text(
                  period.end,
                  style: AppText.body(size: 12, color: AppColors.slate300),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 2,
            height: 40,
            decoration: BoxDecoration(
              color: period.active ? AppColors.honey : AppColors.slate200,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.subject,
                  style: AppText.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: period.active ? const Color(0xFFB45309) : AppColors.slate700,
                  ),
                ),
                Text(
                  '${period.teacher} · ${period.room}',
                  style: AppText.body(size: 12, color: AppColors.slate400),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (trailing == null && period.active)
            const StatusBadge(text: 'Now', tone: Tone.honey),
        ],
      ),
    );
  }
}
