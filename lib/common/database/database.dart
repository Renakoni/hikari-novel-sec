import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:hikari_novel_flutter/common/migration.dart';
import 'package:path_provider/path_provider.dart';
import 'entity.dart';
import '../../service/ai/ai_analysis_models.dart';
import '../../service/ai/ai_memory_models.dart';

part "database.g.dart";

@DriftDatabase(tables: [BookshelfEntity, BrowsingHistoryEntity, SearchHistoryEntity, ReadHistoryEntity, NovelDetailEntity])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4; //版本号

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 2) {
        Migration.fromOneToTwo(this);
      } else if (from == 2 && to == 3) {
        Migration.fromTwoToThree();
      } else if (from == 3 && to == 4) {
        Migration.fromThreeToFour(this);
      }
    },
  );

  Future<void> insertAllBookshelf(Iterable<BookshelfEntityData> data) => batch((b) => b.insertAll(bookshelfEntity, data));

  Future<void> upsertBookshelf(BookshelfEntityData data) => into(bookshelfEntity).insertOnConflictUpdate(data);

  Future<void> deleteAllBookshelf() => delete(bookshelfEntity).go();

  Future<void> deleteDefaultBookshelf() => (delete(bookshelfEntity)..where((i) => i.classId.equals("0"))).go();

  Future<void> deleteBookshelfByAid(String aid) => (delete(bookshelfEntity)..where((i) => i.aid.equals(aid))).go();

  Stream<List<BookshelfEntityData>> getBookshelfByClassId(String classId) => (select(bookshelfEntity)..where((i) => i.classId.equals(classId))).watch();

  Future<List<BookshelfEntityData>> getAllBookshelf() => select(bookshelfEntity).get();

  Future<List<BookshelfEntityData>> getBookshelfByKeyword(String keyword) =>
      (select(bookshelfEntity)..where((i) => i.title.contains(keyword).equals(true))).get();

  Future<void> upsertBrowsingHistory(BrowsingHistoryEntityData data) => into(browsingHistoryEntity).insertOnConflictUpdate(data);

  Stream<List<BrowsingHistoryEntityData>> getWatchableAllBrowsingHistory() => select(browsingHistoryEntity).watch();

  Future<void> deleteBrowsingHistory(String aid) => (delete(browsingHistoryEntity)..where((i) => i.aid.equals(aid))).go();

  Future<void> deleteAllBrowsingHistory() => delete(browsingHistoryEntity).go();

  Future<void> upsertSearchHistory(SearchHistoryEntityData data) => into(searchHistoryEntity).insertOnConflictUpdate(data);

  Stream<List<SearchHistoryEntityData>> getAllSearchHistory() => select(searchHistoryEntity).watch();

  Future<void> deleteAllSearchHistory() => delete(searchHistoryEntity).go();

  Future<void> upsertReadHistory(ReadHistoryEntityData data) => transaction(() async {
    await (update(readHistoryEntity)
      ..where((i) => i.isLatest.equals(true) & i.aid.equals(data.aid))).write(RawValuesInsertable({readHistoryEntity.isLatest.name: Variable<bool>(false)}));
    await into(readHistoryEntity).insertOnConflictUpdate(data);
  });

  Future<ReadHistoryEntityData?> getReadHistoryByCid(String cid) => (select(readHistoryEntity)..where((i) => i.cid.equals(cid))).getSingleOrNull();

  Stream<ReadHistoryEntityData?> getLastestReadHistoryByAid(String aid) =>
      (select(readHistoryEntity)..where((i) => i.aid.equals(aid) & i.isLatest.equals(true))).watchSingleOrNull();

  Stream<ReadHistoryEntityData?> getWatchableReadHistoryByCid(String cid) => (select(readHistoryEntity)..where((i) => i.cid.equals(cid))).watchSingleOrNull();

  /// - [cids] 该卷下所有小说的cid
  Stream<List<ReadHistoryEntityData>> getWatchableReadHistoryByVolume(List<String> cids) => (select(readHistoryEntity)..where((i) => i.cid.isIn(cids))).watch();

  Future<void> deleteReadHistoryByCid(String cid) => (delete(readHistoryEntity)..where((i) => i.cid.equals(cid))).go();

  Future<void> deleteReadHistoryByAid(String aid) => (delete(readHistoryEntity)..where((i) => i.aid.equals(aid))).go();

  Future<void> upsertReadHistoryDirectly(ReadHistoryEntityData data) => into(readHistoryEntity).insertOnConflictUpdate(data);

  Future<void> deleteAllReadHistory() => delete(readHistoryEntity).go();

  Future<void> upsertNovelDetail(NovelDetailEntityData data) => into(novelDetailEntity).insertOnConflictUpdate(data);

  Future<NovelDetailEntityData?> getNovelDetail(String aid) => (select(novelDetailEntity)..where((i) => i.aid.equals(aid))).getSingleOrNull();

  Future<void> deleteNovelDetail(String aid) => (delete(novelDetailEntity)..where((i) => i.aid.equals(aid))).go();

  Future<void> deleteAllNovelDetail() => delete(novelDetailEntity).go();

  Future<void> ensureAiAnalysisTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ai_books (
        aid TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        source_type TEXT NOT NULL DEFAULT '',
        last_analyzed_cid TEXT,
        last_analyzed_at TEXT,
        latest_book_summary TEXT NOT NULL DEFAULT '',
        latest_arc_summary TEXT NOT NULL DEFAULT '',
        character_count INTEGER NOT NULL DEFAULT 0,
        relation_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ai_chapter_analysis (
        aid TEXT NOT NULL,
        cid TEXT NOT NULL,
        chapter_title TEXT NOT NULL DEFAULT '',
        schema_version INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'ready',
        analyzed_at TEXT,
        prompt_version INTEGER NOT NULL DEFAULT 1,
        max_request_tokens INTEGER NOT NULL DEFAULT 60000,
        max_response_tokens INTEGER NOT NULL DEFAULT 30000,
        summary TEXT NOT NULL DEFAULT '',
        characters_json TEXT NOT NULL DEFAULT '[]',
        entities_json TEXT NOT NULL DEFAULT '[]',
        relations_json TEXT NOT NULL DEFAULT '[]',
        snapshot_json_path TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (aid, cid)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ai_memory_rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        aid TEXT NOT NULL,
        row_type TEXT NOT NULL,
        row_key TEXT NOT NULL,
        time_span TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        ref_cid TEXT NOT NULL DEFAULT '',
        order_no INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ai_character_state (
        aid TEXT NOT NULL,
        name TEXT NOT NULL,
        aliases_json TEXT NOT NULL DEFAULT '[]',
        profile_summary TEXT NOT NULL DEFAULT '',
        first_seen_cid TEXT NOT NULL DEFAULT '',
        last_seen_cid TEXT NOT NULL DEFAULT '',
        appearance_count INTEGER NOT NULL DEFAULT 0,
        tier TEXT NOT NULL DEFAULT 'active',
        importance_score INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (aid, name)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ai_relation_state (
        aid TEXT NOT NULL,
        from_name TEXT NOT NULL,
        to_name TEXT NOT NULL,
        relation_label TEXT NOT NULL DEFAULT '',
        relation_summary TEXT NOT NULL DEFAULT '',
        first_seen_cid TEXT NOT NULL DEFAULT '',
        last_seen_cid TEXT NOT NULL DEFAULT '',
        mention_count INTEGER NOT NULL DEFAULT 0,
        strength_score INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (aid, from_name, to_name)
      );
    ''');
    await _ensureColumn('ai_chapter_analysis', 'entities_json', "TEXT NOT NULL DEFAULT '[]'");
    await _ensureColumn('ai_character_state', 'tier', "TEXT NOT NULL DEFAULT 'active'");
    await _ensureColumn('ai_character_state', 'importance_score', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn('ai_relation_state', 'relation_summary', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn('ai_relation_state', 'strength_score', 'INTEGER NOT NULL DEFAULT 0');
    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS ai_memory_rows_unique_idx ON ai_memory_rows(aid, row_type, row_key);');
    await customStatement('CREATE INDEX IF NOT EXISTS ai_memory_rows_aid_order_idx ON ai_memory_rows(aid, row_type, order_no);');
    await customStatement('CREATE INDEX IF NOT EXISTS ai_chapter_analysis_aid_idx ON ai_chapter_analysis(aid);');
    await customStatement('CREATE INDEX IF NOT EXISTS ai_character_state_aid_idx ON ai_character_state(aid);');
    await customStatement('CREATE INDEX IF NOT EXISTS ai_relation_state_aid_idx ON ai_relation_state(aid);');
  }

  Future<void> upsertAiBook({
    required String aid,
    required String title,
    required String sourceType,
    required String? lastAnalyzedCid,
    required DateTime? lastAnalyzedAt,
    required String latestBookSummary,
    required String latestArcSummary,
    required int characterCount,
    required int relationCount,
  }) async {
    await ensureAiAnalysisTables();
    final now = DateTime.now().toIso8601String();
    await customStatement(
      '''
      INSERT INTO ai_books (
        aid, title, source_type, last_analyzed_cid, last_analyzed_at,
        latest_book_summary, latest_arc_summary, character_count, relation_count,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(aid) DO UPDATE SET
        title = excluded.title,
        source_type = excluded.source_type,
        last_analyzed_cid = excluded.last_analyzed_cid,
        last_analyzed_at = excluded.last_analyzed_at,
        latest_book_summary = excluded.latest_book_summary,
        latest_arc_summary = excluded.latest_arc_summary,
        character_count = excluded.character_count,
        relation_count = excluded.relation_count,
        updated_at = excluded.updated_at
      ''',
      [
        aid,
        title,
        sourceType,
        lastAnalyzedCid,
        lastAnalyzedAt?.toIso8601String(),
        latestBookSummary,
        latestArcSummary,
        characterCount,
        relationCount,
        now,
        now,
      ],
    );
  }

  Future<void> upsertAiChapterAnalysis({
    required String aid,
    required String cid,
    required String chapterTitle,
    required ChapterAnalysisResult result,
    required int promptVersion,
    required int maxRequestTokens,
    required int maxResponseTokens,
    required String snapshotJsonPath,
  }) async {
    await ensureAiAnalysisTables();
    await customStatement(
      '''
      INSERT INTO ai_chapter_analysis (
        aid, cid, chapter_title, schema_version, status, analyzed_at,
        prompt_version, max_request_tokens, max_response_tokens,
        summary, characters_json, entities_json, relations_json, snapshot_json_path
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(aid, cid) DO UPDATE SET
        chapter_title = excluded.chapter_title,
        schema_version = excluded.schema_version,
        status = excluded.status,
        analyzed_at = excluded.analyzed_at,
        prompt_version = excluded.prompt_version,
        max_request_tokens = excluded.max_request_tokens,
        max_response_tokens = excluded.max_response_tokens,
        summary = excluded.summary,
        characters_json = excluded.characters_json,
        entities_json = excluded.entities_json,
        relations_json = excluded.relations_json,
        snapshot_json_path = excluded.snapshot_json_path
      ''',
      [
        aid,
        cid,
        chapterTitle,
        result.schemaVersion,
        'ready',
        result.analyzedAt,
        promptVersion,
        maxRequestTokens,
        maxResponseTokens,
        result.summary,
        jsonEncode(result.characters),
        jsonEncode(result.entities.map((item) => item.toJson()).toList()),
        jsonEncode(result.relations.map((item) => item.toJson()).toList()),
        snapshotJsonPath,
      ],
    );
  }

  Future<AiChapterAnalysisRecord?> getAiChapterAnalysis(String aid, String cid) async {
    await ensureAiAnalysisTables();
    final rows = await customSelect(
      'SELECT * FROM ai_chapter_analysis WHERE aid = ? AND cid = ? LIMIT 1',
      variables: [Variable<String>(aid), Variable<String>(cid)],
    ).get();
    if (rows.isEmpty) return null;
    return _mapAiChapterAnalysis(rows.first.data);
  }

  Future<List<AiBookRecord>> getAiBooks() async {
    await ensureAiAnalysisTables();
    final rows = await customSelect('SELECT * FROM ai_books ORDER BY updated_at DESC').get();
    return rows.map((row) => _mapAiBook(row.data)).toList();
  }

  Future<AiBookRecord?> getAiBook(String aid) async {
    await ensureAiAnalysisTables();
    final rows = await customSelect(
      'SELECT * FROM ai_books WHERE aid = ? LIMIT 1',
      variables: [Variable<String>(aid)],
    ).get();
    if (rows.isEmpty) return null;
    return _mapAiBook(rows.first.data);
  }

  Future<void> deleteAiAnalysisByAid(String aid) async {
    await ensureAiAnalysisTables();
    await transaction(() async {
      await customStatement('DELETE FROM ai_relation_state WHERE aid = ?', [aid]);
      await customStatement('DELETE FROM ai_character_state WHERE aid = ?', [aid]);
      await customStatement('DELETE FROM ai_memory_rows WHERE aid = ?', [aid]);
      await customStatement('DELETE FROM ai_chapter_analysis WHERE aid = ?', [aid]);
      await customStatement('DELETE FROM ai_books WHERE aid = ?', [aid]);
    });
  }

  Future<void> upsertAiMemoryRow({
    required String aid,
    required String rowType,
    required String rowKey,
    required String timeSpan,
    required String content,
    required String refCid,
    required int orderNo,
  }) async {
    await ensureAiAnalysisTables();
    await customStatement(
      '''
      INSERT INTO ai_memory_rows (aid, row_type, row_key, time_span, content, ref_cid, order_no, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(aid, row_type, row_key) DO UPDATE SET
        time_span = excluded.time_span,
        content = excluded.content,
        ref_cid = excluded.ref_cid,
        order_no = excluded.order_no,
        updated_at = excluded.updated_at
      ''',
      [aid, rowType, rowKey, timeSpan, content, refCid, orderNo, DateTime.now().toIso8601String()],
    );
  }

  Future<List<AiMemoryRowRecord>> getAiMemoryRows(String aid, {String? rowType}) async {
    await ensureAiAnalysisTables();
    final sql = rowType == null
        ? 'SELECT * FROM ai_memory_rows WHERE aid = ? ORDER BY row_type ASC, order_no ASC'
        : 'SELECT * FROM ai_memory_rows WHERE aid = ? AND row_type = ? ORDER BY order_no ASC';
    final variables = rowType == null ? [Variable<String>(aid)] : [Variable<String>(aid), Variable<String>(rowType)];
    final rows = await customSelect(sql, variables: variables).get();
    return rows.map((row) => _mapAiMemoryRow(row.data)).toList();
  }

  Future<void> upsertAiCharacterState({
    required String aid,
    required String name,
    required String aliasesJson,
    required String profileSummary,
    required String firstSeenCid,
    required String lastSeenCid,
    required int appearanceCount,
    required String tier,
    required int importanceScore,
  }) async {
    await ensureAiAnalysisTables();
    await customStatement(
      '''
      INSERT INTO ai_character_state (aid, name, aliases_json, profile_summary, first_seen_cid, last_seen_cid, appearance_count, tier, importance_score, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(aid, name) DO UPDATE SET
        aliases_json = excluded.aliases_json,
        profile_summary = excluded.profile_summary,
        first_seen_cid = excluded.first_seen_cid,
        last_seen_cid = excluded.last_seen_cid,
        appearance_count = excluded.appearance_count,
        tier = excluded.tier,
        importance_score = excluded.importance_score,
        updated_at = excluded.updated_at
      ''',
      [aid, name, aliasesJson, profileSummary, firstSeenCid, lastSeenCid, appearanceCount, tier, importanceScore, DateTime.now().toIso8601String()],
    );
  }

  Future<void> upsertAiRelationState({
    required String aid,
    required String fromName,
    required String toName,
    required String relationLabel,
    required String relationSummary,
    required String firstSeenCid,
    required String lastSeenCid,
    required int mentionCount,
    required int strengthScore,
  }) async {
    await ensureAiAnalysisTables();
    await customStatement(
      '''
      INSERT INTO ai_relation_state (aid, from_name, to_name, relation_label, relation_summary, first_seen_cid, last_seen_cid, mention_count, strength_score, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(aid, from_name, to_name) DO UPDATE SET
        relation_label = excluded.relation_label,
        relation_summary = excluded.relation_summary,
        first_seen_cid = excluded.first_seen_cid,
        last_seen_cid = excluded.last_seen_cid,
        mention_count = excluded.mention_count,
        strength_score = excluded.strength_score,
        updated_at = excluded.updated_at
      ''',
      [aid, fromName, toName, relationLabel, relationSummary, firstSeenCid, lastSeenCid, mentionCount, strengthScore, DateTime.now().toIso8601String()],
    );
  }

  Future<List<AiCharacterStateRecord>> getAiCharacterStates(String aid) async {
    await ensureAiAnalysisTables();
    final rows = await customSelect(
      'SELECT * FROM ai_character_state WHERE aid = ? ORDER BY appearance_count DESC, updated_at DESC',
      variables: [Variable<String>(aid)],
    ).get();
    return rows.map((row) => _mapAiCharacterState(row.data)).toList();
  }

  Future<List<AiRelationStateRecord>> getAiRelationStates(String aid) async {
    await ensureAiAnalysisTables();
    final rows = await customSelect(
      'SELECT * FROM ai_relation_state WHERE aid = ? ORDER BY mention_count DESC, updated_at DESC',
      variables: [Variable<String>(aid)],
    ).get();
    return rows.map((row) => _mapAiRelationState(row.data)).toList();
  }

  static DateTime? _parseDate(dynamic value) => value == null || value.toString().trim().isEmpty ? null : DateTime.tryParse(value.toString());

  static AiBookRecord _mapAiBook(Map<String, dynamic> data) => AiBookRecord(
        aid: data['aid']?.toString() ?? '',
        title: data['title']?.toString() ?? '',
        sourceType: data['source_type']?.toString() ?? '',
        lastAnalyzedCid: data['last_analyzed_cid']?.toString(),
        lastAnalyzedAt: _parseDate(data['last_analyzed_at']),
        latestBookSummary: data['latest_book_summary']?.toString() ?? '',
        latestArcSummary: data['latest_arc_summary']?.toString() ?? '',
        characterCount: (data['character_count'] as int?) ?? int.tryParse(data['character_count']?.toString() ?? '') ?? 0,
        relationCount: (data['relation_count'] as int?) ?? int.tryParse(data['relation_count']?.toString() ?? '') ?? 0,
      );

  static AiChapterAnalysisRecord _mapAiChapterAnalysis(Map<String, dynamic> data) => AiChapterAnalysisRecord(
        aid: data['aid']?.toString() ?? '',
        cid: data['cid']?.toString() ?? '',
        chapterTitle: data['chapter_title']?.toString() ?? '',
        schemaVersion: (data['schema_version'] as int?) ?? int.tryParse(data['schema_version']?.toString() ?? '') ?? 1,
        status: data['status']?.toString() ?? 'ready',
        analyzedAt: _parseDate(data['analyzed_at']),
        promptVersion: (data['prompt_version'] as int?) ?? int.tryParse(data['prompt_version']?.toString() ?? '') ?? 1,
        maxRequestTokens: (data['max_request_tokens'] as int?) ?? int.tryParse(data['max_request_tokens']?.toString() ?? '') ?? 60000,
        maxResponseTokens: (data['max_response_tokens'] as int?) ?? int.tryParse(data['max_response_tokens']?.toString() ?? '') ?? 30000,
        summary: data['summary']?.toString() ?? '',
        characters: AiChapterAnalysisRecord.decodeStringList(data['characters_json']?.toString() ?? '[]'),
        entities: AiChapterAnalysisRecord.decodeEntities(data['entities_json']?.toString() ?? '[]'),
        relations: AiChapterAnalysisRecord.decodeRelations(data['relations_json']?.toString() ?? '[]'),
        snapshotJsonPath: data['snapshot_json_path']?.toString() ?? '',
      );

  static AiMemoryRowRecord _mapAiMemoryRow(Map<String, dynamic> data) => AiMemoryRowRecord(
        id: (data['id'] as int?) ?? int.tryParse(data['id']?.toString() ?? '') ?? 0,
        aid: data['aid']?.toString() ?? '',
        rowType: data['row_type']?.toString() ?? '',
        rowKey: data['row_key']?.toString() ?? '',
        timeSpan: data['time_span']?.toString() ?? '',
        content: data['content']?.toString() ?? '',
        refCid: data['ref_cid']?.toString() ?? '',
        orderNo: (data['order_no'] as int?) ?? int.tryParse(data['order_no']?.toString() ?? '') ?? 0,
        updatedAt: _parseDate(data['updated_at']),
      );

  static AiCharacterStateRecord _mapAiCharacterState(Map<String, dynamic> data) => AiCharacterStateRecord(
        aid: data['aid']?.toString() ?? '',
        name: data['name']?.toString() ?? '',
        aliasesJson: data['aliases_json']?.toString() ?? '[]',
        profileSummary: data['profile_summary']?.toString() ?? '',
        firstSeenCid: data['first_seen_cid']?.toString() ?? '',
        lastSeenCid: data['last_seen_cid']?.toString() ?? '',
        appearanceCount: (data['appearance_count'] as int?) ?? int.tryParse(data['appearance_count']?.toString() ?? '') ?? 0,
        updatedAt: _parseDate(data['updated_at']),
        tier: data['tier']?.toString() ?? 'active',
        importanceScore: (data['importance_score'] as int?) ?? int.tryParse(data['importance_score']?.toString() ?? '') ?? 0,
      );

  static AiRelationStateRecord _mapAiRelationState(Map<String, dynamic> data) => AiRelationStateRecord(
        aid: data['aid']?.toString() ?? '',
        fromName: data['from_name']?.toString() ?? '',
        toName: data['to_name']?.toString() ?? '',
        relationLabel: data['relation_label']?.toString() ?? '',
        relationSummary: data['relation_summary']?.toString() ?? '',
        firstSeenCid: data['first_seen_cid']?.toString() ?? '',
        lastSeenCid: data['last_seen_cid']?.toString() ?? '',
        mentionCount: (data['mention_count'] as int?) ?? int.tryParse(data['mention_count']?.toString() ?? '') ?? 0,
        updatedAt: _parseDate(data['updated_at']),
        strengthScore: (data['strength_score'] as int?) ?? int.tryParse(data['strength_score']?.toString() ?? '') ?? 0,
      );

  Future<void> _ensureColumn(String tableName, String columnName, String definition) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    final exists = rows.any((row) => row.data['name']?.toString() == columnName);
    if (!exists) {
      await customStatement('ALTER TABLE $tableName ADD COLUMN $columnName $definition');
    }
  }
}

QueryExecutor _openConnection() =>
    driftDatabase(name: "hikari_novel_database", native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory));
