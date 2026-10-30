import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import 'common.dart';

class SchoolLetterhead extends StatelessWidget {
  const SchoolLetterhead({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.maybeOf(context);
    final name = store?.brandedSchoolName ?? 'School';
    final motto = store?.schoolMotto;
    return Row(
      children: [
        const SchoolMark(size: 48, light: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.toUpperCase(), style: AppText.display(size: compact ? 15 : 17, weight: FontWeight.w700)),
              if (motto != null && motto.isNotEmpty)
                Text(motto, style: AppText.body(size: 11, color: AppColors.slate500)),
              Text(
                compact ? 'Academic report' : 'Official academic report',
                style: AppText.body(size: 12, color: AppColors.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AttendanceTick extends StatelessWidget {
  const AttendanceTick({
    super.key,
    required this.present,
    required this.onChanged,
    this.enabled = true,
  });

  final bool present;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Box(
          selected: present,
          icon: Icons.check_rounded,
          color: const Color(0xFF059669),
          onTap: enabled ? () => onChanged(true) : null,
        ),
        const SizedBox(width: 6),
        _Box(
          selected: !present,
          icon: Icons.close_rounded,
          color: AppColors.rose,
          onTap: enabled ? () => onChanged(false) : null,
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.selected, required this.icon, required this.color, this.onTap});

  final bool selected;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.slate200, width: 1.5),
        ),
        child: Icon(icon, size: 18, color: selected ? Colors.white : AppColors.slate400),
      ),
    );
  }
}
