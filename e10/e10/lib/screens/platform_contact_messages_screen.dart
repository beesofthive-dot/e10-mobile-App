import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import 'admin_forms.dart';

/// Messages sent through the public contact form — GET
/// /platform/contact-messages, marked read via PATCH .../{id}.
class PlatformContactMessagesScreen extends StatefulWidget {
  const PlatformContactMessagesScreen({super.key, this.onBack, required this.onLogout});

  final VoidCallback? onBack;
  final VoidCallback onLogout;

  @override
  State<PlatformContactMessagesScreen> createState() => _PlatformContactMessagesScreenState();
}

class _PlatformContactMessagesScreenState extends State<PlatformContactMessagesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _messages = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final store = SchoolScope.of(context);
    final rows = await store.fetchPlatformContactMessages();
    if (!mounted) return;
    setState(() {
      _messages = rows;
      _loading = false;
    });
  }

  Future<void> _markRead(Map<String, dynamic> row) async {
    if (row['read_at'] != null) return;
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) return;
    final store = SchoolScope.of(context);
    final error = await store.markContactMessageRead(id);
    if (!mounted) return;
    if (error.isNotEmpty) {
      showSnack(context, error);
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Contact messages',
            subtitle: '${_messages.length} received',
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
                  if (!_loading && _messages.isEmpty)
                    WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('No messages yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                    )
                  else
                    for (final row in _messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: WhiteCard(
                          padding: const EdgeInsets.all(14),
                          child: InkWell(
                            onTap: () => _markRead(row),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('${row['name'] ?? 'Someone'}', style: AppText.body(size: 15, weight: FontWeight.w700)),
                                    ),
                                    if (row['read_at'] == null) const StatusDot(label: 'Unread', color: AppColors.honeyDark),
                                  ],
                                ),
                                Text(
                                  [
                                    if (row['email'] != null) '${row['email']}',
                                    if (row['phone'] != null) '${row['phone']}',
                                  ].join(' · '),
                                  style: AppText.body(size: 12, color: AppColors.slate500),
                                ),
                                const SizedBox(height: 6),
                                Text('${row['message'] ?? ''}', style: AppText.body(size: 13)),
                              ],
                            ),
                          ),
                        ),
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
