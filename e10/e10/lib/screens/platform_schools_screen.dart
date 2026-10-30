import 'package:flutter/material.dart';

import '../auth.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

/// Every school registered on e10 — GET /platform/schools — with a way to
/// jump into a school's own admin portal (POST /platform/schools/{id}/enter)
/// and a manual "add school" form (POST /platform/schools) for schools the
/// platform team sets up directly rather than through the public signup form.
class PlatformSchoolsScreen extends StatefulWidget {
  const PlatformSchoolsScreen({
    super.key,
    this.onBack,
    required this.onLogout,
    required this.onEnterSchool,
  });

  final VoidCallback? onBack;
  final VoidCallback onLogout;
  final Future<void> Function(AppUser user) onEnterSchool;

  @override
  State<PlatformSchoolsScreen> createState() => _PlatformSchoolsScreenState();
}

class _PlatformSchoolsScreenState extends State<PlatformSchoolsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _schools = const [];
  String? _enteringId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final store = SchoolScope.of(context);
    final schools = await store.fetchPlatformSchools();
    if (!mounted) return;
    setState(() {
      _schools = schools;
      _loading = false;
    });
  }

  Future<void> _enter(Map<String, dynamic> school) async {
    final id = '${school['id'] ?? ''}';
    if (id.isEmpty) return;
    setState(() => _enteringId = id);
    final result = await Auth.platformEnterSchool(id);
    if (!mounted) return;
    setState(() => _enteringId = null);
    if (!result.ok) {
      showSnack(context, result.error ?? 'Could not enter that school.');
      return;
    }
    await widget.onEnterSchool(result.user!);
  }

  void _openCreateForm() {
    final name = TextEditingController();
    final code = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    var saving = false;

    showAdminForm(
      context: context,
      title: 'Add a school',
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          return Column(
            children: [
              AdminField(label: 'School name', controller: name),
              AdminField(label: 'Short code', controller: code),
              AdminField(label: 'Email', controller: email, keyboard: TextInputType.emailAddress),
              AdminField(label: 'Phone', controller: phone, keyboard: TextInputType.phone),
              AdminField(label: 'Address', controller: address),
              const SizedBox(height: 8),
              HoneyButton(
                label: saving ? 'Creating...' : 'Create school',
                loading: saving,
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty) return;
                        setLocal(() => saving = true);
                        final store = SchoolScope.of(context);
                        final error = await store.createPlatformSchool(
                          name: name.text,
                          code: code.text,
                          email: email.text,
                          phone: phone.text,
                          address: address.text,
                        );
                        if (!ctx.mounted) return;
                        if (error.isNotEmpty) {
                          setLocal(() => saving = false);
                          showSnack(ctx, error);
                          return;
                        }
                        closeRoute(ctx);
                        if (!mounted) return;
                        showSnack(context, 'School created.');
                        _load();
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Schools',
            subtitle: '${_schools.length} on the platform',
            onBack: widget.onBack,
            trailing: IconButton(
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  if (!_loading && _schools.isEmpty)
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('No schools yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                    )
                  else
                    for (final school in _schools) _SchoolRow(
                      school: school,
                      entering: _enteringId == '${school['id'] ?? ''}',
                      onEnter: () => _enter(school),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolRow extends StatelessWidget {
  const _SchoolRow({required this.school, required this.entering, required this.onEnter});

  final Map<String, dynamic> school;
  final bool entering;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final name = '${school['name'] ?? 'Untitled school'}';
    final code = '${school['code'] ?? ''}';
    final status = '${school['status'] ?? 'active'}';
    final studentCount = school['students_count'] ?? school['student_count'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WhiteCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            InitialsAvatar(name: name, size: AvatarSize.md),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.body(size: 15, weight: FontWeight.w700)),
                  Text(
                    [
                      if (code.isNotEmpty) code,
                      if (studentCount != null) '$studentCount students',
                    ].join(' · '),
                    style: AppText.body(size: 12, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            StatusDot(
              label: status[0].toUpperCase() + status.substring(1),
              color: status.toLowerCase() == 'active' ? AppColors.emerald : AppColors.slate400,
            ),
            const SizedBox(width: 8),
            entering
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: onEnter, child: const Text('Enter')),
          ],
        ),
      ),
    );
  }
}
