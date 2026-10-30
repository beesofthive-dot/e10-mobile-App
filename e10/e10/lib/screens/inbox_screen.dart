import 'package:flutter/material.dart';

import '../models.dart';
import '../plan_access.dart';
import '../theme.dart';
import '../widgets/dash_cards.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({
    super.key,
    required this.user,
    required this.onBack,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    // Without Messages in the school's plan this is just the alerts list.
    final messages = PlanAccess.hasModule('messages');
    return DefaultTabController(
      length: messages ? 2 : 1,
      child: ColoredBox(
        color: AppSurface.page(context),
        child: Column(
          children: [
            AdminPageHeader(
              title: 'Alerts',
              subtitle: messages ? 'Messages and school notices' : 'School notices',
              onBack: onBack,
            ),
            if (messages)
            TabBar(
              labelColor: AppSurface.brand(context),
              unselectedLabelColor: AppColors.slate400,
              indicatorColor: AppSurface.brand(context),
              tabs: const [
                Tab(text: 'Alerts'),
                Tab(text: 'Messages'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  NotificationsScreen(
                    user: user,
                    role: user.role,
                    onLogout: onLogout,
                    embedded: true,
                  ),
                  if (messages)
                  MessagesScreen(
                    user: user,
                    onLogout: onLogout,
                    embedded: true,
                    showNotifications: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
