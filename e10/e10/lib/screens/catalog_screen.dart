import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/popups.dart';
import '../widgets/common.dart';
import '../widgets/txn_tiles.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.onBack, required this.onLogout});

  final VoidCallback onBack;
  final VoidCallback onLogout;

  static const _hiddenKeys = {'id', 'school_id', 'created_at', 'updated_at', 'full_name', 'name', 'title'};

  String _title(Map<String, dynamic> row) {
    for (final key in const ['full_name', 'name', 'title', 'label', 'slug', 'isbn', 'invoice_number']) {
      final value = row[key];
      if (value != null && '$value'.trim().isNotEmpty && value is! Map && value is! List) {
        return '$value';
      }
    }
    return '${row['id'] ?? 'Record'}';
  }

  /// A nested relation (e.g. `academic_year`, `class`, `subject`, `department`)
  /// used to be silently dropped here because it's a Map, not a scalar —
  /// resolve it to whatever name-like field it carries instead of skipping it.
  String? _describe(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      for (final key in const ['full_name', 'name', 'title', 'label']) {
        final text = '${value[key] ?? ''}'.trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }
    if (value is List) {
      final parts = [for (final item in value) _describe(item)].whereType<String>().where((s) => s.isNotEmpty);
      return parts.isEmpty ? null : parts.join(', ');
    }
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  String _detail(Map<String, dynamic> row) {
    final parts = <String>[];
    for (final entry in row.entries) {
      if (_hiddenKeys.contains(entry.key)) continue;
      final text = _describe(entry.value);
      if (text == null) continue;
      parts.add(text);
      if (parts.length >= 6) break;
    }
    return parts.join(' · ');
  }

  String _label(String key) => key.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  void _openDetail(BuildContext context, Map<String, dynamic> row) {
    final rows = <(String, String)>[
      for (final entry in row.entries)
        if (entry.key != 'id') if (_describe(entry.value) case final text?) (_label(entry.key), text),
    ];
    showAppSheet<void>(
      context: context,
      title: _title(row),
      builder: (context) => TxnInfoCard(rows: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final rows = store.tables[store.catalogKey] ?? const <Map<String, dynamic>>[];
    return Column(
      children: [
        TopBar(
          title: store.catalogTitle,
          subtitle: '${rows.length} records · ${store.catalogKey.replaceAll('_', ' ')}',
          onBack: onBack,
          onLogout: onLogout,
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    store.loading ? 'Loading school records...' : 'No records in this table yet.',
                    style: AppText.body(size: 13, color: AppColors.slate500),
                  ),
                )
              : ListView.separated(
                  padding: AppLayout.page(context),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        onTap: () => _openDetail(context, row),
                        child: WhiteCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              InitialsAvatar(name: _title(row), tone: Tone.sky),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_title(row), style: AppText.body(weight: FontWeight.w800)),
                                    if (_detail(row).isNotEmpty)
                                      Text(
                                        _detail(row),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.body(size: 11, color: AppColors.slate400),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppColors.slate300),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
