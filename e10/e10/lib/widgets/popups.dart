import 'package:flutter/material.dart';

import '../theme.dart';

/// Closes the pop-up or page that [context] belongs to, and only that one.
/// A second call — a double-tapped Save/Update, or two saves finishing at
/// the same moment — does nothing, where `Navigator.pop` would close the
/// screen underneath instead. Popping the app's last screen crashes Flutter
/// ("_history.isNotEmpty is not true").
void closeRoute<T extends Object?>(BuildContext context, [T? result]) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent || route.isFirst) return;
  Navigator.of(context).pop<T>(result);
}

/// Disposes a pop-up form's text controllers (or other notifiers) once the
/// form has finished closing. `showDialog`/`showAppSheet` return as soon as
/// the form starts to close, but it stays on screen for its ~300 ms close
/// animation; disposing right away made its text fields redraw with dead
/// controllers ("A TextEditingController was used after being disposed"),
/// which then cascaded into "Duplicate GlobalKeys" and a red error screen.
void disposeAfterClose(Iterable<ChangeNotifier> notifiers) {
  final list = List<ChangeNotifier>.of(notifiers);
  Future<void>.delayed(const Duration(milliseconds: 450), () {
    for (final n in list) {
      n.dispose();
    }
  });
}

class SheetAction {
  const SheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  /// Unread-style count shown as a small pill at the end of the row.
  final int badge;
}

/// Widest any form/detail pop-up gets, so dialogs stay a readable card on
/// tablets and desktop instead of stretching edge to edge.
const double kAppModalMaxWidth = 560;

/// Shared title row for every pop-up: display-font title on the left and a
/// small bordered close button on the right.
class AppModalHeader extends StatelessWidget {
  const AppModalHeader({super.key, required this.title, this.subtitle, this.onClose});

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(size: 20, weight: FontWeight.w700, color: AppColors.slate800)),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.body(size: 12, color: AppColors.slate500)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Close',
            child: Material(
              color: AppColors.slate50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onClose ?? () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.slate500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form field label in the pop-up style ("Title *").
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        required ? '$text *' : text,
        style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.slate600),
      ),
    );
  }
}

/// Input decoration shared by every pop-up form field.
InputDecoration appFieldDecoration(BuildContext context, {String? hint}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.body(size: 13.5, color: AppColors.slate400),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppSurface.brand(context)),
  );
}

/// Tap-to-pick field in the pop-up style; opens [showAppPicker] under itself.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholder = false,
    this.enabled = true,
    this.required = false,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  /// Renders [value] as hint text (e.g. "Select…").
  final bool placeholder;
  final bool enabled;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final active = enabled && items.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFieldLabel(label, required: required),
          Builder(
            builder: (fieldContext) => Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: !active
                    ? null
                    : () async {
                        final picked = await showAppPicker(
                          context: fieldContext,
                          title: label,
                          items: items,
                          selected: value,
                        );
                        if (picked != null) onChanged(picked);
                      },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 13.5,
                            color: placeholder || !active ? AppColors.slate400 : AppColors.slate800,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.slate400),
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

/// Primary action button at the foot of every pop-up form. Shows a faded
/// brand colour while [onPressed] is null (form not ready yet).
class AppModalButton extends StatelessWidget {
  const AppModalButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = AppSurface.brand(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: brand.withValues(alpha: 0.42),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        textStyle: AppText.body(size: 13.5, weight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

RelativeRect _menuPosition(BuildContext context, {double gap = 4}) {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) {
    return const RelativeRect.fromLTRB(16, 80, 16, 16);
  }
  final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
  final size = box.size;
  return RelativeRect.fromRect(
    Rect.fromLTWH(origin.dx, origin.dy + size.height + gap, size.width, size.height),
    Offset.zero & overlay.size,
  );
}

/// Compact action menu next to the tapped widget. No dim overlay.
Future<void> showActionSheet({
  required BuildContext context,
  String? title,
  required List<SheetAction> actions,
  bool showCancel = false,
}) async {
  final chosen = await showMenu<SheetAction>(
    context: context,
    position: _menuPosition(context),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 10,
    shadowColor: AppColors.navy.withValues(alpha: 0.16),
    constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    ),
    items: [
      if (title != null)
        PopupMenuItem<SheetAction>(
          enabled: false,
          height: 32,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(title, style: AppText.body(size: 11, weight: FontWeight.w500, color: AppColors.slate400)),
        ),
      for (final action in actions)
        PopupMenuItem<SheetAction>(
          value: action,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                action.icon,
                size: 16,
                color: action.destructive ? AppColors.rose : AppSurface.brand(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  style: AppText.body(
                    size: 13,
                    color: action.destructive ? AppColors.rose : AppColors.slate800,
                  ),
                ),
              ),
              if (action.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppSurface.brand(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    action.badge > 99 ? '99+' : '${action.badge}',
                    style: AppText.body(size: 11, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
  if (chosen != null) chosen.onTap();
}

/// Compact dropdown list next to the field. No dim overlay.
Future<String?> showAppPicker({
  required BuildContext context,
  required String title,
  required List<String> items,
  required String selected,
  bool searchable = false,
}) {
  // Drop-downs line up with the field they belong to, like a native select.
  // (Only when anchored to a field-sized widget, not a whole screen.)
  final anchor = (context.findRenderObject() as RenderBox?)?.size;
  final width = anchor != null && anchor.height <= 120 ? anchor.width.clamp(160.0, kAppModalMaxWidth) : 240.0;
  return showMenu<String>(
    context: context,
    position: _menuPosition(context),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 10,
    shadowColor: AppColors.navy.withValues(alpha: 0.16),
    constraints: BoxConstraints(minWidth: width, maxWidth: width, maxHeight: 280),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    ),
    items: [
      for (final item in items)
        PopupMenuItem<String>(
          value: item,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item,
                  style: AppText.body(
                    size: 13,
                    weight: item == selected ? FontWeight.w500 : FontWeight.w400,
                    color: item == selected ? AppSurface.brand(context) : AppColors.slate800,
                  ),
                ),
              ),
              if (item == selected)
                Icon(Icons.check_rounded, size: 16, color: AppSurface.brand(context)),
            ],
          ),
        ),
    ],
  );
}

/// Compact confirmation dialog. Uses a light backdrop only.
Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (ctx) {
      final width = MediaQuery.sizeOf(ctx).width;
      return Dialog(
        insetPadding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.display(size: 16, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(message, style: AppText.body(size: 13, color: AppColors.slate500)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: cancelLabel,
                        filled: false,
                        onTap: () => closeRoute(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SheetButton(
                        label: confirmLabel,
                        filled: true,
                        destructive: destructive,
                        onTap: () => closeRoute(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Centered pop-up card shared by every form, picker list and detail view:
/// white, rounded, light backdrop, capped at [kAppModalMaxWidth].
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = kAppModalMaxWidth,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final keyboard = MediaQuery.viewInsetsOf(ctx).bottom;
      final theme = Theme.of(ctx);
      // Pop-ups are always the light card (as in the reference design); in
      // dark mode give their contents the light variant of the school's own
      // theme so text and controls stay legible on white.
      final light = theme.brightness == Brightness.dark
          ? AppTheme.build(
              brightness: Brightness.light,
              seed: theme.colorScheme.primary,
              accent: theme.colorScheme.secondary,
            )
          : theme;
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width < maxWidth ? size.width : maxWidth,
            maxHeight: (size.height - keyboard).clamp(200.0, size.height) * 0.92,
          ),
          child: Theme(data: light, child: Builder(builder: builder)),
        ),
      );
    },
  );
}

/// Content-sized form/detail overlay. Not full screen. With [title] it gets
/// the standard pop-up header (title + close button).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool padded = true,
  String? title,
  String? subtitle,
}) {
  return showAppDialog<T>(
    context: context,
    builder: (ctx) {
      final keyboard = MediaQuery.viewInsetsOf(ctx).bottom;
      return SingleChildScrollView(
        padding: !padded
            ? EdgeInsets.only(bottom: keyboard)
            : title != null
                ? EdgeInsets.fromLTRB(24, 20, 24, keyboard + 24)
                : EdgeInsets.fromLTRB(16, 16, 16, keyboard + 12),
        child: title == null
            ? builder(ctx)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppModalHeader(title: title, subtitle: subtitle),
                  builder(ctx),
                ],
              ),
      );
    },
  );
}

class ActionMenuButton extends StatelessWidget {
  const ActionMenuButton({super.key, required this.actions, this.title = 'Actions'});

  final List<SheetAction> actions;
  final String title;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: title,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppSurface.brand(context),
        padding: const EdgeInsets.all(4),
        minimumSize: const Size(28, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => showActionSheet(context: context, actions: actions),
      icon: Icon(Icons.more_horiz_rounded, size: 14, color: AppSurface.brand(context)),
    );
  }
}

class AppSelect extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = items.isEmpty ? const ['Unassigned'] : items;
    final selected = options.contains(value) ? value : options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.formLabel),
          const SizedBox(height: 4),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () async {
                final picked = await showAppPicker(
                  context: context,
                  title: label,
                  items: options,
                  selected: selected,
                  searchable: options.length > 8,
                );
                if (picked != null) onChanged(picked);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(selected, style: AppText.body(size: 13, color: AppColors.slate800)),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppSurface.brand(context)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.filled = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final bg = !filled
        ? AppColors.slate100
        : destructive
            ? AppColors.rose
            : AppSurface.brand(context);
    final fg = !filled ? AppColors.slate700 : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 40,
          child: Center(child: Text(label, style: AppText.body(size: 13, weight: FontWeight.w500, color: fg))),
        ),
      ),
    );
  }
}
