import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key, required this.onBack, required this.onLogout});

  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  Role? _filter;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final items = store.roleAccounts.where((a) => _filter == null || a.role == _filter).toList();
    return Column(
      children: [
        TopBar(
          title: 'Roles & permissions',
          subtitle: 'Only school admin can assign roles and permissions',
          onBack: widget.onBack,
          onLogout: widget.onLogout,
          onAdd: () => _edit(context, store),
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip(
                      label: 'All',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final role in Role.values)
                      _Chip(
                        label: role.label,
                        selected: _filter == role,
                        onTap: () => setState(() => _filter = role),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_filter == null)
                for (final role in Role.values) ...[
                  _RoleHeader(role: role, count: store.roleAccounts.where((a) => a.role == role).length),
                  const SizedBox(height: 8),
                  for (final person in store.roleAccounts.where((a) => a.role == role)) ...[
                    _PersonCard(
                      person: person,
                      onView: () => _edit(context, store, existing: person, viewOnly: true),
                      onEdit: () => _edit(context, store, existing: person),
                      onDelete: () async {
                        if (!await confirmDelete(context, person.name)) return;
                        final ok = await store.deleteRoleAccount(person.id);
                        if (context.mounted) {
                          showSnack(context, ok ? '${person.name} removed' : (store.syncError ?? 'Could not delete'));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                ]
              else ...[
                _RoleHeader(role: _filter!, count: items.length),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No ${_filter!.label} yet. Tap + to add one.',
                      style: AppText.body(color: AppColors.slate500),
                    ),
                  )
                else
                  for (final person in items) ...[
                    _PersonCard(
                      person: person,
                      onView: () => _edit(context, store, existing: person, viewOnly: true),
                      onEdit: () => _edit(context, store, existing: person),
                      onDelete: () async {
                        if (!await confirmDelete(context, person.name)) return;
                        final ok = await store.deleteRoleAccount(person.id);
                        if (context.mounted) {
                          showSnack(context, ok ? '${person.name} removed' : (store.syncError ?? 'Could not delete'));
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _edit(
    BuildContext context,
    SchoolStore store, {
    RoleAccount? existing,
    bool viewOnly = false,
  }) {
    final name = TextEditingController(text: existing?.name ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    var role = existing?.role ?? _filter ?? Role.schoolAdmin;

    showAdminForm(
      context: context,
      title: viewOnly
          ? existing!.name
          : existing == null
              ? 'Add ${role.label}'
              : 'Edit ${existing.name}',
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          return Column(
            children: [
              AdminDropdown(
                label: 'Role',
                value: role.label,
                items: Role.values.map((r) => r.label).toList(),
                onChanged: (v) => setLocal(() {
                  role = Role.values.firstWhere((r) => r.label == v);
                }),
              ),
              AdminField(label: 'Full name', controller: name),
              AdminField(label: 'Title / assignment', controller: title),
              AdminField(label: 'Email', controller: email, keyboard: TextInputType.emailAddress),
              AdminField(label: 'Phone', controller: phone, keyboard: TextInputType.phone),
              if (!viewOnly)
                HoneyButton(
                  label: existing == null ? 'Create account' : 'Update account',
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    final ok = await store.upsertRoleAccount(
                      RoleAccount(
                        id: existing?.id ?? '',
                        name: name.text.trim(),
                        role: role,
                        email: email.text.trim(),
                        phone: phone.text.trim(),
                        title: title.text.trim(),
                      ),
                      isNew: existing == null,
                    );
                    if (!ctx.mounted) return;
                    if (!ok) {
                      showSnack(ctx, store.syncError ?? 'Could not save');
                      return;
                    }
                    closeRoute(ctx);
                    showSnack(context, existing == null ? '${role.label} created' : 'Updated');
                  },
                )
              else
                HoneyButton(
                  label: 'Edit',
                  onPressed: () {
                    closeRoute(ctx);
                    _edit(context, store, existing: existing);
                  },
                ),
            ],
          );
        },
      ),
    ).whenComplete(() => disposeAfterClose([name, email, phone, title]));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.honey : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.honey : AppColors.slate200),
          ),
          child: Text(
            label,
            style: AppText.body(
              size: 11,
              weight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.slate500,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  const _RoleHeader({required this.role, required this.count});
  final Role role;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(role.icon, size: AppIconSize.page, color: AppColors.icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(role.label, style: AppText.body(weight: FontWeight.w800)),
        ),
        Text('$count', style: AppText.body(size: 12, color: AppColors.slate400)),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final RoleAccount person;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          InitialsAvatar(name: person.name, tone: Tone.sky),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: AppText.body(weight: FontWeight.w800)),
                Text(person.title, style: AppText.body(size: 11, color: AppColors.slate500)),
                Text(person.email, style: AppText.body(size: 10, color: AppColors.slate400)),
              ],
            ),
          ),
          ActionMenuButton(
            title: person.name,
            actions: [
              SheetAction(label: 'View', icon: Icons.visibility_rounded, onTap: onView),
              SheetAction(label: 'Edit', icon: Icons.edit_rounded, onTap: onEdit),
              SheetAction(label: 'Delete', icon: Icons.delete_outline_rounded, destructive: true, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}
