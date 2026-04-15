import 'dart:convert';

import 'ai_analysis_models.dart';

class AiBookRecord {
  final String aid;
  final String title;
  final String sourceType;
  final String? lastAnalyzedCid;
  final DateTime? lastAnalyzedAt;
  final String latestBookSummary;
  final String latestArcSummary;
  final int characterCount;
  final int relationCount;

  const AiBookRecord({
    required this.aid,
    required this.title,
    required this.sourceType,
    required this.lastAnalyzedCid,
    required this.lastAnalyzedAt,
    required this.latestBookSummary,
    required this.latestArcSummary,
    required this.characterCount,
    required this.relationCount,
  });
}

class AiChapterAnalysisRecord {
  final String aid;
  final String cid;
  final String chapterTitle;
  final int schemaVersion;
  final String status;
  final DateTime? analyzedAt;
  final int promptVersion;
  final int maxRequestTokens;
  final int maxResponseTokens;
  final String summary;
  final List<String> characters;
  final List<AiEntityMention> entities;
  final List<CharacterRelationEdge> relations;
  final String snapshotJsonPath;

  const AiChapterAnalysisRecord({
    required this.aid,
    required this.cid,
    required this.chapterTitle,
    required this.schemaVersion,
    required this.status,
    required this.analyzedAt,
    required this.promptVersion,
    required this.maxRequestTokens,
    required this.maxResponseTokens,
    required this.summary,
    required this.characters,
    required this.entities,
    required this.relations,
    required this.snapshotJsonPath,
  });

  ChapterAnalysisResult toResult() => ChapterAnalysisResult(
        schemaVersion: schemaVersion,
        chapterTitle: chapterTitle,
        analyzedAt: analyzedAt?.toIso8601String() ?? '',
        summary: summary,
        characters: characters,
        entities: entities,
        relations: relations,
      );

  static List<String> decodeStringList(String value) {
    final json = jsonDecode(value);
    if (json is! List) return const [];
    return json.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
  }

  static List<AiEntityMention> decodeEntities(String value) {
    final json = jsonDecode(value);
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((item) => AiEntityMention.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  static List<CharacterRelationEdge> decodeRelations(String value) {
    final json = jsonDecode(value);
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((item) => CharacterRelationEdge.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.from.isNotEmpty && item.to.isNotEmpty && item.displayLabel.isNotEmpty)
        .toList();
  }
}

class AiMemoryRowRecord {
  final int id;
  final String aid;
  final String rowType;
  final String rowKey;
  final String timeSpan;
  final String content;
  final String refCid;
  final int orderNo;
  final DateTime? updatedAt;

  const AiMemoryRowRecord({
    required this.id,
    required this.aid,
    required this.rowType,
    required this.rowKey,
    required this.timeSpan,
    required this.content,
    required this.refCid,
    required this.orderNo,
    required this.updatedAt,
  });
}

class AiCharacterStateRecord {
  final String aid;
  final String name;
  final String aliasesJson;
  final String profileSummary;
  final String firstSeenCid;
  final String lastSeenCid;
  final int appearanceCount;
  final DateTime? updatedAt;
  final String tier;
  final int importanceScore;

  const AiCharacterStateRecord({
    required this.aid,
    required this.name,
    required this.aliasesJson,
    required this.profileSummary,
    required this.firstSeenCid,
    required this.lastSeenCid,
    required this.appearanceCount,
    required this.updatedAt,
    required this.tier,
    required this.importanceScore,
  });

  List<String> get aliases {
    try {
      final decoded = jsonDecode(aliasesJson);
      if (decoded is List) {
        return decoded.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
      }
      if (decoded is Map && decoded['aliases'] is List) {
        return (decoded['aliases'] as List).map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  Map<String, Map<String, dynamic>> get aliasMetadata {
    try {
      final decoded = jsonDecode(aliasesJson);
      if (decoded is Map && decoded['meta'] is Map) {
        final meta = <String, Map<String, dynamic>>{};
        for (final entry in (decoded['meta'] as Map).entries) {
          if (entry.value is Map) {
            meta[entry.key.toString()] = Map<String, dynamic>.from(entry.value as Map);
          }
        }
        return meta;
      }
    } catch (_) {}
    return const <String, Map<String, dynamic>>{};
  }
}

class AiRelationStateRecord {
  final String aid;
  final String fromName;
  final String toName;
  final String relationLabel;
  final String relationSummary;
  final String firstSeenCid;
  final String lastSeenCid;
  final int mentionCount;
  final DateTime? updatedAt;
  final int strengthScore;

  const AiRelationStateRecord({
    required this.aid,
    required this.fromName,
    required this.toName,
    required this.relationLabel,
    required this.relationSummary,
    required this.firstSeenCid,
    required this.lastSeenCid,
    required this.mentionCount,
    required this.updatedAt,
    required this.strengthScore,
  });
}

class AiBookMemorySnapshot {
  final AiBookRecord? book;
  final List<AiMemoryRowRecord> summaries;
  final List<AiMemoryRowRecord> outlines;
  final List<AiCharacterStateRecord> characters;
  final List<AiRelationStateRecord> relations;

  const AiBookMemorySnapshot({
    required this.book,
    required this.summaries,
    required this.outlines,
    required this.characters,
    required this.relations,
  });

  bool get isEmpty => book == null && summaries.isEmpty && outlines.isEmpty && characters.isEmpty && relations.isEmpty;
}
