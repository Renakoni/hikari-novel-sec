import 'package:get/get.dart';

import '../common/database/database.dart';
import 'ai/ai_analysis_models.dart';
import 'ai/ai_memory_models.dart';

class DBService extends GetxService {
  static DBService get instance => Get.find<DBService>();

  late final AppDatabase _db;

  void init() {
    _db = AppDatabase();
    _db.ensureAiAnalysisTables();
  }

  Future<void> insertAllBookshelf(Iterable<BookshelfEntityData> data) => _db.insertAllBookshelf(data);

  Future<void> upsertBookshelf(BookshelfEntityData data) => _db.upsertBookshelf(data);

  Future<void> deleteAllBookshelf() => _db.deleteAllBookshelf();

  Future<void> deleteDefaultBookshelf() => _db.deleteDefaultBookshelf();

  Future<void> deleteBookshelfByAid(String aid) => _db.deleteBookshelfByAid(aid);

  Stream<List<BookshelfEntityData>> getBookshelfByClassId(String classId) => _db.getBookshelfByClassId(classId);

  Future<List<BookshelfEntityData>> getAllBookshelf() => _db.getAllBookshelf();

  Future<List<BookshelfEntityData>> getBookshelfByKeyword(String keyword) => _db.getBookshelfByKeyword(keyword);

  Future<void> upsertBrowsingHistory(BrowsingHistoryEntityData data) => _db.upsertBrowsingHistory(data);

  Stream<List<BrowsingHistoryEntityData>> getWatchableAllBrowsingHistory() => _db.getWatchableAllBrowsingHistory();

  Future<void> deleteBrowsingHistory(String aid) => _db.deleteBrowsingHistory(aid);

  Future<void> deleteAllBrowsingHistory() => _db.deleteAllBrowsingHistory();

  Future<void> upsertSearchHistory(SearchHistoryEntityData data) => _db.upsertSearchHistory(data);

  Stream<List<SearchHistoryEntityData>> getAllSearchHistory() => _db.getAllSearchHistory();

  Future<void> deleteAllSearchHistory() => _db.deleteAllSearchHistory();

  Future<void> upsertReadHistory(ReadHistoryEntityData data) => _db.upsertReadHistory(data);

  Future<ReadHistoryEntityData?> getReadHistoryByCid(String cid) => _db.getReadHistoryByCid(cid);

  Stream<ReadHistoryEntityData?> getLastestReadHistoryByAid(String aid) => _db.getLastestReadHistoryByAid(aid);

  Stream<ReadHistoryEntityData?> getWatchableReadHistoryByCid(String cid) => _db.getWatchableReadHistoryByCid(cid);

  Stream<List<ReadHistoryEntityData>> getWatchableReadHistoryByVolume(List<String> cids) => _db.getWatchableReadHistoryByVolume(cids);

  Future<void> deleteReadHistoryByCid(String cid) => _db.deleteReadHistoryByCid(cid);

  Future<void> deleteReadHistoryByAid(String aid) => _db.deleteReadHistoryByAid(aid);

  Future<void> upsertReadHistoryDirectly(ReadHistoryEntityData data) => _db.upsertReadHistoryDirectly(data);

  Future<void> deleteAllReadHistory() => _db.deleteAllReadHistory();

  Future<void> upsertNovelDetail(NovelDetailEntityData data) => _db.upsertNovelDetail(data);

  Future<NovelDetailEntityData?> getNovelDetail(String aid) => _db.getNovelDetail(aid);

  Future<void> deleteNovelDetail(String aid) => _db.deleteNovelDetail(aid);

  Future<void> deleteAllNovelDetail() => _db.deleteAllNovelDetail();

  Future<void> ensureAiAnalysisTables() => _db.ensureAiAnalysisTables();

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
  }) => _db.upsertAiBook(
        aid: aid,
        title: title,
        sourceType: sourceType,
        lastAnalyzedCid: lastAnalyzedCid,
        lastAnalyzedAt: lastAnalyzedAt,
        latestBookSummary: latestBookSummary,
        latestArcSummary: latestArcSummary,
        characterCount: characterCount,
        relationCount: relationCount,
      );

  Future<void> upsertAiChapterAnalysis({
    required String aid,
    required String cid,
    required String chapterTitle,
    required ChapterAnalysisResult result,
    required int promptVersion,
    required int maxRequestTokens,
    required int maxResponseTokens,
    required String snapshotJsonPath,
  }) => _db.upsertAiChapterAnalysis(
        aid: aid,
        cid: cid,
        chapterTitle: chapterTitle,
        result: result,
        promptVersion: promptVersion,
        maxRequestTokens: maxRequestTokens,
        maxResponseTokens: maxResponseTokens,
        snapshotJsonPath: snapshotJsonPath,
      );

  Future<AiChapterAnalysisRecord?> getAiChapterAnalysis(String aid, String cid) => _db.getAiChapterAnalysis(aid, cid);

  Future<List<AiBookRecord>> getAiBooks() => _db.getAiBooks();

  Future<AiBookRecord?> getAiBook(String aid) => _db.getAiBook(aid);

  Future<void> deleteAiAnalysisByAid(String aid) => _db.deleteAiAnalysisByAid(aid);

  Future<void> upsertAiMemoryRow({
    required String aid,
    required String rowType,
    required String rowKey,
    required String timeSpan,
    required String content,
    required String refCid,
    required int orderNo,
  }) => _db.upsertAiMemoryRow(
        aid: aid,
        rowType: rowType,
        rowKey: rowKey,
        timeSpan: timeSpan,
        content: content,
        refCid: refCid,
        orderNo: orderNo,
      );

  Future<List<AiMemoryRowRecord>> getAiMemoryRows(String aid, {String? rowType}) => _db.getAiMemoryRows(aid, rowType: rowType);

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
  }) => _db.upsertAiCharacterState(
        aid: aid,
        name: name,
        aliasesJson: aliasesJson,
        profileSummary: profileSummary,
        firstSeenCid: firstSeenCid,
        lastSeenCid: lastSeenCid,
        appearanceCount: appearanceCount,
        tier: tier,
        importanceScore: importanceScore,
      );

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
  }) => _db.upsertAiRelationState(
        aid: aid,
        fromName: fromName,
        toName: toName,
        relationLabel: relationLabel,
        relationSummary: relationSummary,
        firstSeenCid: firstSeenCid,
        lastSeenCid: lastSeenCid,
        mentionCount: mentionCount,
        strengthScore: strengthScore,
      );

  Future<List<AiCharacterStateRecord>> getAiCharacterStates(String aid) => _db.getAiCharacterStates(aid);

  Future<List<AiRelationStateRecord>> getAiRelationStates(String aid) => _db.getAiRelationStates(aid);
}
