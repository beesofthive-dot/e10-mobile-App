import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

/// Everything about the current school, straight from GET /school — visible
/// to every signed-in role (teacher, parent, admin, staff), editable only
/// for admin roles via PUT /school/profile.
class SchoolProfileScreen extends StatefulWidget {
  const SchoolProfileScreen({super.key, required this.user, this.onBack, required this.onLogout});

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<SchoolProfileScreen> createState() => _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends State<SchoolProfileScreen> {
  bool _editing = false;
  bool _saving = false;

  late final TextEditingController _name;
  late final TextEditingController _motto;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _phoneSecondary;
  late final TextEditingController _email;

  bool get _canEdit => widget.user.role.isAdminPortal;

  @override
  void initState() {
    super.initState();
    final store = SchoolScope.read(context);
    _name = TextEditingController(text: store.brandedSchoolName);
    _motto = TextEditingController(text: store.schoolMotto ?? '');
    _address = TextEditingController(text: store.schoolAddress ?? '');
    _phone = TextEditingController(text: store.schoolPhone ?? '');
    _phoneSecondary = TextEditingController(text: store.schoolPhoneSecondary ?? '');
    _email = TextEditingController(text: store.schoolEmail ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _motto.dispose();
    _address.dispose();
    _phone.dispose();
    _phoneSecondary.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = SchoolScope.of(context);
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Enter the school name.');
      return;
    }
    setState(() => _saving = true);
    final ok = await store.updateSchoolProfile(
      name: _name.text,
      code: store.schoolCode ?? '',
      currencyCode: store.schoolCurrencyCode ?? '',
      timezone: store.schoolTimezone ?? '',
      motto: _motto.text,
      address: _address.text,
      phone: _phone.text,
      phoneSecondary: _phoneSecondary.text,
      email: _email.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
    showSnack(context, ok ? 'School profile updated.' : (store.syncError ?? 'Could not update the school profile.'));
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'About the school',
            subtitle: store.brandedSchoolName,
            onBack: widget.onBack,
            trailing: _canEdit && !_editing
                ? IconButton(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  )
                : null,
          ),
          Expanded(
            child: ListView(
              padding: AppLayout.page(context),
              children: [
                Center(
                  child: Column(
                    children: [
                      const SchoolMark(size: 72, light: true),
                      const SizedBox(height: 10),
                      Text(store.brandedSchoolName, style: AppText.display(size: 18, weight: FontWeight.w700)),
                      if ((store.schoolCode ?? '').isNotEmpty)
                        Text(store.schoolCode!, style: AppText.body(size: 13, color: AppColors.slate500)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_editing) ..._editForm() else ..._viewInfo(store),
                if (!_editing) ...[
                  const SizedBox(height: 14),
                  _reportSplitCard(store),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _editForm() {
    return [
      AdminField(label: 'School name', controller: _name),
      AdminField(label: 'Motto', controller: _motto),
      AdminField(label: 'Address', controller: _address),
      AdminField(label: 'Phone', controller: _phone, keyboard: TextInputType.phone),
      AdminField(label: 'Secondary phone', controller: _phoneSecondary, keyboard: TextInputType.phone),
      AdminField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => setState(() => _editing = false),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HoneyButton(
              label: _saving ? 'Saving...' : 'Save',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    ];
  }

  /// The class report's split: class work (from subject teachers' marked
  /// homework, assignments, exercises and class tests) + exam = 100.
  /// Set by the admin; the school server applies it to every class report.
  Widget _reportSplitCard(SchoolStore store) {
    final classWork = store.classScoreWeight;
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.pie_chart_outline_rounded, color: AppColors.iconPalette[4]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report marks', style: AppText.body(size: 14, weight: FontWeight.w700)),
                Text('Class work $classWork + Exam ${100 - classWork} = 100', style: AppText.body(size: 13, color: AppColors.slate600)),
              ],
            ),
          ),
          if (_canEdit)
            TextButton(onPressed: () => _editReportSplit(store), child: const Text('Change')),
        ],
      ),
    );
  }

  Future<void> _editReportSplit(SchoolStore store) async {
    final classWork = TextEditingController(text: '${store.classScoreWeight}');
    await showAppSheet<void>(
      context: context,
      title: 'Report marks',
      subtitle: 'How many of the 100 marks come from class work. The exam gets the rest.',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminField(label: 'Class work out of (e.g. 30)', controller: classWork, keyboard: TextInputType.number),
          HoneyButton(
            label: 'Save',
            onPressed: () async {
              final value = int.tryParse(classWork.text.trim());
              if (value == null) {
                showSnack(ctx, 'Enter a number from 0 to 100.');
                return;
              }
              final error = await store.saveReportSettings(value);
              if (!ctx.mounted) return;
              if (error.isNotEmpty) {
                showSnack(ctx, error);
                return;
              }
              closeRoute(ctx);
              showSnack(ctx, 'Saved: class work $value + exam ${100 - value}.');
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
    disposeAfterClose([classWork]);
  }

  List<Widget> _viewInfo(SchoolStore store) {
    final rows = <(String, String)>[
      if ((store.schoolMotto ?? '').isNotEmpty) ('Motto', store.schoolMotto!),
      if ((store.schoolAddress ?? '').isNotEmpty) ('Address', store.schoolAddress!),
      if ((store.schoolPhone ?? '').isNotEmpty) ('Phone', store.schoolPhone!),
      if ((store.schoolPhoneSecondary ?? '').isNotEmpty) ('Secondary phone', store.schoolPhoneSecondary!),
      if ((store.schoolEmail ?? '').isNotEmpty) ('Email', store.schoolEmail!),
      if ((store.schoolCurrencyCode ?? '').isNotEmpty) ('Currency', store.schoolCurrencyCode!),
      if ((store.schoolTimezone ?? '').isNotEmpty) ('Timezone', store.schoolTimezone!),
      if ((store.schoolType ?? '').isNotEmpty) ('School type', store.schoolType!),
      if ((store.schoolStatus ?? '').isNotEmpty) ('Status', store.schoolStatus!),
    ];
    if (rows.isEmpty) {
      return [
        WhiteCard(
          padding: const EdgeInsets.all(14),
          child: Text('No further school details yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
        ),
      ];
    }
    return [
      WhiteCard(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(rows[i].$1, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.slate500)),
                    ),
                    Expanded(child: Text(rows[i].$2, style: AppText.body(size: 14))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
