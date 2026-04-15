class ChapterAnalysisResult {
  final int schemaVersion;
  final String chapterTitle;
  final String analyzedAt;
  final String summary;
  final List<String> characters;
  final List<AiEntityMention> entities;
  final List<CharacterRelationEdge> relations;

  const ChapterAnalysisResult({
    required this.schemaVersion,
    required this.chapterTitle,
    required this.analyzedAt,
    required this.summary,
    required this.characters,
    required this.entities,
    required this.relations,
  });

  factory ChapterAnalysisResult.fromJson(Map<String, dynamic> json) {
    final entities = (json['entities'] as List? ?? json['character_profiles'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => AiEntityMention.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();
    final characters = (json['characters'] as List? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final relations = (json['relations'] as List? ?? json['relation_updates'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CharacterRelationEdge.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.from.isNotEmpty && item.to.isNotEmpty && item.displayLabel.isNotEmpty)
        .toList();

    return ChapterAnalysisResult(
      schemaVersion: int.tryParse((json['schemaVersion'] ?? '3').toString()) ?? 3,
      chapterTitle: (json['chapterTitle'] ?? '').toString().trim(),
      analyzedAt: (json['analyzedAt'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
      characters: characters.isNotEmpty ? characters : entities.map((item) => item.name).toList(),
      entities: entities.isNotEmpty
          ? entities
          : characters.map((name) => AiEntityMention(name: name, aliases: const [], tier: 'active', importanceScore: 40, summary: '')).toList(),
      relations: relations,
    );
  }

  ChapterAnalysisResult withMeta({required String chapterTitle}) => ChapterAnalysisResult(
        schemaVersion: 3,
        chapterTitle: chapterTitle.trim(),
        analyzedAt: DateTime.now().toIso8601String(),
        summary: summary,
        characters: characters,
        entities: entities,
        relations: relations,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'chapterTitle': chapterTitle,
        'analyzedAt': analyzedAt,
        'summary': summary,
        'characters': characters,
        'entities': entities.map((item) => item.toJson()).toList(),
        'relations': relations.map((item) => item.toJson()).toList(),
      };
}

class AiEntityMention {
  final String name;
  final List<String> aliases;
  final String tier;
  final int importanceScore;
  final String summary;

  const AiEntityMention({
    required this.name,
    required this.aliases,
    required this.tier,
    required this.importanceScore,
    required this.summary,
  });

  factory AiEntityMention.fromJson(Map<String, dynamic> json) {
    final aliases = (json['aliases'] as List? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return AiEntityMention(
      name: (json['name'] ?? json['canonical_name'] ?? '').toString().trim(),
      aliases: aliases,
      tier: _normalizeTier((json['tier'] ?? json['importance_tier'] ?? '').toString()),
      importanceScore: _normalizeScore(json['importanceScore'] ?? json['importance_score']),
      summary: (json['summary'] ?? json['profile'] ?? '').toString().trim(),
    );
  }

  static String _normalizeTier(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'core':
      case 'active':
      case 'transient':
        return normalized;
      default:
        return 'active';
    }
  }

  static int _normalizeScore(dynamic value) {
    final parsed = int.tryParse((value ?? '').toString()) ?? 40;
    return parsed.clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'aliases': aliases,
        'tier': tier,
        'importance_score': importanceScore,
        'summary': summary,
      };
}

class CharacterRelationEdge {
  final String from;
  final String to;
  final String displayLabel;
  final String stateSummary;
  final int strengthScore;

  const CharacterRelationEdge({
    required this.from,
    required this.to,
    required this.displayLabel,
    required this.stateSummary,
    required this.strengthScore,
  });

  String get action => displayLabel;

  factory CharacterRelationEdge.fromJson(Map<String, dynamic> json) {
    return CharacterRelationEdge(
      from: (json['from'] ?? json['s'] ?? '').toString().trim(),
      to: (json['to'] ?? json['t'] ?? '').toString().trim(),
      displayLabel: (json['display_label'] ?? json['relation'] ?? json['action'] ?? json['r'] ?? '').toString().trim(),
      stateSummary: (json['state_summary'] ?? json['summary'] ?? json['scene'] ?? '').toString().trim(),
      strengthScore: (int.tryParse((json['strength_score'] ?? json['strength'] ?? '').toString()) ?? 50).clamp(0, 100),
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'display_label': displayLabel,
        'relation': displayLabel,
        'action': displayLabel,
        'state_summary': stateSummary,
        'strength_score': strengthScore,
      };
}
