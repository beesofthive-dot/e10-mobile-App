import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import 'common.dart';
import 'popups.dart';
import 'motion.dart';

class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.title, this.action, this.onAction, this.actionColor});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.display(size: 16, weight: FontWeight.w700, color: AppSurface.ink(context)))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: AppText.body(size: 13, weight: FontWeight.w600, color: AppSurface.ink(context)),
              ),
            ),
        ],
      ),
    );
  }
}

class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.value,
    required this.label,
    this.hint,
    this.hintColor,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String value;
  final String label;
  final String? hint;
  final Color? hintColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final night = AppSurface.dark(context);
    return PressScale(
      child: Material(
        color: AppSurface.card(context),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppSurface.line(context)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppSurface.brand(context).withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: night ? iconColor.withValues(alpha: 0.2) : iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppSurface.muted(context)),
                          ),
                          const SizedBox(height: 4),
                          CountUpText(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.display(size: 24, weight: FontWeight.w800, color: AppSurface.ink(context)),
                          ),
                          if (hint != null && hint!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              hint!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(size: 11.5, weight: FontWeight.w600, color: night ? AppSurface.muted(context) : (hintColor ?? AppSurface.muted(context))),
                            ),
                          ],
                        ],
                      ),
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

class ScheduleRow extends StatelessWidget {
  const ScheduleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isNow = false,
    this.action,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String time;
  final bool isNow;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brand = AppSurface.brand(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isNow ? brand.withValues(alpha: 0.1) : AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: isNow ? brand : AppSurface.line(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: brand,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$time  $title', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 15, weight: FontWeight.w700)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 13, color: AppSurface.ink(context))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: isNow
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.honey, borderRadius: BorderRadius.circular(8)),
                    child: Text('Now', style: AppText.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
                  )
                : action != null
                    ? GestureDetector(
                        onTap: onAction,
                        child: Text(action!, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
                      )
                    : Text(time, style: AppText.body(size: 13, weight: FontWeight.w700, color: AppSurface.ink(context))),
          ),
        ],
      ),
    );
  }
}

class NavListRow extends StatelessWidget {
  const NavListRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon = Icons.groups_outlined,
    this.tint = const Color(0xFFEFF6FF),
    this.iconColor = AppColors.blue,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppSurface.line(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.body(size: 15, weight: FontWeight.w700)),
                      if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: AppText.body(size: 12, color: AppSurface.ink(context))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.slate300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.ink(context))),
        ],
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.user,
    this.onLogout,
    this.showSchool = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Shows the school logo and name above [title] (Announcements/Messages).
  final bool showSchool;

  /// When both are given, the header shows the school-letter account
  /// avatar (SchoolMarkButton → the existing showAccountSheet: profile,
  /// appearance/dark-mode, logout) instead of the bell/message/more-vert
  /// icon row — one clean account entry point instead of four separate
  /// icons. Omit both to keep the previous icon row unchanged (every other
  /// call site that hasn't opted into this yet).
  final AppUser? user;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.sheet)),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: SchoolScope.maybeOf(context)?.brandGradient ?? AppGradients.header),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 6, 16, 14),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSchool) ...[
                      Row(
                        children: [
                          const SchoolMark(size: 28, light: true),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              SchoolScope.of(context).brandedSchoolName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(size: 13, weight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      title,
                      style: AppText.display(size: showSchool ? 22 : 18, weight: FontWeight.w700, color: Colors.white),
                    ),
                    if (subtitle != null) Text(subtitle!, style: AppText.body(size: 13, color: Colors.white70)),
                  ],
                ),
              ),
              if (user != null && onLogout != null)
                SchoolMarkButton(user: user!, onLogout: onLogout!, light: true)
              else ...[
                const HeaderChromeActions(),
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  trailing!,
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HoneyPills extends StatelessWidget {
  const HoneyPills({super.key, required this.items, required this.value, required this.onChanged});

  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: value == item ? AppColors.accent : AppSurface.cardSoft(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item,
                    style: AppText.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: value == item ? Colors.white : AppSurface.text(context),
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

class DashAccountHeader extends StatelessWidget {
  const DashAccountHeader({
    super.key,
    required this.user,
    required this.subtitle,
    required this.onLogout,
    this.extra,
    this.onTapSchool,
    this.onMenu,
  });

  final AppUser user;
  final String subtitle;
  final VoidCallback onLogout;
  final Widget? extra;
  final VoidCallback? onTapSchool;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.sheet)),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: SchoolScope.maybeOf(context)?.brandGradient ?? AppGradients.header),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTapSchool,
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          const SchoolMark(size: 48, light: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  SchoolScope.of(context).headerSchoolName(user.role),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.display(size: 17, weight: FontWeight.w800, color: Colors.white)
                                      .copyWith(height: 1.15),
                                ),
                                if (SchoolScope.of(context).schoolCode?.trim().isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      SchoolScope.of(context).schoolCode!.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body(size: 11, weight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  HeaderChromeActions(
                    onMore: () => showAccountSheet(context, user: user, onLogout: onLogout),
                    onMenu: onMenu,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FocusSwitcher(user: user, subtitle: subtitle),
              if (extra != null) ...[
                const SizedBox(height: 12),
                extra!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusSwitcher extends StatefulWidget {
  const _FocusSwitcher({required this.user, required this.subtitle});

  final AppUser user;
  final String subtitle;

  @override
  State<_FocusSwitcher> createState() => _FocusSwitcherState();
}

class _FocusSwitcherState extends State<_FocusSwitcher> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final user = widget.user;
    final parent = user.role == Role.parent;
    final kids = parent ? store.linkedChildren(Role.parent) : const <Student>[];
    final classes = parent
        ? const <NamedRecord>[]
        : user.role == Role.teacher
            ? store.teacherFocusClasses(user)
            : store.classes;
    final focusKid = store.focusedChild(Role.parent);
    final focusClass = store.focusedClassRecord();

    late final String title;
    late final String line;
    late final IconData avatarIcon;
    if (parent) {
      title = focusKid == null ? 'No linked child' : focusKid.name;
      line = focusKid == null
          ? 'Tap the arrow to view children'
          : [
              if (focusKid.klass.isNotEmpty) focusKid.klass,
              kids.length == 1 ? '1 child' : '${kids.length} children',
            ].join(' · ');
      avatarIcon = Icons.face_rounded;
    } else if (classes.isEmpty) {
      title = user.displayName;
      line = widget.subtitle.isEmpty ? user.role.label : widget.subtitle;
      avatarIcon = user.role.icon;
    } else if (user.role != Role.teacher) {
      // Admin/staff: their own name up top; the class scope moves to the line.
      title = user.displayName.trim().isEmpty ? user.role.label : user.displayName;
      line = '${focusClass?.name ?? 'All classes'} · tap to switch';
      avatarIcon = user.role.icon;
    } else {
      title = focusClass?.name ?? 'Your classes';
      line = focusClass == null
          ? (store.isClassTeacher(user) ? 'Class teacher · tap to switch' : '${user.role.label} · tap the arrow to switch')
          : (store.isClassTeacher(user) ? 'Class teacher · tap to switch' : '${user.role.label} · tap the arrow to switch');
      avatarIcon = Icons.class_rounded;
    }

    final canSwitch = parent ? kids.isNotEmpty : classes.isNotEmpty;

    return Material(
      color: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap:
            canSwitch ? () => _openMenu(parent: parent, kids: kids, classes: classes, selectedId: parent ? (focusKid?.id ?? '') : store.focusedClassId, includeAll: user.role != Role.teacher) : null,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                child: Icon(avatarIcon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 15, weight: FontWeight.w800, color: Colors.white)),
                    Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: canSwitch ? Colors.white : Colors.white54,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu({
    required bool parent,
    required List<Student> kids,
    required List<NamedRecord> classes,
    required String selectedId,
    bool includeAll = true,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final media = MediaQuery.sizeOf(context);
    final width = size.width.clamp(220.0, media.width - 24);
    var left = origin.dx;
    if (left + width > media.width - 12) left = media.width - width - 12;
    if (left < 12) left = 12;
    var top = origin.dy + size.height + 8;
    if (top + 180 > media.height) top = (origin.dy - 188).clamp(12.0, media.height - 12);

    setState(() => _open = true);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Switch profile',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, animation, _) {
        return FadeTransition(
          opacity: animation,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: width,
                child: Material(
                  color: AppColors.headerEnd,
                  elevation: 18,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    // Short screens (phone sideways): never run past the bottom edge.
                    constraints: BoxConstraints(maxHeight: (media.height - top - 12).clamp(120.0, 320.0)),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                            child: Text(
                              parent ? 'YOUR CHILDREN' : 'CLASSES',
                              style: AppText.body(size: 11, weight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.7),
                            ),
                          ),
                          if (parent)
                            for (final kid in kids)
                              _PickerRow(
                                selected: kid.id == selectedId,
                                icon: Icons.face_rounded,
                                title: kid.name,
                                subtitle: kid.klass.isEmpty ? 'Tap to view this child' : kid.klass,
                                onTap: () {
                                  closeRoute(ctx);
                                  final store = SchoolScope.of(context);
                                  store.focusChild(kid.id);
                                  store.refreshChildFees(kid.id);
                                },
                              )
                          else ...[
                            if (includeAll)
                              _PickerRow(
                                selected: selectedId.isEmpty,
                                icon: Icons.apps_rounded,
                                title: 'All classes',
                                subtitle: 'View the whole school',
                                onTap: () {
                                  closeRoute(ctx);
                                  SchoolScope.of(context).focusClass('');
                                },
                              ),
                            for (final klass in classes)
                              _PickerRow(
                                selected: klass.id == selectedId,
                                icon: Icons.class_rounded,
                                title: klass.name,
                                subtitle: klass.detail.isEmpty ? 'Tap to focus this class' : klass.detail,
                                onTap: () {
                                  closeRoute(ctx);
                                  SchoolScope.of(context).focusClass(klass.id);
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) setState(() => _open = false);
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 14, weight: FontWeight.w800, color: Colors.white)),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SquareQuickAction extends StatelessWidget {
  const SquareQuickAction({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          splashColor: color.withValues(alpha: 0.16),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppSurface.card(context),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppSurface.line(context)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.ink(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CircleQuickAction extends StatelessWidget {
  const CircleQuickAction({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.ink(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppSurface.card(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppSurface.line(context)),
        ),
        child: Column(
          children: [
            Text(value, style: AppText.display(size: 20, weight: FontWeight.w800, color: AppSurface.ink(context))),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.ink(context)),
            ),
          ],
        ),
      ),
    );
  }
}
