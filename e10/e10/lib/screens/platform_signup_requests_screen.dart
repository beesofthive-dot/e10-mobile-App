import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

/// Schools that applied through the public "Register your school" form —
/// GET /platform/signup-requests, reviewed via PATCH .../{id} with a status.
class PlatformSignupRequestsScreen extends StatefulWidget {
  const PlatformSignupRequestsScreen({super.key, this.onBack, required this.onLogout});

  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<PlatformSignupRequestsScreen> createState() => _PlatformSignupRequestsScreenState();
}

class _PlatformSignupRequestsScreenState extends State<PlatformSignupRequestsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final store = SchoolScope.of(context);
    final rows = await store.fetchPlatformSignupRequests();
    if (!mounted) return;
    setState(() {
      _requests = rows;
      _loading = false;
    });
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) return;
    final store = SchoolScope.of(context);
    final error = await store.updateSignupRequestStatus(id, status);
    if (!mounted) return;
    if (error.isNotEmpty) {
      showSnack(context, error);
      return;
    }
    showSnack(context, 'Marked as $status.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Signup requests',
            subtitle: '${_requests.length} received',
            onBack: widget.onBack,
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppLayout.page(context),
                children: [
                  if (!_loading && _requests.isEmpty)
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('No signup requests yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                    )
                  else
                    for (final row in _requests) _SignupRow(row: row, onSetStatus: (s) => _setStatus(row, s)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupRow extends StatelessWidget {
  const _SignupRow({required this.row, required this.onSetStatus});

  final Map<String, dynamic> row;
  final ValueChanged<String> onSetStatus;

  (String, Color) _statusTone(String status) {
    return switch (status.toLowerCase()) {
      'approved' => ('Approved', AppColors.emerald),
      'rejected' => ('Rejected', AppColors.rose),
      'contacted' => ('Contacted', AppColors.blue),
      _ => ('New', AppColors.honeyDark),
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = '${row['status'] ?? 'new'}';
    final tone = _statusTone(status);
    final studentCount = row['student_count'];
    final message = '${row['message'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WhiteCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['school_name'] ?? 'Untitled school'}', style: AppText.body(size: 15, weight: FontWeight.w700)),
                      Text(
                        '${row['contact_name'] ?? ''} · ${row['phone'] ?? ''}',
                        style: AppText.body(size: 12, color: AppColors.slate500),
                      ),
                      if (row['email'] != null) Text('${row['email']}', style: AppText.body(size: 12, color: AppColors.slate500)),
                      if (studentCount != null)
                        Text('~$studentCount students', style: AppText.body(size: 12, color: AppColors.slate500)),
                    ],
                  ),
                ),
                StatusDot(label: tone.$1, color: tone.$2),
                ActionMenuButton(
                  actions: [
                    SheetAction(label: 'Mark contacted', icon: Icons.call_outlined, onTap: () => onSetStatus('contacted')),
                    SheetAction(label: 'Approve', icon: Icons.check_circle_outline_rounded, onTap: () => onSetStatus('approved')),
                    SheetAction(label: 'Reject', icon: Icons.cancel_outlined, destructive: true, onTap: () => onSetStatus('rejected')),
                  ],
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message, style: AppText.body(size: 12, color: AppColors.slate500)),
            ],
          ],
        ),
      ),
    );
  }
}
