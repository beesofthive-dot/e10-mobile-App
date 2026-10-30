import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/student_profile_sheet.dart';

class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({
    super.key,
    this.onBack,
    required this.onLogout,
  });

  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  NamedRecord? _open;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final open = _open;
    if (open != null) {
      final kids = store.students.where((s) => s.klass == open.name || s.classId == open.id).toList();
      return ColoredBox(
        color: AppSurface.page(context),
        child: Column(
        children: [
          AdminPageHeader(
            title: open.name,
            subtitle: '${kids.length} students',
            onBack: () => setState(() => _open = null),
          ),
          Expanded(
            child: ListView(
              padding: AppLayout.page(context),
              children: [
                if (kids.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Text('No students in this class yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                  )
                else
                  for (final s in kids)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () => showStudentProfileSheet(context, s),
                          child: WhiteCard(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                InitialsAvatar(name: s.name, size: AvatarSize.sm),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(child: Text(s.name, style: AppText.body(size: 14, weight: FontWeight.w700))),
                                          if (s.allergies.trim().isNotEmpty || s.medicalNotes.trim().isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.health_and_safety_rounded, size: 14, color: AppColors.rose),
                                          ],
                                        ],
                                      ),
                                      Text('ID ${store.studentDisplayId(s)} · ${s.attendance}% attendance', style: AppText.body(size: 12, color: AppColors.slate500)),
                                      if (store.pickupLogs.any((l) => l.studentName == s.name))
                                        Text(
                                          'Picked up · ${store.pickupLogs.firstWhere((l) => l.studentName == s.name).pickerName}',
                                          style: AppText.body(size: 12, color: AppColors.emerald),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: AppColors.slate300),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
        ),
      );
    }

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
        AdminPageHeader(
          title: 'Classes',
          subtitle: 'Your assigned classes.',
          onBack: widget.onBack,
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              if (store.classes.isEmpty)
                WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Text('No classes assigned yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                )
              else
                for (final klass in store.classes)
                  NavListRow(
                    title: klass.name,
                    subtitle: [
                      '${store.students.where((s) => s.klass == klass.name || s.classId == klass.id).length} students',
                      if (klass.detail.isNotEmpty) klass.detail,
                    ].join(' · '),
                    onTap: () => setState(() => _open = klass),
                  ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
