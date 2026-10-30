import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/comms_panel.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';

/// School announcements for every role — opened from the header's
/// communication menu (and the admin sidebar / teacher drawer).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    required this.user,
    required this.onBack,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String _query = '';

  bool get _isAdmin => widget.user.role.isAdminPortal;
  bool get _isTeacher => widget.user.role == Role.teacher;

  /// A teacher posts to the boards of the classes they teach — their own
  /// class or any class they take a subject in — never the whole school.
  /// For a teacher session the server only returns those classes (see the
  /// backend's TeacherScope::assignedClassIds, which is also what it checks
  /// when the announcement is posted).
  List<NamedRecord> _teacherClasses(SchoolStore store) => store.classes;

  bool _canPost(SchoolStore store) => _isAdmin || (_isTeacher && _teacherClasses(store).isNotEmpty);

  List<Map<String, dynamic>> _visible(SchoolStore store) {
    final rows = store.tableRows('announcements');
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return [
      for (final row in rows)
        if (_s(row['title']).toLowerCase().contains(q) ||
            _s(row['body']).toLowerCase().contains(q) ||
            _posterName(row).toLowerCase().contains(q) ||
            _s(row['audience']).toLowerCase().contains(q))
          row,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final rows = _visible(store);
    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          AdminPageHeader(
            title: 'Announcements',
            showSchool: true,
            onBack: widget.onBack,
            trailing: SchoolMarkButton(user: widget.user, onLogout: widget.onLogout, size: 36),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.syncFromApi(),
              child: ListView(
                padding: AppLayout.page(context),
                children: [
                  CommsPanel(
                    title: 'Announcements',
                    searchHint: 'Search announcements...',
                    onSearch: (v) => setState(() => _query = v),
                    onNew: _canPost(store) ? () => _newAnnouncement(store) : null,
                    children: [
                      if (store.syncError != null)
                        CommsEmpty(icon: Icons.cloud_off_rounded, text: store.syncError!)
                      else if (rows.isEmpty)
                        CommsEmpty(
                          icon: Icons.campaign_outlined,
                          text: _query.trim().isEmpty ? 'No announcements yet.' : 'No announcements match your search.',
                        )
                      else
                        for (final row in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AnnouncementCard(
                              title: _s(row['title']).isEmpty ? 'School announcement' : _s(row['title']),
                              body: _s(row['body']),
                              audience: _audienceLabel(store, row),
                              meta: [
                                _posterName(row).toUpperCase(),
                                formatStamp(_s(row['posted_at'] ?? row['created_at'])),
                              ].where((p) => p.isNotEmpty).join(' · '),
                              replies: _replyCount(row),
                              onReplies: () => _openReplies(store, row),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _replyCount(Map<String, dynamic> row) {
    final count = row['reply_count'];
    if (count is num) return count.toInt();
    final parsed = int.tryParse('${count ?? ''}');
    if (parsed != null) return parsed;
    return row['replies'] is List ? (row['replies'] as List).length : 0;
  }

  String _posterName(Map<String, dynamic> row) {
    final poster = row['poster'];
    if (poster is Map) {
      final name = _s(poster['full_name']);
      if (name.isNotEmpty) return name;
    }
    return 'School';
  }

  String _audienceLabel(SchoolStore store, Map<String, dynamic> row) {
    final audience = _s(row['audience']);
    return switch (audience) {
      'all' || '' => 'All',
      'parents' => 'Parents',
      'teachers' => 'Teachers',
      'students' => 'Students',
      'single_class' => row['class'] is Map && _s((row['class'] as Map)['name']).isNotEmpty
          ? _s((row['class'] as Map)['name'])
          : store.classDisplayName(_s(row['class_id'])),
      _ => audience,
    };
  }

  Future<void> _openReplies(SchoolStore store, Map<String, dynamic> row) async {
    final id = _s(row['id']);
    final allowReplies = row['allow_replies'] != false;
    final replies = [
      for (final r in (row['replies'] is List ? row['replies'] as List : const []))
        if (r is Map) Map<String, dynamic>.from(r),
    ];
    final reply = TextEditingController();
    var sending = false;
    await showAppSheet<void>(
      context: context,
      title: _s(row['title']).isEmpty ? 'School announcement' : _s(row['title']),
      subtitle: 'Replies (${_replyCount(row)})',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> send() async {
            final text = reply.text.trim();
            if (text.isEmpty || sending) return;
            setLocal(() => sending = true);
            final error = await store.sendThreadReply(
              threadId: id,
              from: widget.user.displayName,
              fromRole: widget.user.role,
              body: text,
            );
            if (!ctx.mounted) return;
            if (error.isNotEmpty) {
              setLocal(() => sending = false);
              showSnack(ctx, error);
              return;
            }
            closeRoute(ctx);
            unawaited(store.syncFromApi());
            if (mounted) showSnack(context, 'Reply sent.');
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_s(row['body']).isNotEmpty) ...[
                Text(_s(row['body']), style: AppText.body(size: 13.5, color: AppColors.slate600, height: 1.4)),
                const SizedBox(height: 16),
              ],
              if (replies.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text('No replies yet.', style: AppText.body(size: 13, color: AppColors.slate400)),
                )
              else
                for (final r in replies)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [_replyAuthor(r), formatStamp(_s(r['created_at']))].where((p) => p.isNotEmpty).join(' · '),
                          style: AppText.body(size: 11.5, weight: FontWeight.w600, color: AppColors.slate500),
                        ),
                        const SizedBox(height: 4),
                        Text(_s(r['body']), style: AppText.body(size: 13.5, color: AppColors.slate800)),
                      ],
                    ),
                  ),
              if (allowReplies) ...[
                const SizedBox(height: 6),
                const AppFieldLabel('Your reply'),
                TextField(
                  controller: reply,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setLocal(() {}),
                  style: AppText.body(size: 13.5),
                  decoration: appFieldDecoration(ctx),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppModalButton(
                    label: sending ? 'Sending…' : 'Send reply',
                    onPressed: reply.text.trim().isEmpty || sending ? null : send,
                  ),
                ),
              ] else
                Text('Replies are turned off for this announcement.',
                    style: AppText.body(size: 12, color: AppColors.slate400)),
            ],
          );
        },
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), reply.dispose);
  }

  String _replyAuthor(Map<String, dynamic> reply) {
    final author = reply['author'];
    if (author is Map) {
      for (final key in const ['staff_name', 'guardian_name', 'super_admin_name', 'email']) {
        final text = _s(author[key]);
        if (text.isNotEmpty) return text;
      }
    }
    return 'Member';
  }

  Future<void> _newAnnouncement(SchoolStore store) async {
    // Everyone gets the admin's form. A teacher's Audience list simply has
    // one choice — a class they teach — never "All"/"Parents"/"Teachers".
    const adminAudiences = {'All': 'all', 'Parents': 'parents', 'Teachers': 'teachers', 'Single class': 'single_class'};
    final audiences = _isAdmin ? adminAudiences.keys.toList() : const ['Single class'];
    final teacherClasses = _isTeacher ? _teacherClasses(store) : const <NamedRecord>[];
    final classes = _isAdmin ? store.classes : teacherClasses;
    final title = TextEditingController();
    final body = TextEditingController();
    var audience = audiences.first;
    var allowReplies = true;
    String? classId = _isTeacher && teacherClasses.length == 1 ? teacherClasses.first.id : null;
    var sending = false;
    await showAppSheet<void>(
      context: context,
      title: 'New Announcement',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final singleClass = _isTeacher || audience == 'Single class';
          final ready = title.text.trim().isNotEmpty &&
              body.text.trim().isNotEmpty &&
              (!singleClass || (classId?.isNotEmpty ?? false)) &&
              !sending;

          Future<void> submit() async {
            setLocal(() => sending = true);
            final error = await store.sendGroupNotice(
              title: title.text.trim(),
              body: body.text.trim(),
              audience: _isTeacher ? 'single_class' : adminAudiences[audience]!,
              classId: singleClass ? classId : null,
              fromRole: widget.user.role,
              allowReplies: allowReplies,
            );
            if (!ctx.mounted) return;
            if (error.isNotEmpty) {
              setLocal(() => sending = false);
              showSnack(ctx, error);
              return;
            }
            closeRoute(ctx);
            if (mounted) showSnack(context, 'Announcement posted.');
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppFieldLabel('Title', required: true),
              TextField(
                controller: title,
                onChanged: (_) => setLocal(() {}),
                style: AppText.body(size: 13.5),
                decoration: appFieldDecoration(ctx),
              ),
              const SizedBox(height: 14),
              AppPickerField(
                label: 'Audience',
                required: true,
                value: audience,
                items: audiences,
                onChanged: (v) => setLocal(() => audience = v),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setLocal(() => allowReplies = !allowReplies),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: allowReplies,
                          activeColor: AppSurface.brand(ctx),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => setLocal(() => allowReplies = v ?? true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Allow threaded replies', style: AppText.body(size: 13.5, color: AppColors.slate700)),
                    ],
                  ),
                ),
              ),
              if (singleClass && classes.isNotEmpty)
                AppPickerField(
                  label: 'Class',
                  required: true,
                  value: classes.where((c) => c.id == classId).firstOrNull?.name ?? 'Select class',
                  placeholder: classId == null,
                  items: [for (final c in classes) c.name],
                  onChanged: (name) => setLocal(() => classId = classes.where((c) => c.name == name).firstOrNull?.id),
                ),
              const AppFieldLabel('Body', required: true),
              TextField(
                controller: body,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setLocal(() {}),
                style: AppText.body(size: 13.5),
                decoration: appFieldDecoration(ctx),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: AppModalButton(
                  label: sending ? 'Posting…' : 'Post announcement',
                  onPressed: ready ? submit : null,
                ),
              ),
            ],
          );
        },
      ),
    );
    disposeAfterClose([title, body]);
  }

  static String _s(dynamic value) => value == null ? '' : '$value'.trim();
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.title,
    required this.body,
    required this.audience,
    required this.meta,
    required this.replies,
    required this.onReplies,
  });

  final String title;
  final String body;
  final String audience;
  final String meta;
  final int replies;
  final VoidCallback onReplies;

  @override
  Widget build(BuildContext context) {
    final brand = AppSurface.brand(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.body(size: 15.5, weight: FontWeight.w700, color: AppSurface.text(context)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(audience, style: AppText.body(size: 11, weight: FontWeight.w700, color: brand)),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 13.5, color: AppSurface.muted(context), height: 1.4),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta, style: AppText.body(size: 11.5, color: AppColors.slate400)),
          ],
          const SizedBox(height: 10),
          Material(
            color: AppSurface.dark(context) ? AppColors.nightCard : AppColors.slate100,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onReplies,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'Replies ($replies)',
                  style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.text(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
