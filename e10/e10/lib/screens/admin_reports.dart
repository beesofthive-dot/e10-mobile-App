import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, required this.onBack, required this.onLogout, this.viewOnly = false});

  final VoidCallback onBack;
  final VoidCallback onLogout;
  final bool viewOnly;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _tab = 'incoming';

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final items = store.reports.where((r) => _tab == 'all' || r.kind == _tab).toList();
    return Column(
      children: [
        TopBar(
          title: 'Reports',
          subtitle: widget.viewOnly ? 'View school reports' : 'View, receive and file school reports',
          onBack: widget.onBack,
          onLogout: widget.onLogout,
          onAdd: widget.viewOnly ? null : () => _compose(context, store),
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.page(context),
            children: [
              WhiteCard(
                padding: const EdgeInsets.all(4),
                radius: 12,
                child: Row(
                  children: [
                    for (final tab in const [
                      ('incoming', 'Incoming'),
                      ('academic', 'Academic'),
                      ('all', 'All'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = tab.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: _tab == tab.$1 ? AppGradients.honey : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tab.$2,
                              textAlign: TextAlign.center,
                              style: AppText.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: _tab == tab.$1 ? Colors.white : AppColors.slate400,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final report in items) ...[
                WhiteCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(report.title, style: AppText.body(weight: FontWeight.w800)),
                          ),
                          StatusBadge(
                            text: report.received ? 'Received' : 'New',
                            tone: report.received ? Tone.emerald : Tone.honey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.from} · ${formatStamp(report.time)}',
                        style: AppText.body(size: 11, color: AppColors.slate400),
                      ),
                      const SizedBox(height: 8),
                      Text(report.body, style: AppText.body(size: 13, color: AppColors.slate600)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ActionMenuButton(
                            title: report.title,
                            actions: [
                              if (!report.received)
                                SheetAction(
                                  label: 'Receive report',
                                  icon: Icons.mark_email_read_outlined,
                                  onTap: () {
                                    store.receiveReport(report.id);
                                    showSnack(context, 'Report received');
                                  },
                                ),
                              SheetAction(
                                label: 'View',
                                icon: Icons.visibility_rounded,
                                onTap: () => _view(context, report),
                              ),
                              if (!widget.viewOnly)
                                SheetAction(
                                  label: 'Delete',
                                  icon: Icons.delete_outline_rounded,
                                  destructive: true,
                                  onTap: () async {
                                    if (await confirmDelete(context, report.title)) {
                                      store.deleteReport(report.id);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _view(BuildContext context, SchoolReport report) {
    showAppSheet<void>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(report.title, style: AppText.display(size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '${report.from}\n${formatStamp(report.time)}\n\n${report.body}',
            style: AppText.body(size: 13, color: AppColors.slate600),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => closeRoute(ctx), child: const Text('Close')),
          ),
        ],
      ),
    );
  }

  void _compose(BuildContext context, SchoolStore store) {
    final title = TextEditingController();
    final body = TextEditingController();
    var from = store.teacherNames.firstOrNull ?? 'School Admin';
    var kind = 'academic';
    showAdminForm(
      context: context,
      title: 'File a report',
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          return Column(
            children: [
              AdminField(label: 'Title', controller: title),
              AdminDropdown(
                label: 'From',
                value: from,
                items: [...store.teacherNames, 'School Admin'],
                onChanged: (v) => setLocal(() => from = v),
              ),
              AdminDropdown(
                label: 'Type',
                value: kind,
                items: const ['academic', 'incoming'],
                onChanged: (v) => setLocal(() => kind = v),
              ),
              AdminField(label: 'Details', controller: body),
              HoneyButton(
                label: 'Save report',
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  store.addReport(
                    SchoolReport(
                      id: '',
                      title: title.text.trim(),
                      from: from,
                      body: body.text.trim(),
                      time: 'Just now',
                      kind: kind,
                      received: kind == 'academic',
                    ),
                  );
                  closeRoute(ctx);
                  showSnack(context, 'Report filed');
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(() => disposeAfterClose([title, body]));
  }
}
