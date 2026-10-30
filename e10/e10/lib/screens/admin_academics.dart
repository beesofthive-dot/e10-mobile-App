import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

class AdminAcademicsScreen extends StatelessWidget {
  const AdminAcademicsScreen({
    super.key,
    required this.onBack,
    required this.onLogout,
    this.viewOnly = false,
    this.studentName,
  });

  final VoidCallback onBack;
  final VoidCallback onLogout;
  final bool viewOnly;
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final marks = studentName == null
        ? store.academics
        : store.academics.where((m) => m.student == studentName).toList();
    return Column(
      children: [
        TopBar(
          title: studentName != null ? 'My Results' : 'Academics',
          subtitle: viewOnly ? '${marks.length} recorded marks · view only' : '${marks.length} recorded marks',
          onBack: onBack,
          onLogout: onLogout,
          onAdd: viewOnly ? null : () => _edit(context, store),
        ),
        Expanded(
          child: marks.isEmpty
              ? ListView(
                  padding: AppLayout.page(context),
                  children: [
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('No marks recorded yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                    ),
                  ],
                )
              : GridView.builder(
                  padding: AppLayout.page(context),
                  itemCount: marks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 136,
                  ),
                  itemBuilder: (context, i) {
                    final mark = marks[i];
                    return GestureDetector(
                      onTap: viewOnly ? null : () => _edit(context, store, mark),
                      child: WhiteCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  mark.grade,
                                  style: AppText.display(size: 18, weight: FontWeight.w700, color: AppColors.icon),
                                ),
                                const Spacer(),
                                if (!viewOnly)
                                  ActionMenuButton(
                                    title: mark.subject,
                                    actions: [
                                      SheetAction(
                                        label: 'Edit',
                                        icon: Icons.edit_rounded,
                                        onTap: () => _edit(context, store, mark),
                                      ),
                                      SheetAction(
                                        label: 'Delete',
                                        icon: Icons.delete_outline_rounded,
                                        destructive: true,
                                        onTap: () async {
                                          if (await confirmDelete(context, mark.subject)) {
                                            store.deleteMark(mark.id);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              mark.student,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(size: 13, weight: FontWeight.w700),
                            ),
                            Text(
                              '${mark.subject} · ${mark.score}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(size: 11, color: AppColors.slate500),
                            ),
                            if (mark.remark.trim().isNotEmpty)
                              Text(
                                mark.remark.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.icon),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _edit(BuildContext context, SchoolStore store, [AcademicMark? existing]) {
    final subject = TextEditingController(text: existing?.subject ?? 'Mathematics');
    final term = TextEditingController(text: existing?.term ?? 'Term 1');
    final score = TextEditingController(text: existing?.score.toString() ?? '80');
    final grade = TextEditingController(text: existing?.grade ?? 'B+');
    final remark = TextEditingController(text: existing?.remark ?? '');
    var student = existing?.student ?? store.studentNames.firstOrNull ?? '';
    var klass = existing?.klass ?? store.classNames.firstOrNull ?? '';

    showAdminForm(
      context: context,
      title: existing == null ? 'Record mark' : 'Update mark',
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          return Column(
            children: [
              AdminDropdown(
                label: 'Student',
                value: student,
                items: store.studentNames,
                onChanged: (v) => setLocal(() => student = v),
              ),
              AdminDropdown(
                label: 'Class',
                value: klass,
                items: store.classNames,
                onChanged: (v) => setLocal(() => klass = v),
              ),
              AdminField(label: 'Subject', controller: subject),
              AdminField(label: 'Term', controller: term),
              AdminField(label: 'Score', controller: score, keyboard: TextInputType.number),
              AdminField(label: 'Grade', controller: grade),
              AdminField(label: 'Remark', controller: remark),
              HoneyButton(
                label: existing == null ? 'Save mark' : 'Update',
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await WidgetsBinding.instance.endOfFrame;
                  if (!ctx.mounted) return;
                  store.upsertMark(
                    AcademicMark(
                      id: existing?.id ?? '',
                      student: student,
                      klass: klass,
                      subject: subject.text.trim(),
                      term: term.text.trim(),
                      score: int.tryParse(score.text) ?? 0,
                      grade: grade.text.trim(),
                      remark: remark.text.trim(),
                    ),
                    isNew: existing == null,
                  );
                  closeRoute(ctx);
                  if (context.mounted) showSnack(context, 'Academic record saved');
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(() => disposeAfterClose([subject, term, score, grade, remark]));
  }
}
