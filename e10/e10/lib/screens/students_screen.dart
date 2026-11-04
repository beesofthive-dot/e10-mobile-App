import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen(
      {super.key, this.onBack, required this.onLogout, this.viewOnly = false});

  final VoidCallback? onBack;
  final VoidCallback onLogout;
  final bool viewOnly;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _query = '';
  String _klass = 'All Classes';

  Tone _rollTone(String roll) {
    final v = roll.toLowerCase();
    if (v == 'present') return Tone.emerald;
    if (v == 'absent' || v == 'excused' || v == 'authorized_absence') {
      return Tone.rose;
    }
    if (v == 'late' || v == 'left_early') return Tone.honey;
    return Tone.slate;
  }

  String _rollLabel(String roll) {
    final v = roll.trim().isEmpty ? '—' : roll;
    return v.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final classes = ['All Classes', ...store.classNames];
    final filtered = store.students.where((s) {
      final q = _query.toLowerCase();
      final matchesName =
          s.name.toLowerCase().contains(q) || s.id.toLowerCase().contains(q);
      final matchesClass = _klass == 'All Classes' || s.klass == _klass;
      return matchesName && matchesClass;
    }).toList();

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Student Management',
            subtitle: '${filtered.length} students',
            onBack: widget.onBack,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.slate400),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.slate200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.honey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                HoneyPills(
                  items: classes,
                  value: _klass,
                  onChanged: (v) => setState(() => _klass = v),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      store.students.isEmpty
                          ? 'No students yet.'
                          : 'No students match your search or class filter.',
                      style: AppText.body(size: 13, color: AppColors.slate500),
                    ),
                  )
                else
                  for (var i = 0; i < filtered.length; i++) ...[
                    _StudentRow(
                      student: filtered[i],
                      roll: store.rollOf(filtered[i].id),
                      rollLabel: _rollLabel(store.rollOf(filtered[i].id)),
                      tone: _rollTone(store.rollOf(filtered[i].id)),
                      onView: () => openAdmitStudentForm(context, store,
                          existing: filtered[i], viewOnly: true),
                    ),
                    if (i < filtered.length - 1)
                      const Divider(height: 1, color: AppColors.slate100),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.roll,
    required this.rollLabel,
    required this.tone,
    required this.onView,
  });

  final Student student;
  final String roll;
  final String rollLabel;
  final Tone tone;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: student.name, tone: Tone.sky),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 15, weight: FontWeight.w800)),
                Text(
                  '${SchoolScope.of(context).studentDisplayId(student)} · ${student.klass}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 12, color: AppColors.slate400),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusBadge(text: rollLabel, tone: tone),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Attendance: ${student.attendance}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.body(size: 11, color: AppColors.slate400),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (student.outstanding > 0)
                Text(
                  'GHS ${student.outstanding} due',
                  style: AppText.body(
                      size: 12, weight: FontWeight.w800, color: AppColors.rose),
                )
              else
                Builder(
                  builder: (context) {
                    final finance =
                        SchoolScope.of(context).studentFinance(student.id);
                    if (finance.charges <= 0) return const SizedBox.shrink();
                    return Text(
                      'Paid GHS ${finance.paid.toStringAsFixed(0)}',
                      style: AppText.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppColors.emerald),
                    );
                  },
                ),
              GestureDetector(
                onTap: onView,
                child: Text(
                  'View →',
                  style: AppText.body(
                      size: 13, weight: FontWeight.w700, color: AppColors.blue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void openAdmitStudentForm(
  BuildContext context,
  SchoolStore store, {
  Student? existing,
  bool viewOnly = false,
}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final dateOfBirth = TextEditingController(text: existing?.dateOfBirth ?? '');
  final emergencyPhone =
      TextEditingController(text: existing?.emergencyContactPhone ?? '');
  final allergies = TextEditingController(text: existing?.allergies ?? '');
  final medicalNotes =
      TextEditingController(text: existing?.medicalNotes ?? '');
  var klass = existing?.klass ?? store.classNames.firstOrNull ?? '';
  var status = existing?.status ?? 'active';
  var boarder = existing?.boarder ?? false;
  var gender = existing?.gender ?? '';

  showAdminForm(
    context: context,
    title: viewOnly
        ? existing!.name
        : existing == null
            ? 'Admit student'
            : 'Edit ${existing.name}',
    child: StatefulBuilder(
      builder: (ctx, setLocal) {
        return Column(
          children: [
            AdminField(label: 'Full name', controller: name),
            AdminDropdown(
              label: 'Class',
              value: klass,
              items: store.classNames.isEmpty ? [klass] : store.classNames,
              onChanged: (v) => setLocal(() => klass = v),
            ),
            AdminDropdown(
              label: 'Status',
              value: const ['active', 'graduated', 'withdrawn'].contains(status)
                  ? status
                  : 'active',
              items: const ['active', 'graduated', 'withdrawn'],
              onChanged: (v) => setLocal(() => status = v),
            ),
            AdminDropdown(
              label: 'Residence',
              value: boarder ? 'Boarding' : 'Day',
              items: const ['Day', 'Boarding'],
              onChanged: (v) => setLocal(() => boarder = v == 'Boarding'),
            ),
            // Fees come from the school's bills (Finance), the same place the
            // website reads them — typing a number here never reached either.
            if (existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Fees outstanding: GHS ${existing.outstanding} · managed under Transactions (bills)',
                  style: AppText.body(size: 12.5, color: AppColors.slate600),
                ),
              ),
            AdminDropdown(
              label: 'Gender',
              value: const ['male', 'female'].contains(gender)
                  ? gender
                  : (gender.isEmpty ? 'male' : gender),
              items: const ['male', 'female'],
              onChanged: (v) => setLocal(() => gender = v),
            ),
            AdminField(
                label: 'Date of birth (YYYY-MM-DD)', controller: dateOfBirth),
            AdminField(
                label: 'Emergency contact phone',
                controller: emergencyPhone,
                keyboard: TextInputType.phone),
            AdminField(label: 'Allergies', controller: allergies),
            AdminField(label: 'Medical notes', controller: medicalNotes),
            if (existing != null &&
                (existing.guardianName.isNotEmpty ||
                    existing.admissionDate.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (existing.admissionDate.isNotEmpty)
                      Text('Admitted ${existing.admissionDate}',
                          style: AppText.body(
                              size: 12, color: AppColors.slate500)),
                    if (existing.guardianName.isNotEmpty)
                      Text(
                        'Guardian: ${existing.guardianName}'
                        '${existing.guardianRelationship.isEmpty ? '' : ' (${existing.guardianRelationship})'}'
                        '${existing.guardianPhone.isEmpty ? '' : ' · ${existing.guardianPhone}'}',
                        style:
                            AppText.body(size: 12, color: AppColors.slate500),
                      ),
                  ],
                ),
              ),
            if (!viewOnly)
              HoneyButton(
                label: existing == null ? 'Create student' : 'Update student',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final ok = await store.upsertStudent(
                    Student(
                      id: existing?.id ?? '',
                      name: name.text.trim(),
                      klass: klass,
                      avatar: existing?.avatar ?? '',
                      attendance: existing?.attendance ?? 0,
                      fees: existing?.fees ?? 0,
                      outstanding: existing?.outstanding ?? 0,
                      status: status,
                      boarder: boarder,
                      classId: existing?.classId ?? '',
                      studentNumber: existing?.studentNumber ?? '',
                      dateOfBirth: dateOfBirth.text.trim(),
                      gender: gender,
                      emergencyContactPhone: emergencyPhone.text.trim(),
                      allergies: allergies.text.trim(),
                      medicalNotes: medicalNotes.text.trim(),
                    ),
                  );
                  if (!ctx.mounted) return;
                  if (!ok) {
                    showSnack(ctx, store.syncError ?? 'Could not save student');
                    return;
                  }
                  closeRoute(ctx);
                  showSnack(
                      context,
                      existing == null
                          ? 'Student admitted'
                          : 'Student updated');
                },
              )
            else
              HoneyButton(
                label: 'Edit',
                onPressed: () {
                  closeRoute(ctx);
                  openAdmitStudentForm(context, store, existing: existing);
                },
              ),
          ],
        );
      },
    ),
  ).whenComplete(() => disposeAfterClose([name]));
}
