import 'package:flutter/material.dart';

import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/comms_panel.dart';
import '../widgets/common.dart';
import '../widgets/dash_cards.dart';
import '../widgets/popups.dart';
import 'admin_forms.dart';
import 'notifications_screen.dart';

/// Simple shared messaging for parent, teacher, staff and admin dashboards.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.user,
    this.onBack,
    required this.onLogout,
    this.title,
    this.embedded = false,
    this.homeHeader,
    this.showNotifications = false,
  });

  final AppUser user;
  final VoidCallback? onBack;
  final VoidCallback onLogout;
  final String? title;
  final bool embedded;
  final Widget? homeHeader;

  /// Adds a Chats | Notifications switch. Off by default: Messages shows
  /// chats only for every role, and notifications have their own screen
  /// (header chat menu → Notifications).
  final bool showNotifications;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String? _activeId;
  String _filter = 'All';
  bool _showingNotices = false;
  String _query = '';
  final _reply = TextEditingController();
  final _search = TextEditingController();
  final _chatScroll = ScrollController();

  /// Private conversations only — announcements have their own screen.
  List<ChatPreview> get _threads => [
        for (final t in SchoolScope.of(context).messagesFor(widget.user.role))
          if (!t.isAnnouncement) t,
      ];

  bool get _canCompose {
    final role = widget.user.role;
    return role.isAdminPortal || role == Role.teacher || role == Role.parent;
  }

  ChatPreview? get _activeThread {
    final id = _activeId;
    if (id == null) return null;
    for (final t in _threads) {
      if (t.id == id || t.threadId == id) return t;
    }
    return null;
  }

  @override
  void dispose() {
    _reply.dispose();
    _search.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
    });
  }

  Future<void> _openThread(ChatPreview thread) async {
    final store = SchoolScope.of(context);
    await store.markMessageRead(thread.id);
    setState(() => _activeId = thread.id);
    await store.loadThreadMessages(thread.threadId.isNotEmpty ? thread.threadId : thread.id);
    if (!mounted) return;
    setState(() {});
    _scrollChatToEnd();
  }

  Future<void> _sendReply(ChatPreview thread) async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final store = SchoolScope.read(context);
    String error = '';
    try {
      error = await store.runNotifyBatch(
        () => store.sendThreadReply(
          threadId: thread.threadId.isNotEmpty ? thread.threadId : thread.id,
          from: widget.user.displayName,
          fromRole: widget.user.role,
          body: text,
        ),
      );
    } catch (_) {
      error = '';
    }
    if (!mounted) return;
    if (error.isNotEmpty) {
      showSnack(context, error);
      return;
    }
    _reply.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
    _scrollChatToEnd();
  }

  Future<void> _messageActions(BuildContext context, String threadId, ChatLine line) async {
    final store = SchoolScope.of(this.context);
    await showActionSheet(
      context: context,
      title: 'Message',
      actions: [
        SheetAction(
          label: 'Edit',
          icon: Icons.edit_outlined,
          onTap: () => _editLine(store, threadId, line),
        ),
        SheetAction(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onTap: () => _deleteLine(store, threadId, line),
        ),
      ],
    );
  }

  Future<void> _editLine(SchoolStore store, String threadId, ChatLine line) async {
    final body = TextEditingController(text: line.body);
    final saved = await showAppSheet<bool>(
      context: context,
      title: 'Edit message',
      builder: (ctx) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppFieldLabel('Message', required: true),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 5,
              style: AppText.body(size: 13.5),
              decoration: appFieldDecoration(ctx),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: AppModalButton(label: 'Save', onPressed: () => closeRoute(ctx, true)),
            ),
          ],
        );
      },
    );
    if (saved != true) {
      disposeAfterClose([body]);
      return;
    }
    final error = await store.updateChatMessage(threadId: threadId, messageId: line.id, body: body.text);
    disposeAfterClose([body]);
    if (!mounted) return;
    if (error.isNotEmpty) {
      showSnack(context, error);
      return;
    }
    setState(() {});
  }

  Future<void> _deleteLine(SchoolStore store, String threadId, ChatLine line) async {
    final ok = await confirmDelete(context, 'message');
    if (!ok) return;
    final error = await store.deleteChatMessage(threadId: threadId, messageId: line.id);
    if (!mounted) return;
    if (error.isNotEmpty) {
      showSnack(context, error);
      return;
    }
    setState(() {});
  }

  List<_MsgPerson> _staffChoices(SchoolStore store) {
    final me = store.sessionUserId ?? '';
    // The API puts a class's homeroom teacher(s) in `teacher_ids` (array) —
    // there is no singular `class_teacher_id` field.
    final classTeacherIds = <String>{
      for (final klass in store.tableRows('school_classes'))
        if (klass['teacher_ids'] is List)
          for (final id in klass['teacher_ids'] as List) '$id',
    };
    final childClassIds = {
      for (final child in store.students)
        if (child.classId.isNotEmpty) child.classId,
    };
    final homeroomIds = <String>{
      for (final klass in store.tableRows('school_classes'))
        if (childClassIds.contains('${klass['id']}') && klass['teacher_ids'] is List)
          for (final id in klass['teacher_ids'] as List) '$id',
    };
    final people = <_MsgPerson>[];
    final seen = <String>{};
    for (final row in store.tableRows('staff')) {
      final userId = '${row['user_id'] ?? ''}';
      if (userId.isEmpty || userId == me || !seen.add(userId)) continue;
      final staffId = '${row['id']}';
      final name = '${row['full_name'] ?? row['email'] ?? 'Staff'}';
      final position = '${row['position'] ?? 'Staff'}';
      final isClass = homeroomIds.contains(staffId) || classTeacherIds.contains(staffId);
      final isAdminish = position.toLowerCase().contains('admin') ||
          position.toLowerCase().contains('deputy') ||
          position.toLowerCase().contains('registrar');
      people.add(_MsgPerson(
        userId: userId,
        name: name,
        detail: isClass ? 'Class teacher' : position,
        rank: isClass ? 0 : (isAdminish ? 2 : 1),
      ));
    }
    if (people.isEmpty) {
      for (final t in store.teachers) {
        final userId = t.userId.isNotEmpty ? t.userId : 'user-teacher-${t.id}';
        if (userId == me || !seen.add(userId)) continue;
        people.add(_MsgPerson(
          userId: userId,
          name: t.name,
          detail: t.detail.isEmpty ? 'Teacher' : t.detail,
          rank: 1,
        ));
      }
    }
    people.sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.name.compareTo(b.name));
    return people;
  }

  /// Every guardian a message can go to, one entry per guardian+child pair.
  /// Read from each student's own `guardians` list first — admin and teacher
  /// sessions both get that with `/students`, while only admin downloads the
  /// separate `/guardians` list — so picking a child always finds their
  /// guardian. A guardian with no linked child is left out rather than being
  /// pinned to some unrelated student.
  List<_MsgPerson> _parentChoices(SchoolStore store) {
    final people = <_MsgPerson>[];
    final seen = <String>{};
    void add(Map guardian, String studentId, String childName, String childClass) {
      final userId = '${guardian['user_id'] ?? ''}';
      if (userId.isEmpty || userId == 'null' || studentId.isEmpty) return;
      if (!seen.add('$userId|$studentId')) return;
      final relation = '${guardian['relationship'] ?? ''}';
      people.add(_MsgPerson(
        userId: userId,
        name: '${guardian['full_name'] ?? 'Parent'}',
        detail: [
          childClass.isEmpty ? childName : '$childName · $childClass',
          if (relation.isNotEmpty && relation != 'null') relation,
        ].join(' · '),
        studentId: studentId,
      ));
    }

    for (final row in store.tableRows('students')) {
      final studentId = '${row['id'] ?? ''}';
      final student = store.students.where((s) => s.id == studentId).firstOrNull;
      final guardians = row['guardians'];
      if (guardians is! List) continue;
      for (final g in guardians) {
        if (g is Map) add(g, studentId, student?.name ?? '${row['full_name'] ?? 'Child'}', student?.klass ?? '');
      }
    }
    for (final row in store.tableRows('guardians')) {
      final kids = row['students'] is List ? row['students'] as List : const [];
      for (final kid in kids) {
        if (kid is! Map) continue;
        final studentId = '${kid['id'] ?? ''}';
        final student = store.students.where((s) => s.id == studentId).firstOrNull;
        add(
          row,
          studentId,
          student?.name.isNotEmpty == true ? student!.name : '${kid['full_name'] ?? 'Child'}',
          student?.klass.isNotEmpty == true ? student!.klass : '${kid['class_name'] ?? kid['klass'] ?? ''}',
        );
      }
    }
    if (people.isEmpty) {
      for (final p in store.parents) {
        final userId = p.userId.isNotEmpty ? p.userId : 'user-parent-${p.id}';
        final linkedIds = {for (final id in p.link.split(',')) if (id.trim().isNotEmpty) id.trim()};
        for (final student in store.students) {
          if (!linkedIds.contains(student.id) && student.name != p.detail) continue;
          if (!seen.add('$userId|${student.id}')) continue;
          people.add(_MsgPerson(
            userId: userId,
            name: p.name,
            detail: '${student.name} · ${student.klass}',
            studentId: student.id,
          ));
        }
      }
    }
    people.sort((a, b) => a.name.compareTo(b.name));
    return people;
  }

  /// [classIds], when given, is a hard allowlist (e.g. a teacher's own
  /// homeroom class) that [classKey] can only narrow further — unlike
  /// [classKey] alone, leaving it unset never falls back to "every class
  /// in the school".
  List<_MsgPerson> _studentChoices(SchoolStore store, {String? classKey, Set<String>? classIds}) {
    final people = <_MsgPerson>[];
    for (final student in store.students) {
      if (classIds != null && !classIds.contains(student.classId)) continue;
      if (classKey != null &&
          classKey.isNotEmpty &&
          student.classId != classKey &&
          student.klass != classKey) {
        continue;
      }
      var userId = student.userId;
      if (userId.isEmpty) {
        for (final row in store.tableRows('students')) {
          if ('${row['id']}' != student.id) continue;
          userId = '${row['user_id'] ?? ''}';
          if (userId.isEmpty && row['user'] is Map) userId = '${(row['user'] as Map)['id'] ?? ''}';
          break;
        }
      }
      if (userId.isEmpty) userId = 'user-${student.id.toLowerCase()}';
      people.add(_MsgPerson(
        userId: userId,
        name: student.name,
        detail: student.klass.isEmpty ? 'Student' : student.klass,
        studentId: student.id,
      ));
    }
    people.sort((a, b) => a.name.compareTo(b.name));
    return people;
  }

  List<_MsgPerson> _parentsForStudents(List<_MsgPerson> parents, Iterable<String> studentIds) {
    final ids = studentIds.toSet();
    if (ids.isEmpty) return const [];
    final seen = <String>{};
    return [
      for (final p in parents)
        if (ids.contains(p.studentId) && seen.add('${p.userId}|${p.studentId}')) p,
    ];
  }

  /// One "New message" form for every role — the admin's: pick the student
  /// the message is about, pick who receives it, write, send. What each role
  /// can pick differs only by what they may reach:
  ///   * admin   → any student, then that student's guardian;
  ///   * teacher → students in the classes they teach (class or subject —
  ///               the server only returns those), then the guardian;
  ///   * parent  → their own child, then that child's teachers or admin.
  /// Class-wide notices go through Announcements, homework through Homework.
  Future<void> _compose() async {
    final store = SchoolScope.read(context);
    final isParent = widget.user.role == Role.parent;
    final isTeacher = widget.user.role == Role.teacher;
    final body = TextEditingController();
    final staff = isParent ? _staffChoices(store) : const <_MsgPerson>[];
    final parents = isParent ? const <_MsgPerson>[] : _parentChoices(store);
    final students = isParent
        ? [
            for (final c in store.linkedChildren(Role.parent))
              _MsgPerson(userId: '', name: c.name, detail: c.klass, studentId: c.id),
          ]
        : _studentChoices(store, classIds: isTeacher ? {for (final c in store.classes) c.id} : null);
    List<_MsgPerson> recipientsFor(String studentId) {
      if (studentId.isEmpty) return const [];
      return isParent ? staff : _parentsForStudents(parents, [studentId]);
    }

    // Like admin's form nothing is pre-picked — except a parent's only child.
    var studentId = isParent && students.length == 1 ? students.first.studentId : '';
    var recipientKey = recipientsFor(studentId).firstOrNull?.key ?? '';
    var sending = false;

    try {
      await showAppSheet<void>(
        context: context,
        title: 'New message',
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final recipients = recipientsFor(studentId);
              final chosen = recipients.where((p) => p.key == recipientKey).firstOrNull;

              Future<void> submit() async {
                if (sending) return;
                final text = body.text.trim();
                if (text.isEmpty) {
                  showSnack(ctx, 'Write a message first.');
                  return;
                }
                if (studentId.isEmpty) {
                  showSnack(ctx, isParent ? 'Choose which child this is about.' : 'Choose which student this is about.');
                  return;
                }
                if (chosen == null) {
                  showSnack(ctx, 'Choose who to send it to.');
                  return;
                }
                setLocal(() => sending = true);
                var error = '';
                try {
                  await store.runNotifyBatch(() async {
                    error = await store.startDirectMessage(
                      studentId: studentId,
                      participantUserId: chosen.userId,
                      body: text,
                      participantName: chosen.name,
                      participantRole: chosen.detail,
                      fromName: widget.user.displayName,
                      fromRole: widget.user.role,
                    );
                  });
                } catch (_) {
                  error = '';
                }

                if (!ctx.mounted) return;
                if (error.isNotEmpty) {
                  setLocal(() => sending = false);
                  showSnack(ctx, error);
                  return;
                }
                // The store's optimistic local-thread update (inside the send
                // call above) schedules a deferred notifyListeners() for the
                // end of the current frame. Popping this route in the same
                // synchronous breath races that deferred rebuild against the
                // route's own teardown and trips Flutter's InheritedElement
                // "_dependents.isEmpty" assertion. Waiting a frame here lets
                // the pending notify settle before the pop starts.
                await WidgetsBinding.instance.endOfFrame;
                if (!ctx.mounted) return;
                closeRoute(ctx);
                if (!mounted) return;
                showSnack(context, 'Message sent.');
                setState(() {});
              }

              final studentValue = students.where((s) => s.studentId == studentId).firstOrNull?.name ?? 'Select…';
              final recipientItems = studentId.isEmpty
                  ? [isParent ? 'Choose a child first' : 'Choose a student first']
                  : (recipients.isEmpty
                      ? [isParent ? 'No teacher or admin found' : 'No guardian found']
                      : [for (final p in recipients) p.name]);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (students.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        isParent ? 'No children linked to your account yet.' : 'No students yet.',
                        style: AppText.body(size: 12, color: AppColors.slate500),
                      ),
                    )
                  else
                    AppPickerField(
                      label: isParent ? 'About which child?' : 'About which student?',
                      required: true,
                      value: studentValue,
                      placeholder: studentId.isEmpty,
                      items: ['Select…', for (final s in students) s.name],
                      onChanged: (name) => setLocal(() {
                        studentId = students.where((s) => s.name == name).firstOrNull?.studentId ?? '';
                        recipientKey = recipientsFor(studentId).firstOrNull?.key ?? '';
                      }),
                    ),
                  AppPickerField(
                    label: isParent ? 'Send to (teacher or admin)' : "Send to (student's guardian)",
                    required: true,
                    value: chosen?.name ?? recipientItems.first,
                    placeholder: chosen == null,
                    items: recipientItems,
                    enabled: recipients.isNotEmpty,
                    onChanged: (name) => setLocal(() {
                      recipientKey = recipients.where((p) => p.name == name).firstOrNull?.key ?? recipientKey;
                    }),
                  ),
                  const AppFieldLabel('Message', required: true),
                  TextField(
                    controller: body,
                    minLines: 4,
                    maxLines: 6,
                    onChanged: (_) => setLocal(() {}),
                    style: AppText.body(size: 13.5),
                    decoration: appFieldDecoration(ctx),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppModalButton(
                      label: sending ? 'Sending…' : 'Send',
                      onPressed: sending || body.text.trim().isEmpty ? null : submit,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // `push()` resolves as soon as the route is popped, but the route's
      // own exit transition keeps its TextFields (and their controllers)
      // mounted for the ~300ms MaterialPageRoute animation after that — a
      // microtask fires long before the transition finishes and disposes
      // out from under a still-animating TextField ("used after being
      // disposed"). Outlasting the transition, not just yielding once,
      // is what actually avoids the race.
      Future.delayed(const Duration(milliseconds: 350), body.dispose);
    }
  }

  Widget _pageHeader({
    required String title,
    String? subtitle,
    VoidCallback? onBack,
    bool showSchool = false,
  }) {
    return AdminPageHeader(
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      showSchool: showSchool,
      trailing: widget.embedded
          ? null
          : SchoolMarkButton(user: widget.user, onLogout: widget.onLogout, size: 36),
    );
  }

  Widget _threadView(ChatPreview msg) {
    final store = SchoolScope.of(context);
    final me = store.sessionUserId ?? '';
    final threadId = msg.threadId.isNotEmpty ? msg.threadId : msg.id;
    final canManageOthers = widget.user.role.isAdminPortal;
    final lines = msg.timeline;

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          _pageHeader(
            title: msg.from,
            subtitle: msg.isAnnouncement
                ? 'Announcement · ${msg.role}'
                : msg.isSystem
                    ? 'Automatic school alerts'
                    : (msg.toLabel.isNotEmpty ? msg.toLabel : msg.role),
            onBack: () => setState(() => _activeId = null),
          ),
          if (msg.isAnnouncement && msg.avatar.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              color: AppSurface.card(context),
              child: Text(
                msg.avatar.trim(),
                style: AppText.body(size: 15, weight: FontWeight.w800),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _chatScroll,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                final mine = !line.system && (line.senderId.isNotEmpty ? line.senderId == me : line.role == widget.user.role);
                final canManage = (mine || canManageOthers) && line.id.isNotEmpty && !msg.isAnnouncement;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onLongPress: canManage ? () => _messageActions(context, threadId, line) : null,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.accentSoft : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  line.from,
                                  style: AppText.body(size: 12, weight: FontWeight.w700, color: AppSurface.brand(context)),
                                ),
                              ),
                            Text(
                              line.body,
                              style: AppText.body(size: 14, color: AppColors.slate800, height: 1.35),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              line.edited ? 'Edited · ${formatStamp(line.time)}' : formatStamp(line.time),
                              style: AppText.body(size: 11, color: AppColors.slate400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Nobody to reply to on an automatic system thread.
          if (!msg.isSystem)
          Material(
            color: Colors.white,
            elevation: 2,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendReply(msg),
                          style: AppText.body(size: 14, color: AppColors.slate800),
                          cursorColor: AppSurface.brand(context),
                          decoration: InputDecoration(
                            hintText: msg.isAnnouncement ? 'Reply…' : 'Message',
                            hintStyle: AppText.body(size: 14, color: AppColors.slate400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppSurface.brand(context),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 44),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _sendReply(msg),
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatRow(ChatPreview thread) {
    final outgoing = thread.sentByRole != null && thread.sentByRole == widget.user.role;
    final unreadIncoming = !outgoing && thread.unread;
    return InkWell(
      onTap: () => _openThread(thread),
      child: Container(
        color: unreadIncoming ? AppSurface.brand(context).withValues(alpha: 0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            InitialsAvatar(
              name: thread.from,
              tone: thread.isAnnouncement ? Tone.honey : Tone.emerald,
              size: AvatarSize.md,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.from,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 15.5,
                            weight: unreadIncoming ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.slate800,
                          ),
                        ),
                      ),
                      Text(
                        formatStamp(thread.time),
                        style: AppText.body(
                          size: 11.5,
                          weight: unreadIncoming ? FontWeight.w700 : FontWeight.w400,
                          color: unreadIncoming ? AppSurface.brand(context) : AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 13,
                            weight: unreadIncoming ? FontWeight.w600 : FontWeight.w400,
                            color: unreadIncoming ? AppColors.slate700 : AppColors.slate500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MessageStatusChip(
                        unread: unreadIncoming,
                        sent: outgoing,
                        count: unreadIncoming ? thread.badgeCount : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurface.page(context),
      child: _buildBody(context),
    );
  }

  Widget _sectionSwitch(SchoolStore store, int unreadChats) {
    final unreadNotices = store.unreadNoticeCount(widget.user.role);
    Widget tab(String label, int count, bool selected, VoidCallback onTap) {
      final brand = AppSurface.brand(context);
      return Expanded(
        child: Material(
          color: selected ? brand : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: AppText.body(size: 13, weight: FontWeight.w800, color: selected ? Colors.white : AppSurface.ink(context)),
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : AppColors.honey,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: AppText.body(size: 10, weight: FontWeight.w800, color: selected ? brand : Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppSurface.line(context)),
      ),
      child: Row(
        children: [
          tab('Chats', unreadChats, !_showingNotices, () => setState(() => _showingNotices = false)),
          tab('Notifications', unreadNotices, _showingNotices, () => setState(() => _showingNotices = true)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final active = _activeThread;
    if (active != null) return _threadView(active);

    final store = SchoolScope.of(context);
    final unreadCount = [for (final t in _threads) if (t.unread && t.sentByRole != widget.user.role) t].length;
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final t in _threads)
        if (() {
          final outgoing = t.sentByRole != null && t.sentByRole == widget.user.role;
          final unreadIncoming = !outgoing && t.unread;
          if (_filter == 'Unread' && !unreadIncoming) return false;
          if (_filter == 'Read' && unreadIncoming) return false;
          if (q.isNotEmpty &&
              !(t.from.toLowerCase().contains(q) ||
                  t.preview.toLowerCase().contains(q) ||
                  t.role.toLowerCase().contains(q))) {
            return false;
          }
          return true;
        }())
          t,
    ];

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in const ['All', 'Unread', 'Read'])
          ChoiceChip(
            label: Text(f),
            selected: _filter == f,
            onSelected: (_) => setState(() => _filter = f),
            selectedColor: AppSurface.brand(context).withValues(alpha: 0.12),
            checkmarkColor: AppSurface.brand(context),
            backgroundColor: AppSurface.card(context),
            labelStyle: AppText.body(
              size: 12,
              weight: FontWeight.w700,
              color: _filter == f ? AppSurface.brand(context) : AppColors.slate500,
            ),
            side: BorderSide(color: _filter == f ? AppSurface.brand(context) : AppSurface.line(context)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );

    return ColoredBox(
      color: AppSurface.page(context),
      child: Column(
        children: [
          if (widget.homeHeader != null) widget.homeHeader!,
          if (!widget.embedded)
            _pageHeader(
              title: widget.title ?? 'Messages',
              subtitle: unreadCount == 0 ? null : '$unreadCount unread',
              onBack: widget.onBack,
              showSchool: true,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.syncFromApi(),
              child: ListView(
                padding: AppLayout.page(context),
                children: [
                  if (widget.showNotifications) ...[
                    _sectionSwitch(store, unreadCount),
                    const SizedBox(height: 12),
                  ],
                  if (_showingNotices && widget.showNotifications)
                    ...notificationFeed(context, widget.user.role)
                  else
                  CommsPanel(
                    title: 'Messages',
                    searchHint: 'Search messages...',
                    searchController: _search,
                    onSearch: (v) => setState(() => _query = v),
                    onNew: _canCompose ? _compose : null,
                    below: filters,
                    children: [
                      if (visible.isEmpty)
                        store.syncError != null
                            ? CommsEmpty(
                                icon: Icons.cloud_off_rounded,
                                text: 'Unable to load messages. ${store.syncError!}',
                                action: TextButton(
                                  onPressed: () => store.syncFromApi(),
                                  child: const Text('Retry'),
                                ),
                              )
                            : CommsEmpty(
                                icon: Icons.chat_bubble_outline_rounded,
                                text: _threads.isNotEmpty
                                    ? 'No conversations match.'
                                    : _canCompose
                                        ? 'No chats yet. Tap + New to start a conversation.'
                                        : 'Messages from school will appear here.',
                              )
                      else
                        for (final (i, thread) in visible.indexed) ...[
                          if (i > 0) Divider(height: 1, indent: 64, color: AppSurface.line(context)),
                          _chatRow(thread),
                        ],
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
}

class _MsgPerson {
  _MsgPerson({
    required this.userId,
    required this.name,
    required this.detail,
    this.studentId = '',
    this.rank = 1,
  });

  final String userId;
  final String name;
  final String detail;
  final String studentId;
  final int rank;

  /// Unique key for multi-select (parent+child pairs need both ids).
  String get key => studentId.isEmpty ? userId : '$userId|$studentId';
}

class MessageStatusChip extends StatelessWidget {
  const MessageStatusChip({
    super.key,
    required this.unread,
    required this.sent,
    this.count,
  });

  final bool unread;
  final bool sent;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (unread && count != null && count! > 0) {
      return Container(
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppSurface.brand(context),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: AppText.body(
            size: 11,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return Icon(
      sent ? Icons.done_all_rounded : Icons.chevron_right_rounded,
      size: 18,
      color: unread ? AppSurface.brand(context) : AppColors.slate300,
    );
  }
}
