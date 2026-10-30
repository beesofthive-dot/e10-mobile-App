import 'package:flutter/material.dart';

import '../theme.dart';
import 'popups.dart';

/// "22 Sept 2026, 19:08" from an ISO timestamp; falls back to the raw text.

/// White rounded panel shared by the Announcements and Messages pages:
/// display-font title, search box and "+ New" button, then the list.
class CommsPanel extends StatelessWidget {
  const CommsPanel({
    super.key,
    required this.title,
    required this.searchHint,
    required this.onSearch,
    required this.children,
    this.onNew,
    this.searchController,
    this.below,
  });

  final String title;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final VoidCallback? onNew;
  final TextEditingController? searchController;

  /// Optional row under the header (e.g. message filters).
  final Widget? below;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final search = SizedBox(
      height: 42,
      child: TextField(
        controller: searchController,
        onChanged: onSearch,
        style: AppText.body(size: 13.5, color: AppColors.slate800),
        cursorColor: AppSurface.brand(context),
        decoration: appFieldDecoration(context, hint: searchHint).copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    );
    final newButton = onNew == null
        ? null
        : FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppSurface.brand(context),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              textStyle: AppText.body(size: 13.5, weight: FontWeight.w700),
            ),
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New'),
          );
    final heading = Text(
      title,
      style: AppText.display(size: 20, weight: FontWeight.w700, color: AppSurface.text(context)),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: AppSurface.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppSurface.line(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 560) {
                    return Row(
                      children: [
                        Expanded(child: heading),
                        SizedBox(width: 220, child: search),
                        if (newButton != null) ...[const SizedBox(width: 8), newButton],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: heading),
                          if (newButton != null) newButton,
                        ],
                      ),
                      const SizedBox(height: 12),
                      search,
                    ],
                  );
                },
              ),
              if (below != null) ...[const SizedBox(height: 10), below!],
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty/error state inside a [CommsPanel].
class CommsEmpty extends StatelessWidget {
  const CommsEmpty({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.slate300),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: AppText.body(size: 13, color: AppSurface.muted(context))),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
