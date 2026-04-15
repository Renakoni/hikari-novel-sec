import 'package:flutter/material.dart';
import 'package:hikari_novel_flutter/service/ai/ai_analysis_service.dart';
import 'package:hikari_novel_flutter/service/ai/ai_memory_models.dart';

class AiBookMemoryPage extends StatelessWidget {
  final String aid;

  const AiBookMemoryPage({super.key, required this.aid});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: FutureBuilder<AiBookMemorySnapshot>(
          future: AiAnalysisService.instance.getBookMemorySnapshot(aid),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final title = data?.book?.title.trim().isNotEmpty == true ? data!.book!.title.trim() : '\u672c\u4e66 AI \u8bb0\u5fc6';
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar.large(
                    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    titleSpacing: 0,
                    forceElevated: innerBoxIsScrolled,
                    bottom: const TabBar(
                      tabs: [
                        Tab(text: '\u6982\u89c8'),
                        Tab(text: '\u4eba\u7269'),
                        Tab(text: '\u5173\u7cfb'),
                      ],
                    ),
                  ),
                ];
              },
              body: _buildBody(context, snapshot, data),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<AiBookMemorySnapshot> snapshot, AiBookMemorySnapshot? data) {
    if (snapshot.connectionState != ConnectionState.done && data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null || data.isEmpty) {
      return const _EmptyMemoryPanel();
    }

    final sortedCharacters = [...data.characters]
      ..sort((a, b) {
        final tierCompare = _tierWeight(b.tier).compareTo(_tierWeight(a.tier));
        if (tierCompare != 0) return tierCompare;
        return b.importanceScore.compareTo(a.importanceScore);
      });
    final sortedRelations = [...data.relations]
      ..sort((a, b) {
        final strengthCompare = b.strengthScore.compareTo(a.strengthScore);
        if (strengthCompare != 0) return strengthCompare;
        return b.mentionCount.compareTo(a.mentionCount);
      });

    return TabBarView(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _BookStatusCard(book: data.book),
            const SizedBox(height: 14),
            if (data.outlines.isNotEmpty) ...[
              const _SectionTitle(icon: Icons.route_outlined, title: '\u603b\u4f53\u5927\u7eb2'),
              const SizedBox(height: 8),
              ...data.outlines.reversed.take(20).map((item) => _MemoryRowTile(item: item)),
              const SizedBox(height: 18),
            ],
            if (data.summaries.isNotEmpty) ...[
              const _SectionTitle(icon: Icons.notes_outlined, title: '\u7ae0\u8282\u7eaa\u8981'),
              const SizedBox(height: 8),
              ...data.summaries.reversed.take(30).map((item) => _MemoryRowTile(item: item)),
            ],
          ],
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _SectionTitle(icon: Icons.people_outline, title: '\u4eba\u7269\u72b6\u6001'),
            const SizedBox(height: 8),
            ...sortedCharacters.map((item) => _CharacterTile(item: item)),
          ],
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _SectionTitle(icon: Icons.account_tree_outlined, title: '\u5173\u7cfb\u72b6\u6001'),
            const SizedBox(height: 8),
            ...sortedRelations.map((item) => _RelationStateTile(item: item)),
          ],
        ),
      ],
    );
  }

  int _tierWeight(String tier) {
    switch (tier) {
      case 'core':
        return 3;
      case 'active':
        return 2;
      case 'transient':
        return 1;
      default:
        return 0;
    }
  }
}

class _BookStatusCard extends StatelessWidget {
  final AiBookRecord? book;

  const _BookStatusCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('\u8bb0\u5fc6\u6982\u89c8', style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            book?.latestBookSummary.trim().isNotEmpty == true ? book!.latestBookSummary.trim() : '\u8fd8\u6ca1\u6709\u4e66\u7ea7\u6458\u8981\u3002',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(text: book?.sourceType.isNotEmpty == true ? book!.sourceType : 'unknown'),
              _StatusChip(text: '${book?.characterCount ?? 0} \u4eba\u7269'),
              _StatusChip(text: '${book?.relationCount ?? 0} \u5173\u7cfb'),
              if (book?.lastAnalyzedCid?.isNotEmpty == true) _StatusChip(text: '\u6700\u8fd1 ${book!.lastAnalyzedCid}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: colorScheme.onSecondaryContainer)),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  final AiCharacterStateRecord item;

  const _CharacterTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.name, style: Theme.of(context).textTheme.titleSmall)),
                const SizedBox(width: 8),
                _StatusChip(text: _tierLabel(item.tier)),
                const SizedBox(width: 8),
                _StatusChip(text: '${item.importanceScore}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\u51fa\u73b0 ${item.appearanceCount} \u6b21\uff0c\u6700\u8fd1\u7ae0\u8282 ${item.lastSeenCid}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.aliases.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('\u522b\u540d\uff1a${item.aliases.join(' / ')}', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (item.profileSummary.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.profileSummary.trim(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'core':
        return '\u6838\u5fc3';
      case 'transient':
        return '\u77ac\u65f6';
      default:
        return '\u6d3b\u8dc3';
    }
  }
}

class _RelationStateTile extends StatelessWidget {
  final AiRelationStateRecord item;

  const _RelationStateTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(item.fromName, style: Theme.of(context).textTheme.titleSmall),
                Icon(Icons.arrow_forward, size: 16, color: colorScheme.primary),
                _StatusChip(text: item.relationLabel),
                Text(item.toName, style: Theme.of(context).textTheme.titleSmall),
                _StatusChip(text: '\u5f3a\u5ea6 ${item.strengthScore}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.relationSummary.trim().isEmpty ? item.relationLabel : item.relationSummary.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              '\u51fa\u73b0 ${item.mentionCount} \u6b21\uff0c\u6700\u8fd1\u7ae0\u8282 ${item.lastSeenCid}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryRowTile extends StatelessWidget {
  final AiMemoryRowRecord item;

  const _MemoryRowTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.timeSpan, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(item.content, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55)),
          ],
        ),
      ),
    );
  }
}

class _EmptyMemoryPanel extends StatelessWidget {
  const _EmptyMemoryPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('\u8fd9\u672c\u4e66\u8fd8\u6ca1\u6709\u79ef\u7d2f AI \u8bb0\u5fc6\u3002\u5148\u5206\u6790\u51e0\u7ae0\u518d\u6765\u770b\u3002')),
            ],
          ),
        ),
      ),
    );
  }
}
