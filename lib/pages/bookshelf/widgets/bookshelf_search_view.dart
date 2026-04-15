import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/page_state.dart';
import 'package:hikari_novel_flutter/pages/bookshelf/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

import '../../../widgets/novel_cover_card.dart';

class BookshelfSearchView extends StatelessWidget {
  BookshelfSearchView({super.key});

  final controller = Get.put(BookshelfSearchController());
  final bookshelfController = Get.find<BookshelfController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: controller.back),
        title: SizedBox(
          height: kToolbarHeight,
          child: TextField(
            controller: controller.searchTextEditController,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: "搜索书名或结合标签筛选",
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.searchTextEditController.clear();
                  controller.refreshResults();
                },
              ),
              border: InputBorder.none,
            ),
            onChanged: (text) {
              controller.refreshResults();
            },
            onSubmitted: (_) => controller.refreshResults(),
          ),
        ),
        titleSpacing: 0,
        actions: [
          Obx(
            () => IconButton(
              onPressed: () => _showTagFilter(context),
              icon: Icon(
                Icons.tune,
                color: bookshelfController.selectedTags.isEmpty ? null : Theme.of(context).colorScheme.primary,
              ),
              tooltip: bookshelfController.selectedTags.isEmpty ? "搜索与筛选" : "已筛选: ${bookshelfController.selectedTags.join(", ")}",
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Obx(
            () => Offstage(
              offstage: bookshelfController.selectedTags.isEmpty,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...bookshelfController.selectedTags.map(
                        (tag) => InputChip(
                          label: Text(tag),
                          onDeleted: () => bookshelfController.toggleTagFilter(tag),
                        ),
                      ),
                      ActionChip(
                        label: const Text("清空筛选"),
                        onPressed: bookshelfController.clearTagFilters,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Obx(
                  () => Offstage(
                    offstage: controller.pageState.value != PageState.success,
                    child: controller.data.isEmpty
                        ? Container()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: Obx(
                              () => ResponsiveGridList(
                                minItemWidth: 100,
                                horizontalGridSpacing: 4,
                                verticalGridSpacing: 4,
                                children: controller.data
                                    .map(
                                      (item) => BookshelfCoverCard(
                                        bookshelfNovelInfo: item,
                                        onTap: () => AppSubRouter.toNovelDetail(aid: item.aid),
                                        onLongPress: () {},
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                  ),
                ),
                Obx(() => Offstage(offstage: controller.pageState.value != PageState.empty, child: const EmptyPage())),
                Obx(() => Offstage(offstage: controller.pageState.value != PageState.placeholder, child: _PlaceholderPanel())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTagFilter(BuildContext context) async {
    await controller.refreshAvailableTags();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("搜索与筛选", style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    "标签会和当前搜索词一起生效。",
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text("全部标签"),
                        selected: bookshelfController.selectedTags.isEmpty,
                        showCheckmark: false,
                        onSelected: (_) {
                          bookshelfController.clearTagFilters();
                          controller.refreshResults();
                        },
                      ),
                      ...controller.availableTags.map(
                        (tag) => ChoiceChip(
                          label: Text(tag),
                          selected: bookshelfController.selectedTags.contains(tag),
                          showCheckmark: false,
                          onSelected: (_) {
                            bookshelfController.toggleTagFilter(tag);
                            controller.refreshResults();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (controller.availableTags.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "当前还没有可用标签。先打开一本书的详情页，或导入本地 EPUB。",
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search, size: 44, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              "输入书名，或结合标签筛选书架内容。",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
