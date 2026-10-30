import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import 'popups.dart';
import 'common.dart';
import 'txn_tiles.dart';

/// Read-only profile for a single student — the record's own contact,
/// medical and admission details, which the API sends on every student row
/// but previously had no screen anywhere (parent or teacher) that actually
/// displayed them.
Future<void> showStudentProfileSheet(BuildContext context, Student student) {
  // Captured from the *caller's* context, before the dialog opens — a
  // dialog route's own builder context sits outside SchoolScope's part of
  // the tree (SchoolScope wraps the app's Navigator, not the other way
  // round), so looking it up again from inside `builder:` below would
  // throw "No SchoolScope found in context".
  final displayId = SchoolScope.of(context).studentDisplayId(student);
  return showAppSheet<void>(
    context: context,
    title: 'Student profile',
    builder: (context) {
      return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: student.name, size: AvatarSize.lg),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: AppText.display(size: 18, weight: FontWeight.w800)),
                        if (student.klass.isNotEmpty || student.schoolName.isNotEmpty)
                          Text(
                            [student.klass, student.schoolName].where((s) => s.isNotEmpty).join(' · '),
                            style: AppText.body(size: 13, color: AppSurface.muted(context)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (student.allergies.trim().isNotEmpty || student.medicalNotes.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.health_and_safety_rounded, size: 16, color: AppColors.rose),
                            const SizedBox(width: 6),
                            Text('Health notice', style: AppText.body(size: 12, weight: FontWeight.w800, color: AppColors.rose)),
                          ],
                        ),
                        if (student.allergies.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Allergies: ${student.allergies.trim()}', style: AppText.body(size: 13, weight: FontWeight.w600)),
                        ],
                        if (student.medicalNotes.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Medical notes: ${student.medicalNotes.trim()}', style: AppText.body(size: 13, weight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                ),
              TxnInfoCard(
                title: 'Student record',
                rows: [
                  // Always shown, with the same "Not assigned" fallback as
                  // the admin student list/attendance screen — previously
                  // this row vanished silently whenever `studentNumber`
                  // came back empty, which looked like the Student ID
                  // feature was simply missing here instead of just unset.
                  ('Student ID', displayId),
                  if (student.dateOfBirth.trim().isNotEmpty) ('Date of birth', student.dateOfBirth.trim()),
                  if (student.gender.trim().isNotEmpty) ('Gender', student.gender.trim()),
                  if (student.admissionDate.trim().isNotEmpty) ('Admitted', student.admissionDate.trim()),
                  if (student.emergencyContactPhone.trim().isNotEmpty) ('Emergency contact', student.emergencyContactPhone.trim()),
                  ('Status', student.status.isEmpty ? 'Active' : student.status),
                ],
              ),
              if (student.guardianName.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                TxnInfoCard(
                  title: 'Guardian on file',
                  rows: [
                    ('Name', student.guardianName.trim()),
                    if (student.guardianRelationship.trim().isNotEmpty) ('Relationship', student.guardianRelationship.trim()),
                    if (student.guardianPhone.trim().isNotEmpty) ('Phone', student.guardianPhone.trim()),
                  ],
                ),
              ],
            ],
      );
    },
  );
}
