import 'package:flutter/material.dart';
import 'package:hikari_novel_flutter/service/ai/ai_analysis_service.dart';
import 'package:hikari_novel_flutter/service/ai/ai_memory_models.dart';
import 'package:hikari_novel_flutter/service/db_service.dart';

import '../../../common/database/database.dart';
import '../../../router/app_sub_router.dart';
import '../../../widgets/book_cover_image.dart';
import '../../../widgets/state_page.dart';

class AiBookshelfPage extends StatelessWidget {
  const AiBookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 记忆书架'), titleSpacing: 0),
      body: FutureBuilder<_AiBookshelfData>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingPage();
          }
          if (snapshot.hasError) {
            return ErrorMessage(msg: snapshot.error.toString(), action: null);
          }
          final data = snapshot.data;
          if (data == null || data.items.isEmpty) {
            return const EmptyPage();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemBuilder: (context, index) => _AiBookCard(item: data.items[index]),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: data.items.length,
          );
        },
      ),
    );
  }

  Future<_AiBookshelfData> _loadData() async {
    final aiBooks = await AiAnalysisService.instance.getAiBooks();
    final bookshelfEntries = await DBService.instance.getAllBookshelf();
    final byAid = {for (final item in bookshelfEntries) item.aid: item};

    final items = aiBooks
        .map((book) => _AiBookshelfItem(book: book, bookshelfEntry: byAid[book.aid]))
        .toList();
    return _AiBookshelfData(items: items);
  }
}

class _AiBookshelfData {
  final List<_AiBookshelfItem> items;

  const _AiBookshelfData({required this.items});
}

class _AiBookshelfItem {
  final AiBookRecord book;
  final BookshelfEntityData? bookshelfEntry;

  const _AiBookshelfItem({
    required this.book,
    required this.bookshelfEntry,
  });
}

class _AiBookCard extends StatelessWidget {
  final _AiBookshelfItem item;

  const _AiBookCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastTime = _formatTime(item.book.lastAnalyzedAt);
    final summary = item.book.latestArcSummary.trim().isNotEmpty ? item.book.latestArcSummary.trim() : item.book.latestBookSummary.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => AppSubRouter.toNovelDetail(aid: item.book.aid),
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 68,
                  height: 102,
                  child: BookCoverImage(
                    imageUrl: item.bookshelfEntry?.img ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error) => ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.auto_awesome, color: colorScheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.book.title.trim().isEmpty ? item.book.aid : item.book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(icon: Icons.people_alt_outlined, label: '${item.book.characterCount} 人物'),
                        _InfoChip(icon: Icons.hub_outlined, label: '${item.book.relationCount} 关系'),
                        _InfoChip(
                          icon: item.book.sourceType == 'network' ? Icons.cloud_outlined : Icons.menu_book_outlined,
                          label: item.book.sourceType == 'network' ? '网络' : 'EPUB',
                        ),
                      ],
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      lastTime == null ? '尚未记录分析时间' : '最近分析: $lastTime',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatTime(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
