import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/popups.dart';

Future<bool> confirmDelete(BuildContext context, String name) {
  return showAppConfirm(
    context: context,
    title: 'Delete $name?',
    message: 'Are you sure you want to delete this record? This will remove it from the school directory.',
    cancelLabel: 'Cancel',
    confirmLabel: 'Delete',
  );
}

OverlayEntry? _snackEntry;
Timer? _snackTimer;

bool _looksLikeError(String message) {
  final m = message.toLowerCase();
  return const ['could not', 'cannot', "can't", 'unable', 'failed', 'error', 'invalid', 'not found', 'no ', 'choose', 'select', 'enter ', 'write ', 'required', 'denied', 'forbidden']
      .any(m.contains);
}

/// Short status or error message for the user. It is drawn in the app's
/// top-most layer near the top of the screen — above any open pop-up form
/// and clear of the keyboard, where a bottom snackbar used to hide behind
/// the form's dimmed backdrop — and long text wraps instead of being cut
/// off. Tap it to dismiss; it also goes away by itself.
void showSnack(BuildContext context, String message) {
  final text = message.trim();
  if (!context.mounted || text.isEmpty) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
    return;
  }
  _snackTimer?.cancel();
  _snackEntry?.remove();
  late final OverlayEntry entry;
  void dismiss() {
    if (!identical(_snackEntry, entry)) return;
    _snackTimer?.cancel();
    entry.remove();
    _snackEntry = null;
  }

  entry = OverlayEntry(builder: (_) => _TopMessage(message: text, error: _looksLikeError(text), onDismiss: dismiss));
  _snackEntry = entry;
  overlay.insert(entry);
  _snackTimer = Timer(Duration(seconds: (3 + text.length ~/ 40).clamp(3, 8)), dismiss);
}

class _TopMessage extends StatelessWidget {
  const _TopMessage({required this.message, required this.error, required this.onDismiss});

  final String message;
  final bool error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, (1 - t) * -12), child: child),
            ),
            child: Material(
              color: error ? const Color(0xFFB42318) : AppColors.navy,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          softWrap: true,
                          style: AppText.body(size: 13.5, weight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminField extends StatelessWidget {
  const AdminField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboard,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.formLabel),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            style: AppText.body(size: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDropdown extends StatelessWidget {
  const AdminDropdown({
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
    return AppSelect(label: label, value: value, items: items, onChanged: onChanged);
  }
}

Future<void> showAdminForm({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.display(size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      );
    },
  );
}
