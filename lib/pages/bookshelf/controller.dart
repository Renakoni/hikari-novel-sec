import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/bookshelf.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/models/resource.dart';
import 'package:hikari_novel_flutter/network/api.dart';
import 'package:hikari_novel_flutter/network/parser.dart';
import 'package:hikari_novel_flutter/pages/main/controller.dart';
import 'package:hikari_novel_flutter/service/local_book_service.dart';
import 'package:lpinyin/lpinyin.dart';

import '../../common/database/database.dart';
import '../../widgets/state_page.dart';
import '../../service/db_service.dart';

class BookshelfController extends GetxController with GetTickerProviderStateMixin {
  RxInt tabIndex = 0.obs; //淇濆瓨tab绱㈠紩浣嶇疆

  Rx<PageState> pageState = Rx(PageState.bookshelfContent);

  late TabController tabController;
  final List tabs = ["0", "1", "2", "3", "4", "5"];

  RxBool isSelectionMode = false.obs;
  RxSet<String> selectedTags = <String>{}.obs;

  @override
  void onInit() {
    tabController = TabController(length: tabs.length, vsync: this, initialIndex: tabIndex.value);
    super.onInit();
  }

  Future<void> refreshDefaultBookshelf() async {
    final localBooks = await LocalBookService.getLocalBookshelfEntries();
    await DBService.instance.deleteDefaultBookshelf();
    await _insertAll(0);
    if (localBooks.isNotEmpty) {
      await DBService.instance.insertAllBookshelf(localBooks.where((book) => book.classId == "0"));
    }
  }

  Future<String> refreshBookshelf() async {
    final localBooks = await LocalBookService.getLocalBookshelfEntries();
    await DBService.instance.deleteAllBookshelf();

    final futures = Iterable.generate(6, (index) async {
      final result = await _insertAll(index);
      if (!result) return "update_failed".tr;
    });
    await Future.wait(futures);
    if (localBooks.isNotEmpty) {
      await DBService.instance.insertAllBookshelf(localBooks);
    }
    return "update_successfully".tr;
  }

  Future<bool> _insertAll(int index) async {
    final result = await Api.getBookshelf(classId: index);
    switch (result) {
      case Success():
        {
          final bookshelf = Parser.getBookshelf(result.data, index);
          if (bookshelf.list.isNotEmpty) {
            final insertData = bookshelf.list.map((e) {
              return BookshelfEntityData(aid: e.aid, bid: e.bid, url: e.url, title: e.title, img: e.img, classId: bookshelf.classId.toString());
            });
            await DBService.instance.insertAllBookshelf(insertData);
          }
          return true;
        }
      case Error():
        {
          return false;
        }
    }
  }

  Future<List<String>> getAvailableTagsForClass(String classId) async {
    final entries = await DBService.instance.getAllBookshelf();
    final classEntries = entries.where((item) => item.classId == classId);
    return _collectAvailableTags(classEntries);
  }

  Future<List<String>> getAvailableTags() async {
    final entries = await DBService.instance.getAllBookshelf();
    return _collectAvailableTags(entries);
  }

  Future<List<String>> _collectAvailableTags(Iterable<BookshelfEntityData> entries) async {
    final tags = <String>{};

    for (final entry in entries) {
      final detail = await DBService.instance.getNovelDetail(entry.aid);
      if (detail == null) continue;
      try {
        final novelDetail = NovelDetail.fromString(detail.json);
        tags.addAll(novelDetail.tags);
        tags.addAll(novelDetail.personalTags);
      } catch (_) {
        continue;
      }
    }

    final result = tags.toList()..sort(_compareTagsForDisplay);
    return result;
  }

  int _compareTagsForDisplay(String a, String b) {
    final aLatin = _isLatinLeading(a);
    final bLatin = _isLatinLeading(b);
    if (aLatin != bLatin) {
      return aLatin ? -1 : 1;
    }

    final aKey = aLatin ? a.toLowerCase() : PinyinHelper.getPinyinE(a, separator: '', format: PinyinFormat.WITHOUT_TONE).toLowerCase();
    final bKey = bLatin ? b.toLowerCase() : PinyinHelper.getPinyinE(b, separator: '', format: PinyinFormat.WITHOUT_TONE).toLowerCase();

    final byKey = aKey.compareTo(bKey);
    if (byKey != 0) return byKey;
    return a.compareTo(b);
  }

  bool _isLatinLeading(String value) {
    if (value.isEmpty) return true;
    final code = value.codeUnitAt(0);
    final isAsciiLetter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    final isAsciiDigit = code >= 48 && code <= 57;
    return isAsciiLetter || isAsciiDigit;
  }

  void clearTagFilters() => selectedTags.clear();

  void toggleTagFilter(String tag) {
    if (tag.isEmpty) return;
    if (selectedTags.contains(tag)) {
      selectedTags.remove(tag);
    } else {
      selectedTags.add(tag);
    }
    selectedTags.refresh();
  }
}

class BookshelfContentController extends GetxController {
  final String classId;

  BookshelfContentController({required this.classId});

  final BookshelfController _bookshelfController = Get.find();
  final MainController _mainController = Get.find();

  bool get isSelectionMode => _bookshelfController.isSelectionMode.value;

  Rxn<Bookshelf> bookshelf = Rxn();
  Rx<PageState> pageState = Rx(PageState.loading);
  String errorMsg = "";
  List<BookshelfNovelInfo> _allBooks = [];

  @override
  void onReady() {
    super.onReady();

    DBService.instance.getBookshelfByClassId(classId).listen((bss) async {
      _allBooks = bss.map((i) => BookshelfNovelInfo(bid: i.bid, aid: i.aid, url: i.url, title: i.title, img: i.img)).toList();
      await _applyFilter();
    });

    ever<Set<String>>(_bookshelfController.selectedTags, (_) async {
      await _applyFilter();
    });
  }

  Future<void> _applyFilter() async {
    final selectedTags = _bookshelfController.selectedTags.toSet();
    List<BookshelfNovelInfo> list = _allBooks;

    if (selectedTags.isNotEmpty) {
      final filtered = <BookshelfNovelInfo>[];
      for (final item in _allBooks) {
        final detail = await DBService.instance.getNovelDetail(item.aid);
        if (detail == null) continue;
        try {
          final novelDetail = NovelDetail.fromString(detail.json);
          final tags = {...novelDetail.tags, ...novelDetail.personalTags};
          if (tags.intersection(selectedTags).isNotEmpty) {
            filtered.add(item);
          }
        } catch (_) {
          continue;
        }
      }
      list = filtered;
    }

    if (list.isEmpty) {
      bookshelf.value = null;
      pageState.value = PageState.empty;
    } else {
      bookshelf.value = Bookshelf(list: list, classId: classId);
      pageState.value = PageState.success;
    }
  }

  void toggleCoverSelection(String aid) {
    if (LocalBookService.isLocalAid(aid)) return;
    final selected = bookshelf.value!.list.firstWhere((v) => v.aid == aid).isSelected.value;
    bookshelf.value!.list.firstWhere((v) => v.aid == aid).isSelected.value = !selected;
  }

  Future<void> handleBookTap(BookshelfNovelInfo item) async {
    if (!isSelectionMode) return;
    if (LocalBookService.isLocalAid(item.aid)) {
      showSnackBar(message: "本地导入书籍不参与当前批量网络操作", context: Get.context!);
      return;
    }
    toggleCoverSelection(item.aid);
  }

  Future<void> handleBookLongPress(BookshelfNovelInfo item) async {
    if (LocalBookService.isLocalAid(item.aid)) {
      await _showLocalBookActions(item);
      return;
    }
    if (!isSelectionMode) {
      enterSelectionMode();
      toggleCoverSelection(item.aid);
    }
  }

  Future<void> _showLocalBookActions(BookshelfNovelInfo item) async {
    final context = Get.context;
    if (context == null) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(item.title),
                    subtitle: Text(_localBookSubtitle(item.aid)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline),
                    title: const Text("从书架移除"),
                    subtitle: const Text("仅从当前书架移除，保留应用内部缓存文件"),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _confirmLocalAction(
                        title: "从书架移除",
                        message: "这本本地书将从当前书架消失。应用内部已导入的内容和缓存文件仍会保留，但不会继续在书架中显示。",
                        action: () => LocalBookService.removeFromBookshelf(item.aid),
                        successMessage: "已从书架移除",
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: Theme.of(sheetContext).colorScheme.error),
                    title: Text("删除导入记录和缓存文件", style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                    subtitle: const Text("会一并删除图片、章节缓存和导入副本"),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await _confirmLocalAction(
                        title: "彻底删除本地书",
                        message: "这会删除导入记录、书架项、阅读历史，以及应用内部保存的图片、章节缓存和导入副本。此操作不可逆。",
                        action: () => LocalBookService.deleteImportedRecordAndFiles(item.aid),
                        successMessage: "已彻底删除本地书",
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _localBookSubtitle(String aid) {
    if (LocalBookService.isMarkdownAid(aid)) return "本地 Markdown，Local 标签不可删除";
    if (LocalBookService.isTxtAid(aid)) return "本地 TXT，Local 标签不可删除";
    return "本地 EPUB，Local 标签不可删除";
  }

  Future<void> _confirmLocalAction({
    required String title,
    required String message,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text("取消")),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text("确定")),
        ],
      ),
    );

    if (confirmed != true) return;

    await action();
    showSnackBar(message: successMessage, context: Get.context!);
  }

  Future removeNovelFromList() => Api.removeNovelFromList(list: getSelectedNovel(), classId: int.parse(classId));

  Future moveNovelToOther(int newClassId) =>
    Api.moveNovelToOther(list: getSelectedNovel(), classId: int.parse(classId), newClassId: newClassId);


  List<String> getSelectedNovel() => bookshelf.value!.list.where((v) => v.isSelected.value == true).map((i) => i.bid).toList();

  void exitSelectionMode() {
    _bookshelfController.isSelectionMode.value = false;
    _mainController.showBookshelfBottomActionBar.value = false;
    deselect();
  }

  void enterSelectionMode() {
    _bookshelfController.isSelectionMode.value = true;
    _mainController.showBookshelfBottomActionBar.value = true;
  }

  void deselect() {
    for (final v in bookshelf.value!.list) {
      v.isSelected.value = false;
    }
  }

  void selectAll() {
    for (final v in bookshelf.value!.list) {
      v.isSelected.value = true;
    }
  }
}

class BookshelfSearchController extends GetxController {
  final _bookshelfController = Get.find<BookshelfController>();
  final searchTextEditController = Get.find<TextEditingController>(tag: "searchTextEditController");

  RxList<BookshelfNovelInfo> data = RxList();
  Rx<PageState> pageState = Rx(PageState.placeholder);
  RxList<String> availableTags = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshAvailableTags();
    refreshResults();
    ever<Set<String>>(_bookshelfController.selectedTags, (_) {
      refreshResults();
    });
  }

  Future<void> refreshAvailableTags() async {
    availableTags.assignAll(await _bookshelfController.getAvailableTags());
  }

  Future<void> refreshResults() async {
    final keyword = searchTextEditController.text.trim();
    final selectedTags = _bookshelfController.selectedTags.toSet();

    if (keyword.isEmpty && selectedTags.isEmpty) {
      data.clear();
      pageState.value = PageState.placeholder;
      return;
    }

    final source = keyword.isEmpty
        ? await DBService.instance.getAllBookshelf()
        : await DBService.instance.getBookshelfByKeyword(keyword);
    final matched = <BookshelfNovelInfo>[];

    for (final item in source) {
      if (selectedTags.isNotEmpty) {
        final detail = await DBService.instance.getNovelDetail(item.aid);
        if (detail == null) continue;
        try {
          final novelDetail = NovelDetail.fromString(detail.json);
          final tags = {...novelDetail.tags, ...novelDetail.personalTags};
          if (tags.intersection(selectedTags).isEmpty) continue;
        } catch (_) {
          continue;
        }
      }
      matched.add(BookshelfNovelInfo(bid: item.bid, aid: item.aid, url: item.url, title: item.title, img: item.img));
    }

    data.assignAll(matched);
    pageState.value = data.isEmpty ? PageState.empty : PageState.success;
  }

  void back() => _bookshelfController.pageState.value = PageState.bookshelfContent;
}

