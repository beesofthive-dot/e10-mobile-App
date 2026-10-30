import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../school_store.dart';
import '../theme.dart';
import 'school_letterhead.dart';

/// Editable input form for a report card — deliberately shares its outer
/// card, letterhead and typography with [ReportCardView] (the read-only
/// version the same report renders as once finalized) so filling a report
/// in and reading it back look like the same document, not two different
/// products. Used to render as a stamped GES paper form with the app's own
/// logo doubled on either side instead of the school's; that's gone now.
class AssessmentReportSheet extends StatelessWidget {
  const AssessmentReportSheet({
    super.key,
    required this.report,
    required this.line,
    this.canEditScores = false,
    this.canEditHead = false,
    this.onChanged,
  });

  final AcademicReport report;
  final ReportLine line;
  final bool canEditScores;
  final bool canEditHead;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    line.ensureReportSubjects(
      SchoolScope.maybeOf(context)?.reportSubjectTemplates ??
          [for (final name in gesReportSubjects) ReportSubjectMark(subject: name)],
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppSurface.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppSurface.line(context)),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SchoolLetterhead(),
          const SizedBox(height: 8),
          Text(
            canEditScores || canEditHead ? 'Editing this assessment sheet' : 'Assessment sheet · read only',
            style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.icon),
          ),
          const SizedBox(height: 14),
          _identity(context),
          const SizedBox(height: 14),
          _lineField(context, 'TEACHER REMARK', () => line.remark, (v) => line.remark = v, canEditScores),
          _lineField(context, 'HEADTEACHER REMARK', () => line.headteacherRemark, (v) => line.headteacherRemark = v, canEditHead),
          const SizedBox(height: 6),
          _scoreTable(context),
          const SizedBox(height: 14),
          _attendance(context),
          const SizedBox(height: 10),
          _lineField(context, 'Promoted to', () => line.promotedTo, (v) => line.promotedTo = v, canEditScores),
          _lineField(context, 'Conduct', () => line.conduct, (v) => line.conduct = v, canEditScores),
          _lineField(context, 'Interest', () => line.interest, (v) => line.interest = v, canEditScores),
          _lineField(context, 'Attitude', () => line.attitude, (v) => line.attitude = v, canEditScores),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Signature("Class teacher's signature", report.teacher)),
              const SizedBox(width: 16),
              const Expanded(child: _Signature("Head teacher's signature", '')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identity(BuildContext context) {
    return Column(
      children: [
        _twoFields(
          'NAME',
          line.student,
          'STUDENT ID',
          line.studentId.isEmpty ? '—' : line.studentId,
        ),
        _twoFields('CLASS', report.klass, 'YEAR', report.year),
        _twoFields('TERM', report.term, 'POSITION', line.position.isEmpty ? '—' : line.position),
        _twoFields('VACATION DATE', report.vacationDate, 'NEXT TERM BEGINS', report.nextTermBegins),
        _twoFields(
          'NUMBER ON ROLL',
          '${report.lines.length}',
          'PROMOTION',
          line.promotedTo.isNotEmpty
              ? line.promotedTo
              : line.promote == true
                  ? 'Promoted'
                  : '—',
        ),
      ],
    );
  }

  Widget _twoFields(String a, String av, String b, String bv) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: _dotted(a, av)),
          const SizedBox(width: 10),
          Expanded(child: _dotted(b, bv)),
        ],
      ),
    );
  }

  Widget _dotted(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: AppText.body(size: 10, weight: FontWeight.w800, color: AppColors.icon)),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate400, style: BorderStyle.solid)),
            ),
            child: Text(
              value.isEmpty ? ' ' : value,
              style: AppText.body(size: 11, weight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoreTable(BuildContext context) {
    const headers = [
      'SUBJECT',
      'CLASS SCORE (50%)',
      'EXAM SCORE (50%)',
      'TOTAL SCORE (100%)',
      'POS.',
      'REMARKS',
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppSurface.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 48),
          child: Table(
            border: TableBorder.symmetric(inside: BorderSide(color: AppSurface.line(context))),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FixedColumnWidth(108),
              1: FixedColumnWidth(78),
              2: FixedColumnWidth(78),
              3: FixedColumnWidth(78),
              4: FixedColumnWidth(44),
              5: FixedColumnWidth(92),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppSurface.cardSoft(context)),
                children: [
                  for (final h in headers)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        h,
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 9, weight: FontWeight.w800, color: AppSurface.muted(context), letterSpacing: 0.2),
                      ),
                    ),
                ],
              ),
              for (final mark in line.subjects)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text(mark.subject.toUpperCase(), style: AppText.body(size: 10, weight: FontWeight.w700)),
                    ),
                    _numCell(
                      '${line.student}-${mark.subject}-class',
                      mark.classScore,
                      canEditScores,
                      (v) {
                        mark.classScore = v.clamp(0, 50);
                        mark.syncRemark();
                        onChanged?.call();
                      },
                    ),
                    _numCell(
                      '${line.student}-${mark.subject}-exam',
                      mark.examScore,
                      canEditScores,
                      (v) {
                        mark.examScore = v.clamp(0, 50);
                        mark.syncRemark();
                        onChanged?.call();
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('${mark.total}', textAlign: TextAlign.center, style: AppText.body(size: 11, weight: FontWeight.w800)),
                    ),
                    _textCell(
                      '${line.student}-${mark.subject}-pos',
                      mark.position,
                      canEditScores,
                      (v) {
                        mark.position = v;
                        onChanged?.call();
                      },
                      center: true,
                    ),
                    _textCell(
                      '${line.student}-${mark.subject}-remark',
                      mark.remark,
                      canEditScores,
                      (v) {
                        mark.remark = v;
                        onChanged?.call();
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numCell(String id, int value, bool edit, ValueChanged<int> onSet) {
    if (!edit) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text(value == 0 ? '' : '$value', textAlign: TextAlign.center, style: AppText.body(size: 11)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: _BoundTextField(
        key: ValueKey(id),
        value: value == 0 ? '' : '$value',
        keyboard: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: AppText.body(size: 11, weight: FontWeight.w600),
        decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '0'),
        onChanged: (v) => onSet(int.tryParse(v) ?? 0),
      ),
    );
  }

  Widget _textCell(String id, String value, bool edit, ValueChanged<String> onSet, {bool center = false}) {
    if (!edit) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Text(value, textAlign: center ? TextAlign.center : TextAlign.left, style: AppText.body(size: 10)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: _BoundTextField(
        key: ValueKey(id),
        value: value,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: AppText.body(size: 10),
        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
        onChanged: onSet,
      ),
    );
  }

  Widget _attendance(BuildContext context) {
    return Row(
      children: [
        Text('Attendance made: ', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.icon)),
        Expanded(
          child: _underlineValue(
            '${line.student}-att-made',
            line.attendanceMade,
            canEditScores,
            (v) => line.attendanceMade = v,
          ),
        ),
        Text('  Out of: ', style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.icon)),
        Expanded(
          child: _underlineValue(
            '${line.student}-att-out',
            line.attendanceOutOf,
            canEditScores,
            (v) => line.attendanceOutOf = v,
          ),
        ),
      ],
    );
  }

  Widget _underlineValue(String id, String value, bool edit, ValueChanged<String> onSet) {
    if (!edit) {
      return Container(
        padding: const EdgeInsets.only(bottom: 2),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate400))),
        child: Text(value.isEmpty ? ' ' : value, style: AppText.body(size: 11, weight: FontWeight.w600)),
      );
    }
    return _BoundTextField(
      key: ValueKey(id),
      value: value,
      style: AppText.body(size: 11, weight: FontWeight.w600),
      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
      onChanged: (v) {
        onSet(v);
        onChanged?.call();
      },
    );
  }

  Widget _lineField(BuildContext context, String label, String Function() read, ValueChanged<String> write, bool edit) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.3)),
          const SizedBox(height: 2),
          edit
              ? _BoundTextField(
                  key: ValueKey('${line.student}-$label'),
                  value: read(),
                  maxLines: 2,
                  style: AppText.body(size: 12),
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (v) {
                    write(v);
                    onChanged?.call();
                  },
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 6, top: 2),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate400))),
                  child: Text(read().isEmpty ? ' ' : read(), style: AppText.body(size: 12)),
                ),
        ],
      ),
    );
  }
}

class _BoundTextField extends StatefulWidget {
  const _BoundTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyboard,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.style,
    this.maxLines = 1,
    this.decoration = const InputDecoration(isDense: true, border: InputBorder.none),
  });

  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final TextStyle? style;
  final int maxLines;
  final InputDecoration decoration;

  @override
  State<_BoundTextField> createState() => _BoundTextFieldState();
}

class _BoundTextFieldState extends State<_BoundTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(_BoundTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focus.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: widget.keyboard,
      inputFormatters: widget.inputFormatters,
      textAlign: widget.textAlign,
      style: widget.style,
      maxLines: widget.maxLines,
      decoration: widget.decoration,
      onChanged: widget.onChanged,
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature(this.label, this.name);

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 28, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate500)))),
        const SizedBox(height: 4),
        Text(label, style: AppText.body(size: 11, weight: FontWeight.w700, color: AppSurface.muted(context), letterSpacing: 0.3)),
        if (name.isNotEmpty) Text(name, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppSurface.text(context))),
      ],
    );
  }
}
