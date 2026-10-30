import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/comms_panel.dart';

/// Nurse desk. The school server does not record clinic visits yet, so this
/// shows an honest empty state instead of made-up patients.
class ClinicScreen extends StatelessWidget {
  const ClinicScreen({super.key, required this.onBack, required this.onLogout});

  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopBar(
          title: 'School Clinic',
          subtitle: 'Nurse desk',
          onBack: onBack,
          onLogout: onLogout,
        ),
        Expanded(
          child: Padding(
            padding: AppLayout.page(context),
            child: const CommsEmpty(
              icon: Icons.medical_services_outlined,
              text: 'No clinic visits recorded yet.',
            ),
          ),
        ),
      ],
    );
  }
}
