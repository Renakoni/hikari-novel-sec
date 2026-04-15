import 'package:flutter/material.dart';

import 'package:hikari_novel_flutter/service/ai/ai_analysis_models.dart';

class AiChapterAnalysisPage extends StatelessWidget {
  final ChapterAnalysisResult result;

  const AiChapterAnalysisPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = result.chapterTitle.trim().isEmpty ? '\u672c\u7ae0 AI \u5206\u6790' : result.chapterTitle.trim();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            titleSpacing: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.list(
              children: [
                _SummaryPanel(result: result),
                const SizedBox(height: 14),
                if (result.entities.isNotEmpty) ...[
                  const _SectionTitle(icon: Icons.people_outline, title: '\u4eba\u7269'),
                  const SizedBox(height: 8),
                  ...result.entities.map((item) => _EntityCard(entity: item)),
                  const SizedBox(height: 18),
                ],
                if (result.relations.isNotEmpty) ...[
                  const _SectionTitle(icon: Icons.account_tree_outlined, title: '\u5173\u7cfb'),
                  const SizedBox(height: 8),
                  ...result.relations.map((item) => _RelationCard(edge: item)),
                ] else
                  const _EmptyRelationPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final ChapterAnalysisResult result;

  const _SummaryPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = '${result.entities.length} \u4eba\u7269 / ${result.relations.length} \u5173\u7cfb';

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
              Icon(Icons.auto_awesome_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('\u7ae0\u8282\u603b\u7ed3', style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            result.summary.trim().isEmpty ? 'AI \u6ca1\u6709\u8fd4\u56de\u7ae0\u8282\u603b\u7ed3\u3002' : result.summary.trim(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.62),
          ),
          const SizedBox(height: 12),
          Text(meta, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
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

class _EntityCard extends StatelessWidget {
  final AiEntityMention entity;

  const _EntityCard({required this.entity});

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
                Expanded(
                  child: Text(
                    entity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                _Chip(text: _tierLabel(entity.tier)),
                const SizedBox(width: 8),
                _Chip(text: '${entity.importanceScore}'),
              ],
            ),
            if (entity.aliases.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '\u522b\u540d\uff1a${entity.aliases.join(' / ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (entity.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entity.summary.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
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

class _RelationCard extends StatelessWidget {
  final CharacterRelationEdge edge;

  const _RelationCard({required this.edge});

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
                Expanded(
                  child: Text(
                    edge.from,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    edge.to,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Chip(text: edge.displayLabel.trim().isEmpty ? '\u5173\u7cfb\u672a\u6807\u6ce8' : edge.displayLabel.trim()),
                _Chip(text: '\u5f3a\u5ea6 ${edge.strengthScore}'),
              ],
            ),
            if (edge.stateSummary.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                edge.stateSummary.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

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

class _EmptyRelationPanel extends StatelessWidget {
  const _EmptyRelationPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree_outlined, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          const Expanded(child: Text('\u8fd9\u4e00\u7ae0\u6ca1\u6709\u63d0\u53d6\u5230\u7a33\u5b9a\u7684\u4eba\u7269\u5173\u7cfb\u3002')),
        ],
      ),
    );
  }
}
