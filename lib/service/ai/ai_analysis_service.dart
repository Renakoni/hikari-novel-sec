import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../common/ai_debug_logger.dart';
import '../db_service.dart';
import '../local_book_service.dart';
import '../local_storage_service.dart';
import 'ai_analysis_models.dart';
import 'ai_chat_provider.dart';
import 'ai_memory_models.dart';
import 'ai_provider_config.dart';

class AiAnalysisService extends GetxService {
  static AiAnalysisService get instance => Get.find<AiAnalysisService>();
  static const int _memorySummaryMaxChars = 400;

  final enabled = false.obs;
  final provider = 'siliconflow'.obs;
  final baseUrl = 'https://api.siliconflow.cn/v1'.obs;
  final apiKey = ''.obs;
  final model = 'Qwen/Qwen3-8B'.obs;
  final temperature = 0.2.obs;
  final maxRequestTokens = 60000.obs;
  final maxTokens = 30000.obs;
  final systemPrompt = ''.obs;
  final userPromptTemplate = ''.obs;
  final mergeSystemPrompt = ''.obs;
  final models = <String>[].obs;

  final AiChatProvider _provider = AiChatProvider();

  void init() {
    final storage = LocalStorageService.instance;
    enabled.value = storage.getAiAnalysisEnabled();
    provider.value = storage.getAiAnalysisProvider();
    baseUrl.value = storage.getAiAnalysisBaseUrl();
    apiKey.value = storage.getAiAnalysisApiKey();
    model.value = storage.getAiAnalysisModel();
    temperature.value = storage.getAiAnalysisTemperature();
    maxRequestTokens.value = storage.getAiAnalysisMaxRequestTokens();
    maxTokens.value = storage.getAiAnalysisMaxResponseTokens();
    systemPrompt.value = storage.getAiAnalysisSystemPrompt();
    userPromptTemplate.value = storage.getAiAnalysisUserPromptTemplate();
    mergeSystemPrompt.value = storage.getAiAnalysisMergeSystemPrompt();
  }

  AiProviderConfig get config => AiProviderConfig(
        enabled: enabled.value,
        provider: provider.value,
        baseUrl: baseUrl.value,
        apiKey: apiKey.value,
        model: model.value,
        temperature: temperature.value,
        maxTokens: maxTokens.value,
      );

  void setEnabled(bool value) {
    enabled.value = value;
    LocalStorageService.instance.setAiAnalysisEnabled(value);
  }

  void setProvider(String value) {
    provider.value = value.trim().isEmpty ? 'custom' : value.trim();
    LocalStorageService.instance.setAiAnalysisProvider(provider.value);
  }

  void setBaseUrl(String value) {
    baseUrl.value = value.trim();
    LocalStorageService.instance.setAiAnalysisBaseUrl(baseUrl.value);
  }

  void setApiKey(String value) {
    apiKey.value = value.trim();
    LocalStorageService.instance.setAiAnalysisApiKey(apiKey.value);
  }

  void setModel(String value) {
    model.value = value.trim();
    LocalStorageService.instance.setAiAnalysisModel(model.value);
  }

  void setTemperature(double value) {
    temperature.value = value.clamp(0.0, 2.0).toDouble();
    LocalStorageService.instance.setAiAnalysisTemperature(temperature.value);
  }

  void setMaxTokens(int value) {
    maxTokens.value = value.clamp(256, 30000).toInt();
    LocalStorageService.instance.setAiAnalysisMaxResponseTokens(maxTokens.value);
  }

  void setMaxRequestTokens(int value) {
    maxRequestTokens.value = value.clamp(2000, 60000).toInt();
    LocalStorageService.instance.setAiAnalysisMaxRequestTokens(maxRequestTokens.value);
  }

  void setSystemPrompt(String value) {
    systemPrompt.value = value.trim();
    LocalStorageService.instance.setAiAnalysisSystemPrompt(systemPrompt.value);
  }

  void setUserPromptTemplate(String value) {
    userPromptTemplate.value = value.trim();
    LocalStorageService.instance.setAiAnalysisUserPromptTemplate(userPromptTemplate.value);
  }

  void setMergeSystemPrompt(String value) {
    mergeSystemPrompt.value = value.trim();
    LocalStorageService.instance.setAiAnalysisMergeSystemPrompt(mergeSystemPrompt.value);
  }

  void resetPrompts() {
    setSystemPrompt('');
    setUserPromptTemplate('');
    setMergeSystemPrompt('');
  }

  String get effectiveSystemPrompt => _withChineseOutputRule(
        systemPrompt.value.trim().isEmpty ? _chapterAnalysisSystemPrompt : systemPrompt.value.trim(),
      );

  String get effectiveUserPromptTemplate =>
      userPromptTemplate.value.trim().isEmpty ? _chapterAnalysisUserPromptTemplate : userPromptTemplate.value.trim();

  String get effectiveMergeSystemPrompt => _withChineseOutputRule(
        mergeSystemPrompt.value.trim().isEmpty ? _chapterMergeSystemPrompt : mergeSystemPrompt.value.trim(),
      );

  String _withChineseOutputRule(String prompt) {
    if (prompt.contains('Simplified Chinese') || prompt.contains('\u7b80\u4f53\u4e2d\u6587')) return prompt;
    return '$prompt\n\nOutput language rule:\n'
        '- Keep JSON keys exactly as required, but write all user-facing values in Simplified Chinese.\n'
        '- Preserve source character names and aliases; do not translate established names.\n';
  }

  bool supportsAid(String aid) => LocalBookService.supportsAiAnalysis(aid);

  String renderUserPrompt({
    required String chapterTitle,
    required String chapterText,
    String? recentSummary,
    String? bookMemory,
  }) {
    var text = effectiveUserPromptTemplate;
    final replacements = <String, String>{
      '{{chapterTitle}}': chapterTitle,
      '{{chapterText}}': chapterText,
      '{{recentSummary}}': recentSummary ?? '',
      '{{bookMemory}}': bookMemory ?? '',
    };
    replacements.forEach((key, value) {
      text = text.replaceAll(key, value);
    });
    return text;
  }

  Future<List<String>> fetchModels() async {
    final result = await _provider.fetchModels(config);
    models.assignAll(result);
    return result;
  }

  Future<void> testConnection() => _provider.testConnection(config);

  Future<ChapterAnalysisResult> analyzeChapter({
    required String aid,
    required String cid,
    required String chapterTitle,
    required String chapterText,
  }) async {
    if (!supportsAid(aid)) {
      throw Exception('AI analysis is currently enabled only for network novels and local EPUB books.');
    }
    if (!config.isReady) {
      throw Exception('AI analysis is not configured yet.');
    }

    final normalizedText = _normalizeChapterText(chapterText);
    final chunks = _splitChapterText(normalizedText);
    final input = chunks.length == 1 ? chunks.single.text : normalizedText;
    if (input.trim().isEmpty) {
      throw Exception('Chapter content is empty.');
    }
    final recentSummary = await _buildRecentSummary(aid, excludeCid: cid);
    final bookMemory = await _buildBookMemory(aid);
    final renderedUserPrompt = chunks.length == 1
        ? renderUserPrompt(
            chapterTitle: chapterTitle,
            chapterText: input,
            recentSummary: recentSummary,
            bookMemory: bookMemory,
          )
        : '';

    await AiDebugLogger.log('analyze_chapter_start', {
      'aid': aid,
      'cid': cid,
      'chapterTitle': chapterTitle,
      'originalTextLength': chapterText.length,
      'requestTextLength': chunks.length == 1 ? input.length : chunks.fold<int>(0, (sum, chunk) => sum + chunk.text.length),
      'chunkCount': chunks.length,
      'maxRequestTokens': maxRequestTokens.value,
      'maxResponseTokens': maxTokens.value,
      'systemPromptPreview': AiDebugLogger.preview(effectiveSystemPrompt, max: 1200),
      'recentSummaryPreview': AiDebugLogger.preview(recentSummary, max: 1200),
      'bookMemoryPreview': AiDebugLogger.preview(bookMemory, max: 1200),
      'userPromptPreview': AiDebugLogger.preview(chunks.length == 1 ? renderedUserPrompt : 'long chapter mode; see chunk logs', max: 2000),
    });

    final extracted = chunks.length == 1
        ? await _extractChapterFacts(
            aid: aid,
            cid: cid,
            chapterTitle: chapterTitle,
            renderedUserPrompt: renderedUserPrompt,
          )
        : await _analyzeLongChapterChunks(
            aid: aid,
            cid: cid,
            chapterTitle: chapterTitle,
            chunks: chunks,
            recentSummary: recentSummary,
            bookMemory: bookMemory,
          );
    final merged = await _mergeChapterFacts(
      aid: aid,
      cid: cid,
      chapterTitle: chapterTitle,
      extracted: extracted,
    );
    final normalized = await _canonicalizeResult(aid: aid, cid: cid, result: merged);

    await saveAnalysis(aid: aid, cid: cid, result: normalized);
    await AiDebugLogger.log('analyze_chapter_done', {
      'aid': aid,
      'cid': cid,
      'summaryLength': normalized.summary.length,
      'charactersCount': normalized.characters.length,
      'entitiesCount': normalized.entities.length,
      'relationsCount': normalized.relations.length,
      'analysisPath': (await _analysisFile(aid: aid, cid: cid)).path,
    });
    return normalized;
  }

  Future<ChapterAnalysisResult> _extractChapterFacts({
    required String aid,
    required String cid,
    required String chapterTitle,
    required String renderedUserPrompt,
  }) async {
    final raw = await _provider.chat(
      config: config,
      messages: [
        {'role': 'system', 'content': effectiveSystemPrompt},
        {'role': 'user', 'content': renderedUserPrompt},
      ],
    );
    final parsed = ChapterAnalysisResult.fromJson(_parseJsonObject(raw)).withMeta(chapterTitle: chapterTitle);
    await AiDebugLogger.log('analyze_chapter_extract_done', {
      'aid': aid,
      'cid': cid,
      'summaryLength': parsed.summary.length,
      'charactersCount': parsed.characters.length,
      'entitiesCount': parsed.entities.length,
      'relationsCount': parsed.relations.length,
    });
    return parsed;
  }

  Future<ChapterAnalysisResult> _analyzeLongChapterChunks({
    required String aid,
    required String cid,
    required String chapterTitle,
    required List<_ChapterTextChunk> chunks,
    required String recentSummary,
    required String bookMemory,
  }) async {
    await AiDebugLogger.log('analyze_long_chapter_start', {
      'aid': aid,
      'cid': cid,
      'chapterTitle': chapterTitle,
      'chunkCount': chunks.length,
      'chunkLengths': chunks.map((item) => item.text.length).toList(),
    });

    final extracted = <ChapterAnalysisResult>[];
    for (final chunk in chunks) {
      final partTitle = '$chapterTitle (${chunk.index}/${chunk.total})';
      final prompt = renderUserPrompt(
        chapterTitle: partTitle,
        chapterText: chunk.text,
        recentSummary: recentSummary,
        bookMemory: bookMemory,
      );
      await AiDebugLogger.log('analyze_long_chapter_chunk_start', {
        'aid': aid,
        'cid': cid,
        'chunkIndex': chunk.index,
        'chunkTotal': chunk.total,
        'chunkLength': chunk.text.length,
        'promptPreview': AiDebugLogger.preview(prompt, max: 1800),
      });
      final result = await _extractChapterFacts(
        aid: aid,
        cid: '$cid#chunk${chunk.index}',
        chapterTitle: partTitle,
        renderedUserPrompt: prompt,
      );
      extracted.add(result);
    }

    return _mergeChunkResultsRecursively(
      aid: aid,
      cid: cid,
      chapterTitle: chapterTitle,
      results: extracted,
    );
  }

  Future<ChapterAnalysisResult> _mergeChunkResultsRecursively({
    required String aid,
    required String cid,
    required String chapterTitle,
    required List<ChapterAnalysisResult> results,
  }) async {
    if (results.isEmpty) {
      throw Exception('Long chapter analysis produced no chunk results.');
    }
    var current = results;
    var round = 1;
    while (current.length > 1) {
      final groups = _groupChunkResults(current);
      final next = <ChapterAnalysisResult>[];
      for (var i = 0; i < groups.length; i++) {
        final group = groups[i];
        final isFinal = groups.length == 1;
        final merged = await _mergeChunkResultBatch(
          aid: aid,
          cid: cid,
          chapterTitle: chapterTitle,
          results: group,
          round: round,
          batchIndex: i + 1,
          batchCount: groups.length,
          isFinal: isFinal,
        );
        next.add(merged);
      }
      if (next.length == current.length && groups.every((group) => group.length == 1)) {
        return _combineChunkResultsLocally(chapterTitle: chapterTitle, results: next);
      }
      current = next;
      round++;
    }
    return current.single.withMeta(chapterTitle: chapterTitle);
  }

  Future<ChapterAnalysisResult> _mergeChunkResultBatch({
    required String aid,
    required String cid,
    required String chapterTitle,
    required List<ChapterAnalysisResult> results,
    required int round,
    required int batchIndex,
    required int batchCount,
    required bool isFinal,
  }) async {
    final payload = jsonEncode({
      'chapterTitle': chapterTitle,
      'round': round,
      'batchIndex': batchIndex,
      'batchCount': batchCount,
      'isFinal': isFinal,
      'parts': results.map((item) => item.toJson()).toList(),
    });
    final prompt = '''
You are merging structured analyses from consecutive slices of one very long novel chapter.

Return strict JSON only. No markdown. No explanation.

Rules:
- Keep JSON keys in English, but write all user-facing text values in Simplified Chinese.
- Preserve chronology across parts.
- Merge aliases and codenames into stable character entities when the evidence is strong.
- Merge duplicate relationships into one current relationship state.
- Keep only characters, not locations, organizations, or objects.
- Because the source chapter is long, the final summary may be longer than a normal chapter summary.
- For the final merge, write a detailed but readable chapter summary with the major beats in order.
- If this is an intermediate merge, preserve enough detail so the final merge does not lose later events.

<chunk_results_json>
$payload
</chunk_results_json>
''';
    await AiDebugLogger.log('analyze_long_chapter_merge_start', {
      'aid': aid,
      'cid': cid,
      'round': round,
      'batchIndex': batchIndex,
      'batchCount': batchCount,
      'isFinal': isFinal,
      'partCount': results.length,
      'promptLength': prompt.length,
      'promptPreview': AiDebugLogger.preview(prompt, max: 2200),
    });

    try {
      final raw = await _provider.chat(
        config: config,
        messages: [
          {'role': 'system', 'content': effectiveMergeSystemPrompt},
          {'role': 'user', 'content': prompt},
        ],
      );
      final merged = ChapterAnalysisResult.fromJson(_parseJsonObject(raw)).withMeta(
        chapterTitle: isFinal ? chapterTitle : '$chapterTitle merge $round-$batchIndex',
      );
      await AiDebugLogger.log('analyze_long_chapter_merge_done', {
        'aid': aid,
        'cid': cid,
        'round': round,
        'batchIndex': batchIndex,
        'summaryLength': merged.summary.length,
        'entitiesCount': merged.entities.length,
        'relationsCount': merged.relations.length,
      });
      return merged;
    } catch (e) {
      await AiDebugLogger.log('analyze_long_chapter_merge_fallback', {
        'aid': aid,
        'cid': cid,
        'round': round,
        'batchIndex': batchIndex,
        'error': e.toString(),
      });
      return _combineChunkResultsLocally(
        chapterTitle: isFinal ? chapterTitle : '$chapterTitle merge $round-$batchIndex',
        results: results,
      );
    }
  }

  List<List<ChapterAnalysisResult>> _groupChunkResults(List<ChapterAnalysisResult> results) {
    final maxPayloadChars = _requestTextBudget();
    final groups = <List<ChapterAnalysisResult>>[];
    var current = <ChapterAnalysisResult>[];
    var currentLength = 0;
    for (final result in results) {
      final length = jsonEncode(result.toJson()).length;
      final shouldStartNext = current.isNotEmpty && (current.length >= 5 || currentLength + length > maxPayloadChars);
      if (shouldStartNext) {
        groups.add(current);
        current = <ChapterAnalysisResult>[];
        currentLength = 0;
      }
      current.add(result);
      currentLength += length;
    }
    if (current.isNotEmpty) groups.add(current);
    return groups;
  }

  ChapterAnalysisResult _combineChunkResultsLocally({
    required String chapterTitle,
    required List<ChapterAnalysisResult> results,
  }) {
    final entities = <String, AiEntityMention>{};
    final relations = <String, CharacterRelationEdge>{};
    for (final result in results) {
      for (final entity in result.entities) {
        final key = _normalizeName(entity.name);
        final existing = entities[key];
        final aliases = {
          ...?existing?.aliases,
          ...entity.aliases,
        }.where((item) => item.trim().isNotEmpty && item.trim() != entity.name).toList();
        entities[key] = AiEntityMention(
          name: existing?.name ?? entity.name,
          aliases: aliases,
          tier: _pickTier(existing?.tier ?? entity.tier, entity.tier),
          importanceScore: mathMax(existing?.importanceScore ?? 0, entity.importanceScore),
          summary: _mergeSummary(existing?.summary ?? '', entity.summary),
        );
      }
      for (final edge in result.relations) {
        final endpoints = _normalizeRelationEndpoints(edge.from, edge.to, edge.displayLabel);
        final key = '${_normalizeName(endpoints.$1)}=>${_normalizeName(endpoints.$2)}';
        final existing = relations[key];
        relations[key] = CharacterRelationEdge(
          from: endpoints.$1,
          to: endpoints.$2,
          displayLabel: existing == null ? edge.displayLabel : _pickRelationLabel(existing.displayLabel, edge.displayLabel),
          stateSummary: _mergeRelationSummary(existing?.stateSummary ?? '', edge.stateSummary, edge.displayLabel),
          strengthScore: mathMax(existing?.strengthScore ?? 0, edge.strengthScore),
        );
      }
    }
    final summary = results.asMap().entries.map((entry) {
      final summary = entry.value.summary.trim();
      if (summary.isEmpty) return '';
      return '【片段 ${entry.key + 1}】$summary';
    }).where((item) => item.isNotEmpty).join('\n\n');
    final entityList = entities.values.toList()
      ..sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
    return ChapterAnalysisResult(
      schemaVersion: 3,
      chapterTitle: chapterTitle,
      analyzedAt: DateTime.now().toIso8601String(),
      summary: summary,
      characters: entityList.map((item) => item.name).toList(),
      entities: entityList,
      relations: relations.values.toList(),
    );
  }

  Future<ChapterAnalysisResult> _mergeChapterFacts({
    required String aid,
    required String cid,
    required String chapterTitle,
    required ChapterAnalysisResult extracted,
  }) async {
    final characterStates = await DBService.instance.getAiCharacterStates(aid);
    final relationStates = await DBService.instance.getAiRelationStates(aid);
    final recentSummary = await _buildRecentSummary(aid, excludeCid: cid);
    final mergePrompt = _buildMergePrompt(
      chapterTitle: chapterTitle,
      extracted: extracted,
      characterStates: characterStates,
      relationStates: relationStates,
      recentSummary: recentSummary,
    );

    await AiDebugLogger.log('analyze_chapter_merge_start', {
      'aid': aid,
      'cid': cid,
      'mergePromptPreview': AiDebugLogger.preview(mergePrompt.prompt, max: 2200),
      'recentSummaryPreview': AiDebugLogger.preview(recentSummary, max: 1200),
      'knownCharacters': characterStates.length,
      'knownRelations': relationStates.length,
      'focusEntitiesCount': mergePrompt.focusEntitiesCount,
      'relevantEntitiesCount': mergePrompt.relevantEntitiesCount,
      'pairRelationsCount': mergePrompt.pairRelationsCount,
      'relevantRelationsCount': mergePrompt.relevantRelationsCount,
      'selectedRelationsCount': mergePrompt.selectedRelationsCount,
    });

    try {
      final raw = await _provider.chat(
        config: config,
        messages: [
          {'role': 'system', 'content': effectiveMergeSystemPrompt},
          {'role': 'user', 'content': mergePrompt.prompt},
        ],
      );
      final merged = ChapterAnalysisResult.fromJson(_parseJsonObject(raw)).withMeta(chapterTitle: chapterTitle);
      await AiDebugLogger.log('analyze_chapter_merge_done', {
        'aid': aid,
        'cid': cid,
        'summaryLength': merged.summary.length,
        'charactersCount': merged.characters.length,
        'entitiesCount': merged.entities.length,
        'relationsCount': merged.relations.length,
      });
      return merged;
    } catch (e) {
      await AiDebugLogger.log('analyze_chapter_merge_fallback', {
        'aid': aid,
        'cid': cid,
        'error': e.toString(),
      });
      return extracted;
    }
  }

  Future<ChapterAnalysisResult?> loadAnalysis({required String aid, required String cid}) async {
    final file = await _analysisFile(aid: aid, cid: cid);
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      if (json is Map) {
        return ChapterAnalysisResult.fromJson(Map<String, dynamic>.from(json));
      }
    }
    final dbRecord = await DBService.instance.getAiChapterAnalysis(aid, cid);
    return dbRecord?.toResult();
  }

  Future<void> saveAnalysis({required String aid, required String cid, required ChapterAnalysisResult result}) async {
    final file = await _analysisFile(aid: aid, cid: cid);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(result.toJson()), flush: true);
    await DBService.instance.upsertAiChapterAnalysis(
      aid: aid,
      cid: cid,
      chapterTitle: result.chapterTitle,
      result: result,
      promptVersion: 2,
      maxRequestTokens: maxRequestTokens.value,
      maxResponseTokens: maxTokens.value,
      snapshotJsonPath: file.path,
    );
    await _syncBookMemory(aid: aid, cid: cid, result: result);
  }

  Future<String> analysisPath({required String aid, required String cid}) async => (await _analysisFile(aid: aid, cid: cid)).path;

  Future<List<AiBookRecord>> getAiBooks() => DBService.instance.getAiBooks();

  Future<void> clearBookAnalysis(String aid) async {
    await DBService.instance.deleteAiAnalysisByAid(aid);
    final dir = await getApplicationSupportDirectory();
    final analysisDir = Directory(path.join(dir.path, 'ai_analysis', aid));
    if (await analysisDir.exists()) {
      await analysisDir.delete(recursive: true);
    }
  }

  Future<List<AiMemoryRowRecord>> getBookMemoryRows(String aid, {String? rowType}) => DBService.instance.getAiMemoryRows(aid, rowType: rowType);

  Future<String> getRecentSummaryPreview(String aid, {String? excludeCid}) => _buildRecentSummary(aid, excludeCid: excludeCid);

  Future<String> getBookMemoryPreview(String aid) => _buildBookMemory(aid);

  Future<String> renderMergePromptPreview({
    required String aid,
    required String cid,
    required String chapterTitle,
  }) async {
    final extracted = await loadAnalysis(aid: aid, cid: cid);
    if (extracted == null) {
      throw Exception('No cached analysis for this chapter. Analyze the chapter first.');
    }
    final recentSummary = await _buildRecentSummary(aid, excludeCid: cid);
    final characterStates = await DBService.instance.getAiCharacterStates(aid);
    final relationStates = await DBService.instance.getAiRelationStates(aid);
    return _buildMergePrompt(
      chapterTitle: chapterTitle,
      extracted: extracted,
      characterStates: characterStates,
      relationStates: relationStates,
      recentSummary: recentSummary,
    ).prompt;
  }

  Future<AiBookMemorySnapshot> getBookMemorySnapshot(String aid) async {
    final book = await DBService.instance.getAiBook(aid);
    final summaries = await DBService.instance.getAiMemoryRows(aid, rowType: 'summary');
    final outlines = await DBService.instance.getAiMemoryRows(aid, rowType: 'outline');
    final characters = await DBService.instance.getAiCharacterStates(aid);
    final relations = await DBService.instance.getAiRelationStates(aid);
    return AiBookMemorySnapshot(
      book: book,
      summaries: summaries,
      outlines: outlines,
      characters: characters,
      relations: relations,
    );
  }

  Future<File> _analysisFile({required String aid, required String cid}) async {
    final dir = await getApplicationSupportDirectory();
    return File(path.join(dir.path, 'ai_analysis', aid, '$cid.json'));
  }

  String _normalizeChapterText(String value) => value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  int _requestTextBudget() => (maxRequestTokens.value.clamp(2000, 60000) * 0.8).floor().clamp(1600, 48000).toInt();

  List<_ChapterTextChunk> _splitChapterText(String value) {
    final normalized = _normalizeChapterText(value);
    if (normalized.isEmpty) return const [];
    final maxChars = _requestTextBudget();
    if (normalized.length <= maxChars) {
      return [_ChapterTextChunk(index: 1, total: 1, text: normalized)];
    }

    final chunks = <String>[];
    var start = 0;
    while (start < normalized.length) {
      var end = (start + maxChars).clamp(0, normalized.length).toInt();
      if (end < normalized.length) {
        end = _findChunkBoundary(normalized, start, end, maxChars);
      }
      final chunk = normalized.substring(start, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      start = end;
      while (start < normalized.length && normalized.codeUnitAt(start) <= 32) {
        start++;
      }
    }

    return [
      for (var i = 0; i < chunks.length; i++) _ChapterTextChunk(index: i + 1, total: chunks.length, text: chunks[i]),
    ];
  }

  int _findChunkBoundary(String text, int start, int idealEnd, int maxChars) {
    final minEnd = start + (maxChars * 0.55).floor();
    final searchStart = mathMax(start, idealEnd - (maxChars * 0.35).floor());
    final patterns = [
      RegExp(r'[。！？!?][」』”’）\)]?\n+'),
      RegExp(r'\n{2,}'),
      RegExp(r'[。！？!?][」』”’）\)]?'),
      RegExp(r'\n+'),
    ];
    for (final pattern in patterns) {
      final matches = pattern.allMatches(text, searchStart).where((match) => match.end <= idealEnd && match.end >= minEnd).toList();
      if (matches.isNotEmpty) return matches.last.end;
    }
    return idealEnd;
  }

  Map<String, dynamic> _parseJsonObject(String raw) {
    var text = raw.trim().replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '').replaceFirst(RegExp(r'\s*```$'), '').trim();
    try {
      final value = jsonDecode(text);
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {}

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      text = text.substring(start, end + 1).replaceAllMapped(RegExp(r',(\s*[}\]])'), (match) => match.group(1) ?? '');
      final value = jsonDecode(text);
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    throw Exception('AI did not return valid JSON.');
  }

  Future<ChapterAnalysisResult> _canonicalizeResult({
    required String aid,
    required String cid,
    required ChapterAnalysisResult result,
  }) async {
    final existingStates = await DBService.instance.getAiCharacterStates(aid);
    final aliasToCanonical = <String, String>{};
    for (final item in existingStates) {
      aliasToCanonical[_normalizeName(item.name)] = item.name;
      for (final alias in item.aliases) {
        aliasToCanonical[_normalizeName(alias)] = item.name;
      }
    }

    final mergedEntities = <String, AiEntityMention>{};

    void registerEntity(AiEntityMention entity) {
      final canonical = _resolveCanonicalName(entity.name, entity.aliases, aliasToCanonical);
      final existing = mergedEntities[canonical];
      final mergedAliases = {...?existing?.aliases, ...entity.aliases, entity.name}..removeWhere((item) => item.trim().isEmpty || item == canonical);
      final mergedTier = _pickTier(existing?.tier, entity.tier);
      final mergedScore = mathMax(existing?.importanceScore ?? 0, entity.importanceScore);
      final mergedSummary = _capMemorySummary(_mergeSummary(existing?.summary ?? '', entity.summary));
      mergedEntities[canonical] = AiEntityMention(
        name: canonical,
        aliases: mergedAliases.toList()..sort(),
        tier: mergedTier,
        importanceScore: mergedScore,
        summary: mergedSummary,
      );
      aliasToCanonical[_normalizeName(canonical)] = canonical;
      for (final alias in mergedAliases) {
        aliasToCanonical[_normalizeName(alias)] = canonical;
      }
    }

    for (final entity in result.entities) {
      registerEntity(entity);
    }
    for (final character in result.characters) {
      registerEntity(AiEntityMention(name: character, aliases: const [], tier: 'active', importanceScore: 40, summary: ''));
    }

    final relationDensity = <String, int>{};
    final relationMap = <String, CharacterRelationEdge>{};
    for (final edge in result.relations) {
      final canonicalFrom = _resolveCanonicalName(edge.from, const [], aliasToCanonical);
      final canonicalTo = _resolveCanonicalName(edge.to, const [], aliasToCanonical);
      if (canonicalFrom.isEmpty || canonicalTo.isEmpty) continue;
      if (!mergedEntities.containsKey(canonicalFrom)) {
        registerEntity(AiEntityMention(name: canonicalFrom, aliases: const [], tier: 'transient', importanceScore: 25, summary: ''));
      }
      if (!mergedEntities.containsKey(canonicalTo)) {
        registerEntity(AiEntityMention(name: canonicalTo, aliases: const [], tier: 'transient', importanceScore: 25, summary: ''));
      }
      final endpoints = _normalizeRelationEndpoints(canonicalFrom, canonicalTo, edge.displayLabel);
      final from = endpoints.$1;
      final to = endpoints.$2;
      if (from.isEmpty || to.isEmpty || from == to) continue;
      final label = edge.displayLabel.trim();
      if (label.isEmpty) continue;
      relationDensity[from] = (relationDensity[from] ?? 0) + 1;
      relationDensity[to] = (relationDensity[to] ?? 0) + 1;
      final key = '$from=>$to';
      final existing = relationMap[key];
      relationMap[key] = CharacterRelationEdge(
        from: from,
        to: to,
        displayLabel: existing == null ? label : _pickRelationLabel(existing.displayLabel, label),
        stateSummary: _mergeRelationSummary(existing?.stateSummary ?? '', edge.stateSummary, label),
        strengthScore: mathMax(existing?.strengthScore ?? 0, edge.strengthScore),
      );
    }
    final normalizedRelations = relationMap.values.toList()
      ..sort((a, b) => b.strengthScore.compareTo(a.strengthScore));

    final normalizedEntities = mergedEntities.values.map((entity) {
      final score = _deriveImportanceScore(entity: entity, summary: result.summary, relationDensity: relationDensity[entity.name] ?? 0);
      return AiEntityMention(
        name: entity.name,
        aliases: entity.aliases,
        tier: _deriveTier(entity.tier, score),
        importanceScore: score,
        summary: entity.summary,
      );
    }).toList()
      ..sort((a, b) => b.importanceScore.compareTo(a.importanceScore));

    return ChapterAnalysisResult(
      schemaVersion: 3,
      chapterTitle: result.chapterTitle,
      analyzedAt: result.analyzedAt,
      summary: result.summary,
      characters: normalizedEntities.map((item) => item.name).toList(),
      entities: normalizedEntities,
      relations: normalizedRelations,
    );
  }

  String _resolveCanonicalName(String name, List<String> aliases, Map<String, String> aliasToCanonical) {
    final normalized = _normalizeName(name);
    if (normalized.isEmpty) return name.trim();
    final direct = aliasToCanonical[normalized];
    if (direct != null) return direct;
    for (final alias in aliases) {
      final match = aliasToCanonical[_normalizeName(alias)];
      if (match != null) return match;
    }
    return name.trim();
  }

  int _deriveImportanceScore({
    required AiEntityMention entity,
    required String summary,
    required int relationDensity,
  }) {
    var score = entity.importanceScore;
    if (_summaryMentions(summary, entity.name, entity.aliases)) score += 20;
    score += relationDensity * 8;
    if (entity.aliases.length >= 2) score += 10;
    return score.clamp(0, 100);
  }

  String _deriveTier(String hintedTier, int score) {
    if (hintedTier == 'core' || score >= 78) return 'core';
    if (hintedTier == 'transient' && score < 30) return 'transient';
    if (score < 32) return 'transient';
    return 'active';
  }

  bool _summaryMentions(String summary, String name, List<String> aliases) {
    if (summary.contains(name)) return true;
    return aliases.any(summary.contains);
  }

  String _pickTier(String? a, String b) {
    const weight = {'transient': 0, 'active': 1, 'core': 2};
    final left = weight[a ?? 'active'] ?? 1;
    final right = weight[b] ?? 1;
    return left >= right ? (a ?? 'active') : b;
  }

  String _pickRelationLabel(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    if (left == right) return left;
    if (left == 'complicated' || left == '复杂关系') return left;
    if (right == 'complicated' || right == '复杂关系') return right;
    if (right.length < left.length) return right;
    return left;
  }

  (String, String) _normalizeRelationEndpoints(String from, String to, String label) {
    if (!_isSymmetricRelation(label)) return (from, to);
    return from.compareTo(to) <= 0 ? (from, to) : (to, from);
  }

  bool _isSymmetricRelation(String label) {
    final value = label.trim().toLowerCase();
    const symmetric = {
      'friend',
      'ally',
      'rival',
      'hostile',
      'family',
      'complicated',
      '朋友',
      '同盟',
      '盟友',
      '对立',
      '敌对',
      '家人',
      '家族',
      '复杂关系',
    };
    return symmetric.contains(value);
  }

  String _mergeSummary(String oldSummary, String newSummary) {
    if (oldSummary.trim().isEmpty) return newSummary.trim();
    if (newSummary.trim().isEmpty) return oldSummary.trim();
    if (oldSummary.contains(newSummary)) return oldSummary.trim();
    if (newSummary.contains(oldSummary)) return newSummary.trim();
    return '$oldSummary\n$newSummary'.trim();
  }

  String _capMemorySummary(String value) => _capText(value, maxChars: _memorySummaryMaxChars);

  Future<void> _syncBookMemory({
    required String aid,
    required String cid,
    required ChapterAnalysisResult result,
  }) async {
    final title = await _resolveBookTitle(aid);
    final sourceType = LocalBookService.isLocalAid(aid) ? 'epub' : 'network';
    final summaryRows = await DBService.instance.getAiMemoryRows(aid, rowType: 'summary');
    final matchingRows = summaryRows.where((item) => item.rowKey == cid).toList();
    final existing = matchingRows.isEmpty ? null : matchingRows.first;
    final nextOrder = existing?.orderNo ?? (summaryRows.length + 1);
    final timeSpan = result.chapterTitle.isEmpty ? cid : result.chapterTitle;

    await DBService.instance.upsertAiMemoryRow(
      aid: aid,
      rowType: 'summary',
      rowKey: cid,
      timeSpan: timeSpan,
      content: result.summary,
      refCid: cid,
      orderNo: nextOrder,
    );
    await DBService.instance.upsertAiMemoryRow(
      aid: aid,
      rowType: 'outline',
      rowKey: cid,
      timeSpan: timeSpan,
      content: _outlineFromSummary(result.summary),
      refCid: cid,
      orderNo: nextOrder,
    );

    await _syncCharacterAndRelationStates(aid: aid, cid: cid, result: result);
    final totalCharacters = (await DBService.instance.getAiCharacterStates(aid)).length;
    final totalRelations = (await DBService.instance.getAiRelationStates(aid)).length;
    await DBService.instance.upsertAiBook(
      aid: aid,
      title: title,
      sourceType: sourceType,
      lastAnalyzedCid: cid,
      lastAnalyzedAt: DateTime.tryParse(result.analyzedAt),
      latestBookSummary: result.summary,
      latestArcSummary: _outlineFromSummary(result.summary),
      characterCount: totalCharacters,
      relationCount: totalRelations,
    );
  }

  Future<void> _syncCharacterAndRelationStates({
    required String aid,
    required String cid,
    required ChapterAnalysisResult result,
  }) async {
    final existingCharacters = {for (final item in await DBService.instance.getAiCharacterStates(aid)) item.name: item};
    for (final entity in result.entities) {
      if (entity.tier == 'transient') continue;
      final current = existingCharacters[entity.name];
      final aliases = {...?current?.aliases, ...entity.aliases}.toList()..sort();
      await DBService.instance.upsertAiCharacterState(
        aid: aid,
        name: entity.name,
        aliasesJson: _buildAliasPayload(current?.aliasesJson, aliases),
        profileSummary: _capMemorySummary(_mergeSummary(current?.profileSummary ?? '', entity.summary)),
        firstSeenCid: current?.firstSeenCid.isNotEmpty == true ? current!.firstSeenCid : cid,
        lastSeenCid: cid,
        appearanceCount: (current?.appearanceCount ?? 0) + 1,
        tier: _pickTier(current?.tier, entity.tier),
        importanceScore: mathMax(current?.importanceScore ?? 0, entity.importanceScore),
      );
    }

    final existingRelations = {
      for (final item in await DBService.instance.getAiRelationStates(aid)) '${item.fromName}=>${item.toName}': item,
    };
    for (final edge in result.relations) {
      final endpoints = _normalizeRelationEndpoints(edge.from, edge.to, edge.displayLabel);
      final fromName = endpoints.$1;
      final toName = endpoints.$2;
      final key = '$fromName=>$toName';
      final current = existingRelations[key];
      await DBService.instance.upsertAiRelationState(
        aid: aid,
        fromName: fromName,
        toName: toName,
        relationLabel: edge.displayLabel,
        relationSummary: _capMemorySummary(_mergeRelationSummary(current?.relationSummary ?? '', edge.stateSummary, edge.displayLabel)),
        firstSeenCid: current?.firstSeenCid.isNotEmpty == true ? current!.firstSeenCid : cid,
        lastSeenCid: cid,
        mentionCount: (current?.mentionCount ?? 0) + 1,
        strengthScore: mathMax(current?.strengthScore ?? 0, edge.strengthScore),
      );
    }
  }

  String _mergeRelationSummary(String oldSummary, String newSummary, String label) {
    final cleanOld = oldSummary.trim();
    final cleanNew = newSummary.trim();
    if (cleanOld.isEmpty && cleanNew.isEmpty) return label;
    if (cleanOld.isEmpty) return cleanNew;
    if (cleanNew.isEmpty) return cleanOld;
    if (cleanOld.contains(cleanNew)) return cleanOld;
    if (cleanNew.contains(cleanOld)) return cleanNew;
    return '$cleanOld\nUpdate: $cleanNew';
  }

  String _buildAliasPayload(String? existingJson, List<String> aliases) {
    final cleanAliases = aliases.map((item) => item.trim()).where((item) => item.isNotEmpty).toSet().toList()..sort();
    final metadata = <String, Map<String, dynamic>>{};

    if (existingJson != null && existingJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(existingJson);
        if (decoded is Map && decoded['meta'] is Map) {
          for (final entry in (decoded['meta'] as Map).entries) {
            metadata[entry.key.toString()] = Map<String, dynamic>.from(entry.value as Map);
          }
        }
      } catch (_) {}
    }

    for (final alias in cleanAliases) {
      metadata.putIfAbsent(alias, () => {'source': 'analysis', 'confidence': 0.6});
    }

    return jsonEncode({
      'aliases': cleanAliases,
      'meta': metadata,
    });
  }

  Future<String> _resolveBookTitle(String aid) async {
    final detail = await DBService.instance.getNovelDetail(aid);
    if (detail == null || detail.json.isEmpty) return aid;
    try {
      final map = jsonDecode(detail.json);
      if (map is Map && (map['title']?.toString().trim().isNotEmpty ?? false)) {
        return map['title'].toString().trim();
      }
    } catch (_) {}
    return aid;
  }

  String _outlineFromSummary(String summary) {
    final text = summary.replaceAll('\n', ' ').trim();
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  Future<String> _buildRecentSummary(String aid, {String? excludeCid}) async {
    final rows = await DBService.instance.getAiMemoryRows(aid, rowType: 'summary');
    final filtered = rows.where((item) => item.rowKey != excludeCid).toList();
    if (filtered.isEmpty) return '';
    final take = filtered.length <= 3 ? filtered : filtered.sublist(filtered.length - 3);
    return _capText(take.map((item) => '- ${item.timeSpan}: ${item.content}').join('\n'), maxChars: 1800);
  }

  Future<String> _buildBookMemory(String aid) async {
    final characters = await DBService.instance.getAiCharacterStates(aid);
    final relations = await DBService.instance.getAiRelationStates(aid);
    final lines = <String>[];

    final core = characters.where((item) => item.tier == 'core').take(8);
    final active = characters.where((item) => item.tier == 'active').take(8);

    if (core.isNotEmpty || active.isNotEmpty) {
      lines.add('[known_entities]');
      for (final item in [...core, ...active]) {
        final aliasPart = item.aliases.isEmpty ? '' : ' aliases=${item.aliases.join(", ")}';
        lines.add('- ${item.name} tier=${item.tier} score=${item.importanceScore}$aliasPart');
      }
    }

    if (relations.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('[relation_states]');
      for (final item in relations.take(10)) {
        final summary = item.relationSummary.trim().isEmpty ? item.relationLabel : item.relationSummary.trim();
        lines.add('- ${item.fromName} -> ${item.toName}: ${item.relationLabel}; $summary');
      }
    }

    return _capText(lines.join('\n'), maxChars: 2400);
  }

  _MergePromptBundle _buildMergePrompt({
    required String chapterTitle,
    required ChapterAnalysisResult extracted,
    required List<AiCharacterStateRecord> characterStates,
    required List<AiRelationStateRecord> relationStates,
    required String recentSummary,
  }) {
    final focusNames = <String>{
      for (final entity in extracted.entities) entity.name.trim(),
      for (final relation in extracted.relations) relation.from.trim(),
      for (final relation in extracted.relations) relation.to.trim(),
      for (final character in extracted.characters) character.trim(),
    }..removeWhere((item) => item.isEmpty);
    final focusKeys = focusNames.map(_normalizeName).where((item) => item.isNotEmpty).toSet();

    bool matchesFocus(AiCharacterStateRecord item) {
      if (focusNames.contains(item.name) || focusKeys.contains(_normalizeName(item.name))) return true;
      return item.aliases.any((alias) => focusNames.contains(alias) || focusKeys.contains(_normalizeName(alias)));
    }

    final relevantCharacters = characterStates.where(matchesFocus).toList();
    final fallbackCharacters = relevantCharacters.isEmpty
        ? characterStates.take(8).toList()
        : [
            ...relevantCharacters,
            ...characterStates.where((item) => item.tier == 'core' && !relevantCharacters.contains(item)).take(4),
          ];

    final aliasToCanonical = <String, String>{};
    for (final item in fallbackCharacters) {
      aliasToCanonical[_normalizeName(item.name)] = item.name;
      for (final alias in item.aliases) {
        aliasToCanonical[_normalizeName(alias)] = item.name;
      }
    }

    final focusPairs = <String>{};
    for (final relation in extracted.relations) {
      final from = _resolveMergeName(relation.from, aliasToCanonical);
      final to = _resolveMergeName(relation.to, aliasToCanonical);
      if (from.isEmpty || to.isEmpty || from == to) continue;
      focusPairs.add('$from=>$to');
      focusPairs.add('$to=>$from');
    }

    bool relationTouchesFocus(AiRelationStateRecord item) {
      if (focusPairs.contains('${item.fromName}=>${item.toName}')) return true;
      final fromKey = _normalizeName(item.fromName);
      final toKey = _normalizeName(item.toName);
      return focusKeys.contains(fromKey) || focusKeys.contains(toKey);
    }

    bool relationMatchesPair(AiRelationStateRecord item) {
      if (focusPairs.contains('${item.fromName}=>${item.toName}')) return true;
      final from = _resolveMergeName(item.fromName, aliasToCanonical);
      final to = _resolveMergeName(item.toName, aliasToCanonical);
      return focusPairs.contains('$from=>$to');
    }

    final pairRelations = relationStates.where(relationMatchesPair).toList();
    final relevantRelations = relationStates.where(relationTouchesFocus).toList();
    final fallbackRelations = pairRelations.isNotEmpty
        ? pairRelations.take(8).toList()
        : relevantRelations.isNotEmpty
            ? relevantRelations.take(10).toList()
            : relationStates.take(6).toList();

    final knownEntities = fallbackCharacters
        .take(12)
        .map((item) {
          final aliases = item.aliases.isEmpty ? '' : ' aliases=${item.aliases.join(", ")}';
          final summary = item.profileSummary.trim().isEmpty ? '' : ' summary=${item.profileSummary.trim()}';
          return '- ${item.name} tier=${item.tier} score=${item.importanceScore}$aliases$summary';
        })
        .join('\n');
    final focusEntityList = fallbackCharacters.take(12).map((item) => '- ${item.name}').join('\n');
    final knownRelations = fallbackRelations
        .take(12)
        .map((item) {
          final summary = item.relationSummary.trim().isEmpty ? item.relationLabel : item.relationSummary.trim();
          return '- ${item.fromName} -> ${item.toName}: ${item.relationLabel}; $summary';
        })
        .join('\n');

    final prompt = '''
<chapter_title>
$chapterTitle
</chapter_title>

<extracted_result>
${jsonEncode(extracted.toJson())}
</extracted_result>

<recent_summary>
$recentSummary
</recent_summary>

<focus_entities>
$focusEntityList
</focus_entities>

<known_entities>
$knownEntities
</known_entities>

<relevant_relation_history>
$knownRelations
</relevant_relation_history>

Merge the extracted result into a cleaner canonical result.
Return JSON only.
''';
    return _MergePromptBundle(
      prompt: prompt,
      focusEntitiesCount: focusNames.length,
      relevantEntitiesCount: relevantCharacters.length,
      pairRelationsCount: pairRelations.length,
      relevantRelationsCount: relevantRelations.length,
      selectedRelationsCount: fallbackRelations.length,
    );
  }

  String _resolveMergeName(String value, Map<String, String> aliasToCanonical) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final normalized = _normalizeName(trimmed);
    return aliasToCanonical[normalized] ?? trimmed;
  }

  String _capText(String value, {required int maxChars}) {
    final text = value.trim();
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n...(truncated)';
  }

  String _normalizeName(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s._\-·・•]+'), '')
        .replaceAll(RegExp(r'''[()\[\]{}（）【】「」『』《》〈〉“”‘’"':;,，。！？、：；]'''), '');
    return normalized;
  }
}

class _MergePromptBundle {
  final String prompt;
  final int focusEntitiesCount;
  final int relevantEntitiesCount;
  final int pairRelationsCount;
  final int relevantRelationsCount;
  final int selectedRelationsCount;

  const _MergePromptBundle({
    required this.prompt,
    required this.focusEntitiesCount,
    required this.relevantEntitiesCount,
    required this.pairRelationsCount,
    required this.relevantRelationsCount,
    required this.selectedRelationsCount,
  });
}

class _ChapterTextChunk {
  final int index;
  final int total;
  final String text;

  const _ChapterTextChunk({
    required this.index,
    required this.total,
    required this.text,
  });
}

int mathMax(int a, int b) => a > b ? a : b;

const String _chapterAnalysisSystemPrompt = '''
You are a novel chapter analyst.

Return strict JSON only. No explanation. No markdown.

Your job:
1. Summarize the current chapter.
2. Extract character entities.
3. Resolve obvious aliases or codenames when the context is strong enough.
4. Extract relationship updates as stable relationship states, not one-off actions.

Output shape:
{
  "summary": "short chapter summary",
  "entities": [
    {
      "name": "canonical character name",
      "aliases": ["alias A", "alias B"],
      "tier": "core|active|transient",
      "importance_score": 0,
      "summary": "short character state summary"
    }
  ],
  "relations": [
    {
      "from": "canonical name",
      "to": "canonical name",
      "display_label": "short label",
      "state_summary": "1-2 sentence relationship state summary",
      "strength_score": 0
    }
  ]
}

Rules:
- Keep JSON keys in English, but all user-facing text values must be Simplified Chinese:
  summary, entity summary, display_label, and state_summary.
- Preserve source character names and aliases; do not translate established names.
- Prefer canonical names when possible.
- Use aliases only in the aliases field.
- Do not treat locations, organizations, or objects as characters.
- Do not use pronouns as entity names.
- tier means:
  - core: major character that should remain globally important
  - active: supporting character currently relevant
  - transient: passing mention or temporary side character
- display_label must be short Chinese, such as \u670b\u53cb, \u5bf9\u624b, \u540c\u76df, \u4e0a\u4e0b\u7ea7, \u5bb6\u4eba, \u654c\u5bf9, \u590d\u6742.
- state_summary should describe the current combined relationship state, not just a single scene.
- If the title shows a part marker like (2/5), analyze only that slice but preserve enough detail for later chapter-level merging.
- If there is no stable relationship update, return an empty relations array.
''';

const String _chapterAnalysisUserPromptTemplate = '''
<chapter>
<title>{{chapterTitle}}</title>
<content>
{{chapterText}}
</content>
</chapter>

<recent_summary>
{{recentSummary}}
</recent_summary>

<book_memory>
{{bookMemory}}
</book_memory>

Analyze the chapter and return JSON only.
''';

const String _chapterMergeSystemPrompt = '''
You are a novel state-merging analyst.

You do not re-read the full chapter text. You only receive:
1. an extracted chapter result,
2. recent chapter summaries,
3. focus entities for this chapter,
4. relevant entity registry,
5. relevant relationship history.

Return strict JSON only. No explanation. No markdown.

Your job:
1. Canonicalize obvious aliases or codenames to stable character names.
2. Keep only character entities, not locations or objects.
3. Re-evaluate entity tier and importance with long-book continuity in mind.
4. Merge relationship updates into current relationship states.
5. Produce a clean final chapter result.

Output shape:
{
  "summary": "clean chapter summary",
  "entities": [
    {
      "name": "canonical character name",
      "aliases": ["alias A", "alias B"],
      "tier": "core|active|transient",
      "importance_score": 0,
      "summary": "short character state summary"
    }
  ],
  "relations": [
    {
      "from": "canonical name",
      "to": "canonical name",
      "display_label": "short label",
      "state_summary": "merged relationship state summary",
      "strength_score": 0
    }
  ]
}

Rules:
- Keep JSON keys in English, but all user-facing text values must be Simplified Chinese:
  summary, entity summary, display_label, and state_summary.
- Preserve source character names and aliases; do not translate established names.
- Prefer existing canonical names when an alias match is strong.
- If two names clearly refer to the same person, keep one canonical entity and move the rest into aliases.
- Use recent summaries, focus entities, relevant entities, and relevant relationship history as context.
- Prioritize exact character-pair history over broad book-level memory.
- Do not pull unrelated book-level characters or unrelated old relationships into this chapter.
- Keep display_label short and in Chinese.
- state_summary should reflect old state plus new update when possible.
- For very long chapters or multi-part extracted results, keep a proportionate detailed summary instead of compressing everything into one short paragraph.
- If the extracted result is already clean, preserve it rather than inventing new facts.
''';
