import 'package:flutter/material.dart';

import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.onBack, required this.onLogout});

  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final store = SchoolScope.of(context);
    final books = store.tables['library_books'] ?? const <Map<String, dynamic>>[];
    final loans = store.tables['book_loans'] ?? const <Map<String, dynamic>>[];
    return Column(
      children: [
        TopBar(
          title: 'Library',
          subtitle: '${books.length} titles · ${store.brandedSchoolName} Library',
          onBack: onBack,
          onLogout: onLogout,
        ),
        Expanded(
          child: books.isEmpty
              ? Center(
                  child: Text('No library books yet.', style: AppText.body(size: 13, color: AppColors.slate500)),
                )
              : ListView.separated(
                  padding: AppLayout.page(context),
                  itemCount: books.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final book = books[i];
                    final loaned = loans.where((item) {
                      final bookId = '${item['library_book_id'] ?? (item['library_book'] is Map ? (item['library_book'] as Map)['id'] : '')}';
                      return bookId == '${book['id']}' && '${item['returned_at'] ?? ''}'.isEmpty;
                    });
                    final loan = loaned.isEmpty ? null : loaned.first;
                    final borrower = loan?['student'] is Map ? '${(loan!['student'] as Map)['full_name'] ?? ''}' : '';
                    final out = loan != null;
                    return WhiteCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          InitialsAvatar(name: '${book['title'] ?? 'Book'}', tone: Tone.honey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${book['title'] ?? ''}', style: AppText.body(weight: FontWeight.w800)),
                                Text('${book['author'] ?? ''}', style: AppText.body(size: 12, color: AppColors.slate400)),
                                if ('${book['isbn'] ?? ''}'.trim().isNotEmpty)
                                  Text('ISBN ${book['isbn']}', style: AppText.body(size: 11, color: AppColors.slate400)),
                                Text(
                                  out ? 'Borrowed · $borrower' : 'On shelf · ${book['available_copies'] ?? book['shelf_location'] ?? ''}',
                                  style: AppText.body(size: 11, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(text: out ? 'Out' : 'In', tone: out ? Tone.honey : Tone.emerald),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
