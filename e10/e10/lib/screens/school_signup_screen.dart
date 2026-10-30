import 'package:flutter/material.dart';

import '../auth.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import 'admin_forms.dart';

/// Public "register your school" form — no sign-in required. Posts to
/// POST /signup-requests (confirmed live: school_name, contact_name and
/// phone are required; email, student_count and message are optional).
/// A BeeSoft Hive platform admin reviews these from the Platform portal.
class SchoolSignupScreen extends StatefulWidget {
  const SchoolSignupScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<SchoolSignupScreen> createState() => _SchoolSignupScreenState();
}

class _SchoolSignupScreenState extends State<SchoolSignupScreen> {
  final _schoolName = TextEditingController();
  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _studentCount = TextEditingController();
  final _message = TextEditingController();

  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _schoolName.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _studentCount.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await Auth.submitSignupRequest(
      schoolName: _schoolName.text,
      contactName: _contactName.text,
      phone: _phone.text,
      email: _email.text,
      studentCount: int.tryParse(_studentCount.text.trim()),
      message: _message.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok || result.info != null) {
        _submitted = true;
      } else {
        _error = result.error ?? 'Could not submit your registration.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Register your school',
            subtitle: _submitted ? null : "We'll set your school up on e10.",
            onBack: widget.onBack,
          ),
          Expanded(
            child: _submitted ? _confirmation(context) : _form(context),
          ),
        ],
      ),
    );
  }

  Widget _confirmation(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Center(child: Icon(Icons.check_circle_rounded, size: 72, color: AppColors.emerald)),
        const SizedBox(height: 20),
        Text(
          "Thanks — we've got it!",
          textAlign: TextAlign.center,
          style: AppText.display(size: 20, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          "Our team will reach out to ${_contactName.text.trim().isEmpty ? 'you' : _contactName.text.trim()} shortly to set ${_schoolName.text.trim().isEmpty ? 'your school' : _schoolName.text.trim()} up on e10.",
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, color: AppColors.slate500),
        ),
        const SizedBox(height: 24),
        HoneyButton(label: 'Back to login', onPressed: widget.onBack),
      ],
    );
  }

  Widget _form(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
            ),
            child: Text(_error!, style: AppText.body(size: 13, color: AppColors.rose)),
          ),
        AdminField(label: 'School name *', controller: _schoolName),
        AdminField(label: 'Contact name *', controller: _contactName),
        AdminField(label: 'Phone *', controller: _phone, keyboard: TextInputType.phone),
        AdminField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
        AdminField(label: 'Roughly how many students?', controller: _studentCount, keyboard: TextInputType.number),
        AdminField(label: 'Anything else we should know?', controller: _message),
        const SizedBox(height: 8),
        HoneyButton(
          label: _busy ? 'Submitting...' : 'Submit registration',
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
