import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import 'admin_forms.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    this.onBack,
    required this.onLogout,
    required this.role,
    this.user,
    this.title = 'Notifications',
    this.embedded = false,
  });

  final VoidCallback? onBack;
  final VoidCallback onLogout;
  final Role role;
  final AppUser? user;
  final String title;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final unread = store.unreadNoticeCount(role);

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          if (!embedded)
            AdminPageHeader(
              title: title == 'Inbox' ? 'Notifications' : title,
              subtitle: unread == 0 ? 'All caught up' : '$unread unread',
              onBack: onBack,
              trailing: user == null ? null : SchoolMarkButton(user: user!, onLogout: onLogout, light: true),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.refreshNoticesAndAttendance(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: notificationFeed(context, role),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every notification the school API holds for this user (the website's
/// Notifications page), newest first, with "Mark all read" when any are
/// unread. Shared by [NotificationsScreen] and the Messages screen's
/// Notifications tab.
List<Widget> notificationFeed(BuildContext context, Role role) {
  final store = SchoolScope.of(context);
  final items = [...store.noticesFor(role)]..sort((a, b) => b.time.compareTo(a.time));
  final unread = items.where((n) => n.unread).length;
  return [
    if (unread > 0)
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () async {
            final error = await store.markAllNoticesRead();
            if (!context.mounted) return;
            if (error.isNotEmpty) showSnack(context, error);
          },
          child: Text('Mark all read', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.brand(context))),
        ),
      ),
    if (items.isEmpty && store.syncError != null)
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Text('Unable to load notifications.', style: AppText.body(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              store.syncError!,
              textAlign: TextAlign.center,
              style: AppText.body(size: 12, color: AppSurface.muted(context)),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => store.syncFromApi(), child: const Text('Retry')),
          ],
        ),
      )
    else if (items.isEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text('No notifications yet.', textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppSurface.muted(context))),
      ),
    for (final n in items) NotificationTile(notice: n, onTap: () => store.markNoticeRead(n.id)),
  ];
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notice, this.onTap});

  final AppNotification notice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final brand = AppSurface.brand(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: n.unread ? Color.alphaBlend(brand.withValues(alpha: 0.06), AppSurface.card(context)) : AppSurface.card(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: n.unread ? 0.14 : 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconFor(n.icon), size: 18, color: brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (n.title.trim().isNotEmpty) ...[
                        Text(n.title, style: AppText.body(size: 13, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        n.text,
                        style: AppText.body(
                          size: 13,
                          weight: n.title.trim().isEmpty ? FontWeight.w700 : FontWeight.w500,
                          color: n.title.trim().isEmpty ? null : AppSurface.ink(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(formatStamp(n.time), style: AppText.body(size: 12, color: AppSurface.muted(context))),
                    ],
                  ),
                ),
                if (n.unread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, left: 6),
                    decoration: const BoxDecoration(color: AppColors.honey, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
