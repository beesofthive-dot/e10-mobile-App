import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.active,
    required this.role,
    required this.allowed,
    required this.onNav,
  });

  final AppScreen active;
  final Role role;
  final Set<AppScreen> allowed;
  final ValueChanged<AppScreen> onNav;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  late Set<String> _open;

  @override
  void initState() {
    super.initState();
    _open = {
      for (final g in sidebarFor(widget.role, widget.allowed))
        if (g.title != null) g.title!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final groups = sidebarFor(widget.role, widget.allowed);
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 12),
            child: Row(
              children: [
                const AppLogo(size: 28, width: 48),
                const SizedBox(width: 8),
                Text('e10', style: AppText.display(size: 16, weight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
              children: [
                for (final group in groups) ...[
                  if (group.title == null)
                    for (final item in group.items) _item(item)
                  else ...[
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (_open.contains(group.title)) {
                            _open.remove(group.title);
                          } else {
                            _open.add(group.title!);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.title!.toUpperCase(),
                                style: AppText.body(
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: AppColors.slate400,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            AppIcon(
                              _open.contains(group.title) ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_open.contains(group.title))
                      for (final item in group.items) _item(item),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(NavItem item) {
    final active = navItemActive(item.screen, widget.active, grouped: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => widget.onNav(item.screen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                AppIcon(item.icon, size: AppIconSize.sidebar),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppText.body(
                      size: 13,
                      weight: active ? FontWeight.w500 : FontWeight.w400,
                      color: active ? AppColors.slate800 : AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
