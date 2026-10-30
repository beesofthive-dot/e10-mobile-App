import 'package:flutter/material.dart';

import '../auth.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/popups.dart';
import '../widgets/common.dart';

/// Shown right after a guardian verifies their OTC, when the verify-code
/// response's `guardian_schools` lists more than one school — confirmed
/// live against the deployed API: the same phone number can be a guardian
/// at several schools, each a fully separate account under the hood (see
/// the backend's `GuardianAuthController::findActiveGuardianUser`). Picking
/// a school other than the one verify-code defaulted into calls
/// `Auth.guardianEnterSchool` to actually switch, then loads that school's
/// own children as normal once on the dashboard.
class SelectChildScreen extends StatefulWidget {
  const SelectChildScreen({
    super.key,
    required this.schools,
    required this.initialUser,
    required this.onContinue,
  });

  /// Every school this phone number is linked to, as returned by the API.
  final List<({String id, String name})> schools;

  /// The user returned by `Auth.verifyGuardian` — used as-is when the
  /// picked school is already the session's current one, so that pick
  /// doesn't need an extra API round trip.
  final AppUser initialUser;
  final Future<void> Function(AppUser user) onContinue;

  @override
  State<SelectChildScreen> createState() => _SelectChildScreenState();
}

class _SelectChildScreenState extends State<SelectChildScreen> {
  String? _busySchoolId;
  String? _error;

  Future<void> _select(SchoolStore store, ({String id, String name}) school) async {
    if (_busySchoolId != null) return;
    setState(() {
      _busySchoolId = school.id;
      _error = null;
    });

    // verify-code already defaulted into one of these schools — picking
    // that same one doesn't need an extra enter() round trip.
    if (school.id == store.schoolId) {
      await widget.onContinue(widget.initialUser);
      if (!mounted) return;
      closeRoute(context);
      return;
    }

    final result = await Auth.guardianEnterSchool(school.id);
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busySchoolId = null;
        _error = result.error ?? 'Could not enter that school.';
      });
      return;
    }

    store.applyUserSchool(result.user!);
    await widget.onContinue(result.user!);

    if (!mounted) return;
    closeRoute(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    // Phone turned sideways: header on the left, school list on the right.
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height && size.height < 600;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          const AppLogo(size: 64),
          const SizedBox(height: 16),
          Text(
            'Which school would you like to sign in to?',
            textAlign: TextAlign.center,
            style: AppText.display(size: 22, weight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'This phone number is linked to more than one school. Pick one to continue.',
            textAlign: TextAlign.center,
            style: AppText.body(size: 13, color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.chrome),
        child: SafeArea(
          child: Flex(
            direction: landscape ? Axis.horizontal : Axis.vertical,
            children: [
              if (landscape)
                Expanded(child: Center(child: SingleChildScrollView(child: header)))
              else
                header,
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppSurface.card(context),
                    borderRadius: landscape
                        ? const BorderRadius.horizontal(left: Radius.circular(AppRadius.sheet))
                        : const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    children: [
                      if (_error != null) ...[
                        WhiteCard(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!, style: AppText.body(size: 12, color: AppColors.rose)),
                        ),
                        const SizedBox(height: 14),
                      ],
                      for (final school in widget.schools) ...[
                        _SchoolCard(
                          name: school.name,
                          busy: _busySchoolId == school.id,
                          disabled: _busySchoolId != null && _busySchoolId != school.id,
                          onTap: () => _select(store, school),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.name,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final String name;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: disabled || busy ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppSurface.line(context)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.honey.withValues(alpha: 0.14),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppText.body(size: 16, weight: FontWeight.w800, color: AppColors.honey),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 15, weight: FontWeight.w700, color: AppSurface.text(context)),
                  ),
                ),
                if (busy)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(Icons.chevron_right_rounded, color: AppSurface.muted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
