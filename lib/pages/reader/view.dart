import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/log.dart';
import 'package:hikari_novel_flutter/models/reader_direction.dart';
import 'package:hikari_novel_flutter/pages/reader/controller.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/ai_chapter_analysis_page.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/ai_book_memory_page.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/custom_header.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/custom_slider.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/horizontal_read_page.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/markdown_read_page.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/reader_background.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/vertical_read_page.dart';
import 'package:hikari_novel_flutter/service/ai/ai_analysis_service.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
import 'package:intl/intl.dart';
import 'package:hikari_novel_flutter/service/tts_service.dart';
import 'package:hikari_novel_flutter/pages/reader/widgets/tts_floating_controller.dart';

import '../../common/constants.dart';
import '../../models/page_state.dart';
import '../../router/route_path.dart';
import '../../service/local_book_service.dart';

class ReaderPage extends StatelessWidget {
  ReaderPage({super.key});

  final controller = Get.put(ReaderController());

  final GlobalKey<VerticalReadPageState> _verticalReadPageKey = GlobalKey();

  EdgeInsets _contentPadding(BuildContext context, {required bool inPageStatusBar}) => EdgeInsets.fromLTRB(
    controller.readerSettingsState.value.leftMargin,
    controller.readerSettingsState.value.topMargin,
    controller.readerSettingsState.value.rightMargin,
    controller.readerSettingsState.value.showStatusBar
        ? controller.readerSettingsState.value.bottomMargin + kStatusBarPadding + (inPageStatusBar ? MediaQuery.of(context).padding.bottom : 0)
        : controller.readerSettingsState.value.bottomMargin,
  );

  TextStyle get textStyle => TextStyle(
    fontFamily: controller.readerSettingsState.value.textFamily,
    height: controller.readerSettingsState.value.lineSpacing,
    fontSize: controller.readerSettingsState.value.fontSize,
    color: controller.currentTextColor.value ?? Theme.of(Get.context!).colorScheme.onSurface,
  );

  bool _useOverlayBottomStatusBar() {
    final settings = controller.readerSettingsState.value;
    return settings.showStatusBar && settings.direction == ReaderDirection.upToDown;
  }

  bool _useInPageBottomStatusBar() {
    final settings = controller.readerSettingsState.value;
    return settings.showStatusBar && settings.direction != ReaderDirection.upToDown;
  }

  Future<void> _analyzeCurrentChapter(BuildContext context) async {
    final ai = AiAnalysisService.instance;
    try {
      if (!ai.config.isReady) {
        showSnackBar(message: "\u8bf7\u5148\u5728\u8bbe\u7f6e -> AI \u4e2d\u5b8c\u6210\u914d\u7f6e", context: context);
        return;
      }

      final text = controller.text.value;
      if (text.trim().isEmpty) {
        showSnackBar(message: "\u5f53\u524d\u7ae0\u8282\u8fd8\u5728\u52a0\u8f7d\u4e2d", context: context);
        return;
      }

      showSnackBar(
        message: "\u6b63\u5728\u5206\u6790\u5f53\u524d\u7ae0\u8282...",
        context: context,
        duration: const Duration(days: 1),
      );
      final result = await ai.analyzeChapter(
        aid: controller.aid,
        cid: controller.cid,
        chapterTitle: controller.chapterTitle.value,
        chapterText: text,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      await Get.to(() => AiChapterAnalysisPage(result: result));
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar(message: "AI \u5206\u6790\u5931\u8d25: $e", context: context);
    }
  }

  Future<void> _viewCurrentAnalysis(BuildContext context) async {
    final ai = AiAnalysisService.instance;
    final cached = await ai.loadAnalysis(aid: controller.aid, cid: controller.cid);
    if (cached == null) {
      showSnackBar(message: "\u5f53\u524d\u7ae0\u8282\u8fd8\u6ca1\u6709\u5206\u6790\u7ed3\u679c", context: context);
      return;
    }
    await Get.to(() => AiChapterAnalysisPage(result: cached));
  }

  Future<void> _showAiActionSheet(BuildContext context) async {
    final ai = AiAnalysisService.instance;
    final hasResult = await ai.loadAnalysis(aid: controller.aid, cid: controller.cid) != null;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.72),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        hasResult ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: hasResult ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      title: const Text('\u67e5\u770b\u672c\u7ae0\u5206\u6790'),
                      subtitle: Text(
                        hasResult
                            ? '\u6253\u5f00\u5f53\u524d\u7ae0\u8282\u7684\u5206\u6790\u7ed3\u679c'
                            : '\u8bf7\u5148\u5206\u6790\u5f53\u524d\u7ae0\u8282',
                      ),
                      enabled: hasResult,
                      onTap: hasResult
                          ? () async {
                              Navigator.of(sheetContext).pop();
                              await _viewCurrentAnalysis(context);
                            }
                          : null,
                    ),
                    ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('\u5206\u6790\u5f53\u524d\u7ae0\u8282'),
                      subtitle: Text(
                        hasResult
                            ? '\u5df2\u6709\u7ed3\u679c\uff0c\u518d\u6b21\u5206\u6790\u4f1a\u8986\u76d6\u65e7\u7ed3\u679c'
                            : '\u751f\u6210\u5f53\u524d\u7ae0\u8282\u7684\u65b0\u5206\u6790',
                      ),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await _analyzeCurrentChapter(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const Text('\u67e5\u770b\u672c\u4e66 AI \u8bb0\u5fc6'),
                      subtitle: const Text('\u67e5\u770b\u7eaa\u8981\u3001\u5927\u7eb2\u3001\u4eba\u7269\u72b6\u6001\u548c\u5173\u7cfb\u72b6\u6001'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Get.to(() => AiBookMemoryPage(aid: controller.aid));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final supportsAi = LocalBookService.supportsAiAnalysis(controller.aid);
    return Scaffold(
      body: Stack(
        children: [
          Obx(
            () => controller.pageState.value == PageState.success
                ? ReaderBackground(
                    child: Obx(
                      () => Padding(
                        padding: EdgeInsets.only(
                          bottom: _useOverlayBottomStatusBar()
                              ? kStatusBarPadding + MediaQuery.of(context).padding.bottom
                              : 0,
                        ),
                        child: _buildReadPage(context),
                      ),
                    ),
                  )
                : Container(),
          ),
          Obx(() => Offstage(offstage: controller.pageState.value != PageState.loading, child: const LoadingPage())),
          Obx(
            () => Offstage(
              offstage: controller.pageState.value != PageState.error,
              child: ErrorMessage(msg: controller.errorMsg, action: controller.getContent),
            ),
          ),
          _buildBottomStatusBar(context),
          const TtsFloatingController(),
          Obx(() {
            //濠碉紕鍋戦崐娑㈠春閺嶎厽鍋?
            double statusBarHeight = MediaQuery.of(context).padding.top;
            return AnimatedPositioned(
              top: controller.showBar.value ? 0 : -(kToolbarHeight + statusBarHeight),
              left: 0,
              right: 0,
              duration: Duration(milliseconds: 100),
              child: AppBar(
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                titleSpacing: 0,
                title: Text(
                  controller.chapterTitle.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: supportsAi
                    ? [
                        IconButton(
                          tooltip: "AI \u7ae0\u8282\u5206\u6790",
                          onPressed: () => _showAiActionSheet(context),
                          icon: const Icon(Icons.auto_awesome_outlined),
                        ),
                      ]
                    : null,
              ),
            );
          }),
          Obx(() {
            //闂佸湱鍘ч悺銊ッ哄鈧幃?
            double navigationBarHeight = MediaQuery.of(context).padding.bottom;
            int bottomBarHeight = 100;
            return AnimatedPositioned(
              left: 0,
              right: 0,
              bottom: controller.showBar.value ? 0 : -(navigationBarHeight + bottomBarHeight),
              duration: const Duration(milliseconds: 100),
              child: Container(
                height: navigationBarHeight + bottomBarHeight,
                color: Theme.of(context).colorScheme.secondaryContainer,
                alignment: Alignment.center,
                child: Obx(
                  () => Column(
                    children: [
                      SizedBox(width: double.infinity, child: _buildProgressBar(context)),
                      Row(
                        children: [
                          Expanded(
                            child: IconButton(
                              onPressed: () {
                                if (controller.readerSettingsState.value.direction == ReaderDirection.rightToLeft) {
                                  controller.nextChapter();
                                } else {
                                  controller.prevChapter();
                                }
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                          ),
                          Expanded(
                            child: IconButton(onPressed: () => _showCatalogue(context), icon: const Icon(Icons.list_alt)),
                          ),
                          Expanded(
                            child: IconButton(onPressed: () => Get.toNamed(RoutePath.readerSetting), icon: const Icon(Icons.settings_outlined)),
                          ),
                          TtsService.instance.enabled.value
                              ? Expanded(
                                  child: IconButton(
                                    tooltip: "listen_to_books".tr,
                                    onPressed: () async {
                                      final tts = TtsService.instance;
                                      final text = controller.text.value;
                                      if (text.trim().isEmpty) {
                                        showSnackBar(message: "chapter_content_loading_tip".tr, context: context);
                                        return;
                                      }

                                      if (tts.isPlaying.value) {
                                        await tts.stop();
                                        return;
                                      }
                                      if (tts.isPaused.value && tts.isSessionActive.value) {
                                        await tts.resumeSession();
                                        return;
                                      }

                                      await tts.startChapter(text);
                                    },
                                    icon: Obx(() {
                                      final tts = TtsService.instance;
                                      if (tts.isPlaying.value) {
                                        return const Icon(Icons.stop_circle_outlined);
                                      }
                                      return const Icon(Icons.play_circle_outline);
                                    }),
                                  ),
                                )
                              : Container(),
                          Expanded(
                            child: IconButton(
                              onPressed: () {
                                if (controller.readerSettingsState.value.direction == ReaderDirection.rightToLeft) {
                                  controller.prevChapter();
                                } else {
                                  controller.nextChapter();
                                }
                              },
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReadPage(BuildContext context) {
    return Obx(() {
      if (controller.pageState.value == PageState.success) {
        if (LocalBookService.isMarkdownAid(controller.aid)) {
          return MarkdownReadPage(
            data: controller.markdownText.value,
            padding: _contentPadding(context, inPageStatusBar: false),
            textColor: controller.currentTextColor.value ?? Theme.of(context).colorScheme.onSurface,
          );
        }
        return controller.readerSettingsState.value.direction == ReaderDirection.upToDown ? _buildVertical(context) : _buildHorizontal(context);
      } else {
        return Container();
      }
    });
  }

  Widget _buildVertical(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => controller.showBar.value = !controller.showBar.value,
      child: SizedBox(
        height: double.infinity,
        child: EasyRefresh(
          header: MaterialHeader2(
            triggerOffset: 80,
            child: Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.arrow_circle_up, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          footer: MaterialFooter2(
            triggerOffset: 80,
            child: Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.arrow_circle_down, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          refreshOnStart: false,
          onRefresh: controller.prevChapter,
          onLoad: controller.nextChapter,
          child: VerticalReadPage(
            key: _verticalReadPageKey,
            controller.text.value,
            controller.images,
            initialOffset: controller.initialVerticalOffset,
            padding: _contentPadding(context, inPageStatusBar: false),
            style: textStyle,
            paraSpacing: controller.readerSettingsState.value.readerParaSpacing,
            paraIndent: controller.readerSettingsState.value.readerParaIndent,
            onScroll: (position, max) {
              if (max == 0 && position == 0) {
                controller.currentLocation.value = 0;
                controller.verticalProgress.value = 100;
                controller.setReadHistory();
              } else if (max > 0) {
                controller.currentLocation.value = position.toInt();
                controller.verticalProgress.value = ((position.toInt() / max.toInt()) * 100).clamp(0, 100).toInt();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    final usePaperCurl = controller.readerSettingsState.value.pageTurningAnimation;
    final horizontalReader = HorizontalReadPage(
      controller.text.value,
      controller.images,
      initIndex: controller.initialHorizontalIndex,
      padding: _contentPadding(context, inPageStatusBar: _useInPageBottomStatusBar()),
      style: textStyle,
      reverse: controller.readerSettingsState.value.direction == ReaderDirection.rightToLeft,
      isDualPage: controller.isDualPage,
      dualPageSpacing: controller.readerSettingsState.value.dualPageSpacing,
      controller: controller.pageController,
      pageTurningAnimation: controller.readerSettingsState.value.pageTurningAnimation,
      paraSpacing: controller.readerSettingsState.value.readerParaSpacing,
      paraIndent: controller.readerSettingsState.value.readerParaIndent,
      paperCurlController: controller.paperCurlController,
      backgroundColor: controller.currentBgColor.value ?? Theme.of(context).colorScheme.surface,
      backsideColor: Color.lerp(
        controller.currentBgColor.value ?? Theme.of(context).colorScheme.surface,
        Theme.of(context).colorScheme.surfaceTint,
        Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10,
      ),
      pageFooter: _useInPageBottomStatusBar() ? _buildInPageStatusBar(context) : null,
      onCenterTap: () => controller.showBar.value = !controller.showBar.value,
      onLeftTap: controller.prevPage,
      onRightTap: controller.nextPage,
      onReachStart: controller.prevChapter,
      onReachEnd: controller.nextChapter,
      onPageChanged: (index, max) {
        controller.currentIndex.value = index;
        controller.maxPage.value = max;
        if (max == 1 && index == 0) {
          //濠电偛顕慨鎾箠瀹ュ洨鍗氶悗娑櫱滄禍婊堟煟閵忕姷浠涢柣锝変憾閺岀喖顢涘顓炴闂佸摜濮撮張顒傜矙?
          controller.horizontalProgress.value = 100;
          controller.setReadHistory(); //缂傚倷鐒﹂弻銊╊敄閸涱厾鏆ら柛鈩冪☉閸楁娊鎮楀☉娅虫垿鎮￠埀顒勬⒑閸涘⊕顏勎涘Δ鍕╀汗闁割偅娲橀埛鎾绘煕濞戙垹浜伴柛銈冨灲閹鎷呯憴鍕嚒缂?
        } else if (max > 0) {
          controller.horizontalProgress.value = int.parse(((index + 1) / max * 100.0).toStringAsFixed(0)).clamp(0, 100);
          //闂備焦鐪归崹璇层€掔粵绯縯roller闂備焦鐪归崝宀勫垂缁⒔ounce闂備胶鍎甸弲婊堝垂閻㈢绠氬┑澶涚rrentIndex闂備礁鎲￠悷锕傛晪闁诲骸鐏氶悡锟犲极瀹ュ洣娌柦妯侯槺娴煎牓姊洪崫鍕簽闁告妫勫嵄闁归棿绀佺憴锕傛煥閺冨洤袚缂佺虎鍨堕弻锟犲磼濞戞瑧鍑￠悗鍦焾椤嘲鐣烽敐澶婅摕闁靛瀵屽鎰版煟閻樺弶澶勬俊鍙夊浮椤㈡瑩宕堕鍌欐睏?
        }
      },
      onViewImage: (index) => Get.toNamed(RoutePath.photo, arguments: {"gallery_mode": true, "list": controller.images, "index": index}),
    );

    if (usePaperCurl) {
      return horizontalReader;
    }

    return EasyRefresh(
      header: MaterialHeader2(
        triggerOffset: 80,
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(12),
          child: Icon(Icons.arrow_circle_left_outlined, color: Theme.of(context).colorScheme.primary),
        ),
      ),
      footer: MaterialFooter2(
        triggerOffset: 80,
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(12),
          child: Icon(Icons.arrow_circle_right_outlined, color: Theme.of(context).colorScheme.primary),
        ),
      ),
      refreshOnStart: false,
      onRefresh: controller.prevChapter,
      onLoad: controller.nextChapter,
      child: horizontalReader,
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Obx(() {
      if (controller.pageState.value != PageState.success) return SizedBox(height: 48, child: Container());
      if (controller.readerSettingsState.value.direction == ReaderDirection.upToDown) {
        int value = controller.verticalProgress.value;

        return SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(width: 60, child: Center(child: Text("$value%"))),
              Expanded(
                child: Slider(
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Theme.of(context).colorScheme.surface,
                  value: value.toDouble(),
                  max: 100.0,
                  onChanged: (e) {
                    _verticalReadPageKey.currentState!.jumpToProgress(e);
                  },
                  divisions: 99,
                ),
              ),
              SizedBox(width: 60, child: Center(child: Text("100%"))),
            ],
          ),
        );
      } else {
        int value = controller.currentIndex.value + 1;
        int max = controller.maxPage.value;

        if (value > max || max == 1) {
          return SizedBox(height: 48, child: Center(child: Text("only_one_page".tr)));
        }
        return SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Center(
                  child: controller.readerSettingsState.value.direction == ReaderDirection.leftToRight ? Text(value.toString()) : Text(max.toString()),
                ),
              ),
              Expanded(
                child: CustomSlider(
                  min: 1,
                  max: max.toDouble(),
                  value: value.toDouble(),
                  divisions: max - 1,
                  onChanged: (v) => controller.jumpToPage((v - 1).toInt()),
                  focusNode: null,
                  reversed: controller.readerSettingsState.value.direction != ReaderDirection.leftToRight,
                ),
              ),
              SizedBox(
                width: 60,
                child: Center(
                  child: controller.readerSettingsState.value.direction == ReaderDirection.leftToRight ? Text(max.toString()) : Text(value.toString()),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  void _showCatalogue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: BottomSheet(
          onClosing: () {},
          builder: (_) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: controller.catalogue.length,
                  itemBuilder: (context, volumeIndex) {
                    final volume = controller.catalogue[volumeIndex];

                    return ExpansionTile(
                      shape: const Border(),
                      title: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(volume.title, style: const TextStyle(fontSize: 15)),
                      ),
                      children: volume.chapters.asMap().entries.map((entry) {
                        final chapterIndex = entry.key;
                        final chapter = entry.value;

                        return ListTile(
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              volumeIndex == controller.currentVolumeIndex && chapterIndex == controller.currentChapterIndex
                                  ? Row(
                                      children: [
                                        SizedBox(height: 22, child: Icon(Icons.arrow_circle_right, color: Theme.of(context).colorScheme.primary)),
                                        const SizedBox(width: 10),
                                      ],
                                    )
                                  : Container(),
                              Text(
                                chapter.title,
                                style: volumeIndex == controller.currentVolumeIndex && chapterIndex == controller.currentChapterIndex
                                    ? TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                                    : const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.only(left: 50.0, right: 10.0),
                          onTap: () {
                            controller.currentVolumeIndex = volumeIndex;
                            controller.currentChapterIndex = chapterIndex;
                            controller.getContent();
                            Get.back();
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStatusBar(BuildContext context) {
    final spacing = controller.readerSettingsState.value.readerBottomStatusBarHorizontalSpacing.toDouble();
    return Positioned(
      right: 8,
      left: 8,
      bottom: 4,
      child: Obx(
        () => Offstage(
          offstage: !(_useOverlayBottomStatusBar() && controller.pageState.value == PageState.success),
          child: Padding(
            padding: EdgeInsets.fromLTRB(spacing, 0, spacing, MediaQuery.of(context).padding.bottom),
            child: _buildStatusBarContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInPageStatusBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final spacing = controller.readerSettingsState.value.readerBottomStatusBarHorizontalSpacing.toDouble();
    return SizedBox(
      width: double.infinity,
      height: kStatusBarPadding.toDouble() + bottomInset,
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing, 0, spacing, bottomInset),
        child: _buildStatusBarContent(context),
      ),
    );
  }

  Widget _buildStatusBarContent(BuildContext context) {
    return Obx(() {
      final textColor = controller.currentTextColor.value ?? Theme.of(context).colorScheme.onSurface;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StreamBuilder(
            stream: controller.clockStream(),
            builder: (_, snapshot) {
              final now = snapshot.data ?? DateTime.now();
              final timeString = DateFormat('HH:mm').format(now);
              return Text(timeString, style: TextStyle(fontSize: 13, color: textColor));
            },
          ),
          const SizedBox(width: 8),
          IconTheme(
            data: IconThemeData(color: textColor),
            child: _buildBattery(context, controller.batteryLevel.value),
          ),
          Text("${controller.batteryLevel.value}%", style: TextStyle(fontSize: 13, color: textColor)),
          const Spacer(),
          controller.readerSettingsState.value.direction == ReaderDirection.upToDown
              ? Text("${controller.verticalProgress.value} %", style: TextStyle(fontSize: 13, color: textColor))
              : Text(
                  "${controller.currentIndex.value + 1} / ${controller.maxPage.value}",
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
        ],
      );
    });
  }

  Widget _buildBattery(BuildContext context, int value) {
    if (value >= 95) {
      return const Icon(Icons.battery_full, size: kSmallIconSize);
    } else if (value >= 85) {
      return const Icon(Icons.battery_6_bar, size: kSmallIconSize); // ~90%
    } else if (value >= 65) {
      return const Icon(Icons.battery_5_bar, size: kSmallIconSize); // ~80%
    } else if (value >= 45) {
      return const Icon(Icons.battery_4_bar, size: kSmallIconSize); // ~60%
    } else if (value >= 35) {
      return const Icon(Icons.battery_3_bar, size: kSmallIconSize); // ~50%
    } else if (value >= 25) {
      return const Icon(Icons.battery_2_bar, size: kSmallIconSize); // ~30%
    } else if (value >= 15) {
      return const Icon(Icons.battery_1_bar, size: kSmallIconSize); // ~20%
    } else {
      return const Icon(Icons.battery_0_bar, size: kSmallIconSize); // <15%
    }
  }
}
