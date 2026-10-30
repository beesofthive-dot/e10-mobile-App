import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';
import 'department_screen.dart';

enum AdminRecordKind { classes, teachers, departments, parents, accountants }

class AdminRecordsScreen extends StatelessWidget {
  const AdminRecordsScreen({
    super.key,
    required this.kind,
    required this.onLogout,
    this.onBack,
    this.viewOnly = true,
    this.canManageHeads = false,
  });

  /// Departments only: offer "Department heads" on each department.
  final bool canManageHeads;

  final AdminRecordKind kind;
  final VoidCallback? onBack;
  final VoidCallback onLogout;
  final bool viewOnly;

  String get _title => switch (kind) {
        AdminRecordKind.classes => 'Classes',
        AdminRecordKind.teachers => 'Staff',
        AdminRecordKind.departments => 'Departments',
        AdminRecordKind.parents => 'Parents',
        AdminRecordKind.accountants => 'Accountants',
      };

  String get _emptyMessage => switch (kind) {
        AdminRecordKind.classes => 'No classes yet.',
        AdminRecordKind.teachers => 'No staff records yet.',
        AdminRecordKind.departments => 'No departments yet.',
        AdminRecordKind.parents => 'No parent records yet.',
        AdminRecordKind.accountants => 'No accountant records yet.',
      };

  List<NamedRecord> _list(SchoolStore store) => switch (kind) {
        AdminRecordKind.classes => store.classes,
        AdminRecordKind.teachers => store.teachers,
        AdminRecordKind.departments => store.departments,
        AdminRecordKind.parents => store.parents,
        AdminRecordKind.accountants => store.accountants,
      };

  /// Departments and Parents (guardians) can run into the hundreds on a
  /// real school, so they browse better as a scannable grid of cards than
  /// as one long single-column list — Classes/Staff/Accountants keep the
  /// list layout since their rows carry more per-item detail.
  bool get _gridStyle =>
      kind == AdminRecordKind.departments || kind == AdminRecordKind.parents;

  /// Plain-language summary under each row. The record's database id is a
  /// UUID that means nothing to school staff, so it is never shown.
  String _subtitle(SchoolStore store, NamedRecord item) {
    if (kind == AdminRecordKind.classes) {
      final enrolled = store.students
          .where((s) => s.classId == item.id || s.klass == item.name)
          .length;
      final capacity = int.tryParse(item.extra.trim());
      return [
        item.link.isEmpty
            ? 'No class teacher yet'
            : 'Class teacher: ${item.link}',
        capacity != null && capacity > 0
            ? '$enrolled of $capacity students'
            : '$enrolled ${enrolled == 1 ? 'student' : 'students'}',
        if (item.detail.isNotEmpty) '${item.detail} House',
      ].join(' · ');
    }
    // Teachers show their department on its own line below.
    return [item.detail, if (kind != AdminRecordKind.teachers) item.extra]
        .where((e) => e.isNotEmpty)
        .join(' · ');
  }

  List<SheetAction> _actionsFor(
          BuildContext context, SchoolStore store, NamedRecord item) =>
      [
        SheetAction(
          label: 'View',
          icon: Icons.visibility_rounded,
          onTap: () => openAdminRecordForm(context, store, kind,
              existing: item, viewOnly: true),
        ),
        if (kind == AdminRecordKind.departments && canManageHeads)
          SheetAction(
            label: 'Department heads',
            icon: Icons.manage_accounts_rounded,
            onTap: () => showDepartmentHeadsSheet(context, departmentId: item.id, departmentName: item.name),
          ),
        if (!viewOnly) ...[
          SheetAction(
            label: 'Edit',
            icon: Icons.edit_rounded,
            onTap: () =>
                openAdminRecordForm(context, store, kind, existing: item),
          ),
          SheetAction(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            destructive: true,
            onTap: () async {
              if (!await confirmDelete(context, item.name)) return;
              final ok = await switch (kind) {
                AdminRecordKind.classes => store.deleteClass(item.id),
                AdminRecordKind.teachers => store.deleteTeacher(item.id),
                AdminRecordKind.departments => store.deleteDepartment(item.id),
                AdminRecordKind.parents => store.deleteParent(item.id),
                AdminRecordKind.accountants => store.deleteAccountant(item.id),
              };
              if (context.mounted) {
                showSnack(
                    context,
                    ok
                        ? '${item.name} deleted'
                        : (store.syncError ?? 'Could not delete'));
              }
            },
          ),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final items = _list(store);
    return Column(
      children: [
        TopBar(
          title: _title,
          subtitle: viewOnly
              ? '${items.length} records · view only'
              : '${items.length} records',
          onBack: onBack,
          onLogout: onLogout,
          onAdd:
              viewOnly ? null : () => openAdminRecordForm(context, store, kind),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: AppLayout.page(context),
                    child: WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(_emptyMessage,
                          style: AppText.body(
                              size: 13, color: AppColors.slate500)),
                    ),
                  ),
                )
              : _gridStyle
                  ? GridView.builder(
                      padding: AppLayout.page(context),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 148,
                      ),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return WhiteCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  InitialsAvatar(
                                      name: item.name, tone: Tone.sky),
                                  const Spacer(),
                                  ActionMenuButton(
                                      title: item.name,
                                      actions:
                                          _actionsFor(context, store, item)),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(weight: FontWeight.w800),
                              ),
                              Text(
                                [item.detail, item.extra]
                                    .where((e) => e.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(
                                    size: 11, color: AppColors.slate400),
                              ),
                              if (kind == AdminRecordKind.departments)
                                Text(
                                  item.link.isEmpty ? 'No head yet' : 'Head: ${item.link}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: AppColors.blue),
                                ),
                            ],
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: AppLayout.page(context),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return WhiteCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              InitialsAvatar(name: item.name, tone: Tone.sky),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: AppText.body(
                                            weight: FontWeight.w800)),
                                    Text(
                                      _subtitle(store, item),
                                      style: AppText.body(
                                          size: 11, color: AppColors.slate400),
                                    ),
                                    if (kind == AdminRecordKind.teachers &&
                                        item.extra.isNotEmpty)
                                      Text(
                                        '${item.extra} Department',
                                        style: AppText.body(
                                            size: 10,
                                            weight: FontWeight.w700,
                                            color: AppColors.blue),
                                      ),
                                    if (item.email.isNotEmpty)
                                      Text(item.email,
                                          style: AppText.body(
                                              size: 10,
                                              color: AppColors.slate400)),
                                  ],
                                ),
                              ),
                              ActionMenuButton(
                                  title: item.name,
                                  actions: _actionsFor(context, store, item)),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

String _recordSingular(AdminRecordKind kind) => switch (kind) {
      AdminRecordKind.classes => 'Class',
      AdminRecordKind.teachers => 'Teacher',
      AdminRecordKind.departments => 'Department',
      AdminRecordKind.parents => 'Parent',
      AdminRecordKind.accountants => 'Accountant',
    };

void openAdminRecordForm(
  BuildContext context,
  SchoolStore store,
  AdminRecordKind kind, {
  NamedRecord? existing,
  bool viewOnly = false,
}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final detail = TextEditingController(text: existing?.detail ?? '');
  final extra = TextEditingController(text: existing?.extra ?? '');
  final email = TextEditingController(text: existing?.email ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  var link = existing?.link ?? '';
  final singular = _recordSingular(kind);

  // The "Children" field used to be free text that was never actually sent
  // anywhere — a guardian typing a child's name here never linked them to
  // that student. This tracks real student ids (same comma-joined shape
  // `link` already carries for an existing guardian) and upsertParent now
  // calls the real attach endpoint for each one on save.
  final selectedChildren = <String>{
    for (final id in link.split(','))
      if (id.trim().isNotEmpty) id.trim(),
  };
  void syncChildrenSummary() {
    final names = [
      for (final s in store.students)
        if (selectedChildren.contains(s.id)) s.name,
    ];
    detail.text = names.join(', ');
    link = selectedChildren.join(',');
  }

  final isPerson = kind == AdminRecordKind.teachers ||
      kind == AdminRecordKind.parents ||
      kind == AdminRecordKind.accountants;

  showAdminForm(
    context: context,
    title: viewOnly
        ? existing!.name
        : existing == null
            ? 'New $singular'
            : 'Edit ${existing.name}',
    child: StatefulBuilder(
      builder: (ctx, setLocal) {
        return Column(
          children: [
            AdminField(label: 'Name', controller: name),
            if (kind == AdminRecordKind.parents)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Children', style: AppType.formLabel),
                    const SizedBox(height: 4),
                    if (store.students.isEmpty)
                      Text(
                        'No students on file yet.',
                        style:
                            AppText.body(size: 12, color: AppColors.slate500),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in store.students)
                            FilterChip(
                              label: Text(s.name),
                              selected: selectedChildren.contains(s.id),
                              onSelected: viewOnly
                                  ? null
                                  : (v) => setLocal(() {
                                        if (v) {
                                          selectedChildren.add(s.id);
                                        } else {
                                          selectedChildren.remove(s.id);
                                        }
                                        syncChildrenSummary();
                                      }),
                            ),
                        ],
                      ),
                  ],
                ),
              )
            else
              AdminField(
                label: switch (kind) {
                  AdminRecordKind.classes => 'House',
                  AdminRecordKind.teachers => 'Subject',
                  AdminRecordKind.departments => 'Faculty',
                  AdminRecordKind.parents => 'Children',
                  AdminRecordKind.accountants => 'Office',
                },
                controller: detail,
              ),
            AdminField(
              label: switch (kind) {
                AdminRecordKind.classes => 'Class size (capacity)',
                AdminRecordKind.teachers => 'Assignment',
                AdminRecordKind.departments => 'Staff size',
                AdminRecordKind.parents => 'Relation',
                AdminRecordKind.accountants => 'Role',
              },
              controller: extra,
            ),
            if (isPerson) ...[
              AdminField(
                  label: 'Email',
                  controller: email,
                  keyboard: TextInputType.emailAddress),
              AdminField(
                  label: 'Phone',
                  controller: phone,
                  keyboard: TextInputType.phone),
            ],
            if (kind == AdminRecordKind.classes)
              AdminDropdown(
                label: 'Class teacher',
                value: link.isEmpty
                    ? (store.teacherNames.firstOrNull ?? 'Unassigned')
                    : link,
                items: store.teacherNames,
                onChanged: (v) => setLocal(() => link = v),
              ),
            if (kind == AdminRecordKind.teachers)
              AdminDropdown(
                label: 'Department',
                value: link.isEmpty
                    ? (store.departmentNames.firstOrNull ?? 'Unassigned')
                    : link,
                items: store.departmentNames,
                onChanged: (v) => setLocal(() => link = v),
              ),
            if (kind == AdminRecordKind.departments && existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  link.isEmpty ? 'Head of department: none yet' : 'Head of department: $link',
                  style: AppText.body(size: 13, weight: FontWeight.w700),
                ),
              ),
            if (!viewOnly)
              HoneyButton(
                label: existing == null ? 'Create' : 'Update',
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final record = NamedRecord(
                    id: existing?.id ?? '',
                    name: name.text.trim(),
                    detail: detail.text.trim(),
                    extra: extra.text.trim(),
                    email: email.text.trim(),
                    phone: phone.text.trim(),
                    link: link,
                  );
                  final ok = await switch (kind) {
                    AdminRecordKind.classes => store.upsertClass(record),
                    AdminRecordKind.teachers => store.upsertTeacher(record),
                    AdminRecordKind.departments =>
                      store.upsertDepartment(record),
                    AdminRecordKind.parents => store.upsertParent(record),
                    AdminRecordKind.accountants =>
                      store.upsertAccountant(record),
                  };
                  if (!ctx.mounted) return;
                  if (!ok) {
                    showSnack(ctx, store.syncError ?? 'Could not save');
                    return;
                  }
                  closeRoute(ctx);
                  showSnack(
                      context,
                      existing == null
                          ? '$singular created'
                          : '$singular updated');
                },
              )
            else
              HoneyButton(
                label: 'Edit',
                onPressed: () {
                  closeRoute(ctx);
                  openAdminRecordForm(context, store, kind, existing: existing);
                },
              ),
          ],
        );
      },
    ),
  ).whenComplete(() => disposeAfterClose([name, detail, extra, email, phone]));
}
