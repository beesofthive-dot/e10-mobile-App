import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../core/config/api_config.dart';
import '../models.dart';
import '../plan_access.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Shown in place of a screen the school's plan doesn't cover, so the user
/// gets a reason instead of an empty page. School admins can ask BeeSoft
/// Hive to add the module, same as the website's "Not part of your plan".
class PlanLockedScreen extends StatefulWidget {
  const PlanLockedScreen({
    super.key,
    required this.user,
    required this.module,
    required this.onBack,
    required this.onLogout,
  });

  final AppUser user;
  final String module;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<PlanLockedScreen> createState() => _PlanLockedScreenState();
}

class _PlanLockedScreenState extends State<PlanLockedScreen> {
  bool _sending = false;
  bool _sent = false;

  bool get _isSchoolAdmin => widget.user.roleSlugs.contains('school_admin');

  String get _label => planModuleLabels[widget.module] ?? 'This feature';

  Future<void> _request() async {
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post(ApiConfig.schoolUpgradeRequestPath, {'module': widget.module});
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : 'Could not send your request'),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final plan = user.planName.isNotEmpty
        ? " in your school's ${user.planName} plan"
        : user.planGrade.isNotEmpty
            ? " in your school's Grade ${user.planGrade} plan"
            : " in your school's plan";
    final next = _isSchoolAdmin
        ? ' Send us a request and we will get back to you.'
        : ' Ask your school administrator to request it.';
    return Column(
      children: [
        TopBar(title: _label, subtitle: 'Not part of your plan', onBack: widget.onBack, onLogout: widget.onLogout),
        Expanded(
          child: SingleChildScrollView(
            padding: AppLayout.page(context),
            child: LockedNoticeCard(
              icon: Icons.lock_outline_rounded,
              title: 'Not part of your plan',
              message: '$_label is not included$plan.$next',
              actions: [
                if (_isSchoolAdmin)
                  _sent
                      ? Text('✓ Request sent — we\'ll be in touch.',
                          style: AppText.body(size: 14, weight: FontWeight.w600, color: AppSurface.text(context)))
                      : HoneyButton(
                          label: 'Request $_label',
                          loading: _sending,
                          onPressed: _sending ? null : _request,
                        ),
                TextButton(onPressed: widget.onBack, child: const Text('Back')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Whole-school lock (`subscription_access.access_level == none`): the term
/// isn't paid, so every screen shows why instead of empty lists.
class SchoolLockedScreen extends StatelessWidget {
  const SchoolLockedScreen({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isSchoolAdmin = user.roleSlugs.contains('school_admin');
    final school = user.school.isNotEmpty ? ' for ${user.school}' : '';
    final reason = user.blockReason.isNotEmpty
        ? user.blockReason
        : 'e10 is temporarily unavailable$school. Please contact the school.';
    return Column(
      children: [
        TopBar(title: user.school.isNotEmpty ? user.school : 'e10', onLogout: onLogout),
        Expanded(
          child: SingleChildScrollView(
            padding: AppLayout.page(context),
            child: LockedNoticeCard(
              icon: Icons.lock_clock_outlined,
              title: isSchoolAdmin ? 'e10 is locked' : 'Temporarily unavailable',
              message: isSchoolAdmin
                  ? '$reason\n\nStaff and parents see that e10 is temporarily unavailable. '
                      'Card and palm check-ins are still recorded. e10 unlocks as soon as the payment is recorded.'
                  : reason,
              actions: [TextButton(onPressed: onLogout, child: const Text('Sign out'))],
            ),
          ),
        ),
      ],
    );
  }
}

class LockedNoticeCard extends StatelessWidget {
  const LockedNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: AppSurface.iconOnCard(context)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppText.display(size: 20, weight: FontWeight.w700, color: AppSurface.text(context)))),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: AppText.body(size: 14, color: AppSurface.muted(context)).copyWith(height: 1.5)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ],
        ],
      ),
    );
  }
}
