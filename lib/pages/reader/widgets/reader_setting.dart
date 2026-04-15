import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/extension.dart';
import 'package:hikari_novel_flutter/models/tts_provider_type.dart';
import 'package:hikari_novel_flutter/service/ai/ai_analysis_service.dart';
import 'package:hikari_novel_flutter/service/tts_service.dart';
import 'package:hikari_novel_flutter/widgets/custom_tile.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../../../models/dual_page_mode.dart';
import '../../../models/reader_direction.dart';
import 'ai_chapter_analysis_page.dart';
import '../controller.dart';

class ReaderSettingPage extends StatelessWidget {
  ReaderSettingPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  final ReaderController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialTabIndex,
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text("setting".tr),
          titleSpacing: 0,
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.settings_outlined), text: "basic".tr),
              Tab(icon: const Icon(Icons.palette_outlined), text: "theme".tr),
              Tab(icon: const Icon(Icons.record_voice_over_outlined), text: "listen_to_books".tr),
              const Tab(icon: Icon(Icons.auto_awesome_outlined), text: "AI"),
              Tab(icon: const Icon(Icons.padding), text: "margin".tr),
            ],
          ),
        ),
        body: TabBarView(children: [_buildBasic(context), _buildTheme(context), _buildListen(context), _buildAiAnalysis(context), _buildPadding()]),
      ),
    );
  }

  Widget _buildBasic(BuildContext context) {
    return ListView(
      children: [
        Obx(
          () => SliderTile(
            title: "font_size".tr,
            leading: const Icon(Icons.format_size),
            min: 7,
            max: 48,
            divisions: 41,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.fontSize,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(fontSize: value),
            onChangeEnd: (value) => controller.changeFontSize(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "line_spacing".tr,
            leading: const Icon(Icons.format_line_spacing_outlined),
            min: 0.1,
            max: 3,
            divisions: 29,
            decimalPlaces: 1,
            value: controller.readerSettingsState.value.lineSpacing,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(lineSpacing: value),
            onChangeEnd: (value) => controller.changeLineSpacing(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "para_indent".tr,
            leading: const Icon(Icons.format_indent_increase),
            min: 0,
            max: 10,
            divisions: 10,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.readerParaIndent,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(readerParaIndent: value.toInt()),
            onChangeEnd: (value) => controller.changeReaderParaIndent(value.toInt()),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "para_spacing".tr,
            leading: const Icon(Icons.expand),
            min: 0,
            max: 50,
            divisions: 50,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.readerParaSpacing,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(readerParaSpacing: value.toInt()),
            onChangeEnd: (value) => controller.changeReaderParaSpacing(value.toInt()),
          ),
        ),
        Obx(() {
          final sub = switch (controller.readerSettingsState.value.direction) {
            ReaderDirection.leftToRight => "left_to_right".tr,
            ReaderDirection.rightToLeft => "right_to_left".tr,
            ReaderDirection.upToDown => "scroll".tr,
          };
          return NormalTile(
            title: "reading_direction".tr,
            subtitle: sub,
            leading: const Icon(Icons.chrome_reader_mode_outlined),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: () =>
                Get.dialog(
                  RadioListDialog(
                    value: controller.readerSettingsState.value.direction,
                    values: [
                      (ReaderDirection.upToDown, "scroll".tr),
                      (ReaderDirection.leftToRight, "left_to_right".tr),
                      (ReaderDirection.rightToLeft, "right_to_left".tr),
                    ],
                    title: "reading_direction".tr,
                  ),
                ).then((value) {
                  if (value != null) controller.changeReaderDirection(value);
                }),
          );
        }),
        Obx(
          () => Offstage(
            offstage: controller.readerSettingsState.value.direction == ReaderDirection.upToDown,
            child: SwitchTile(
              title: "page_turning_animation".tr,
              leading: const Icon(Icons.animation),
              onChanged: (enabled) => controller.changeReaderPageTurningAnimation(enabled),
              value: controller.readerSettingsState.value.pageTurningAnimation,
            ),
          ),
        ),
        Obx(
          () => SwitchTile(
            title: "screen_stays_on".tr,
            leading: const Icon(Icons.lightbulb_outlined),
            onChanged: (enabled) => controller.changeReaderWakeLock(enabled),
            value: controller.readerSettingsState.value.wakeLock,
          ),
        ),
        Offstage(
          offstage: !(Platform.isAndroid || Platform.isIOS),
          child: Obx(
            () => SwitchTile(
              title: "immersive_mode".tr,
              leading: const Icon(Icons.width_full_outlined),
              onChanged: (enabled) => controller.changeImmersionMode(enabled),
              value: controller.readerSettingsState.value.immersionMode,
            ),
          ),
        ),
        Obx(
          () => SwitchTile(
            title: "show_status_bar".tr,
            leading: const Icon(Icons.call_to_action_outlined),
            onChanged: (enabled) => controller.changeShowStatusBar(enabled),
            value: controller.readerSettingsState.value.showStatusBar,
          ),
        ),
        Obx(
          () => Offstage(
            offstage: controller.readerSettingsState.value.direction == ReaderDirection.upToDown,
            child: NormalTile(
              title: "dual_page".tr,
              subtitle: controller.readerSettingsState.value.dualPageMode.name.tr,
              leading: const Icon(Icons.looks_two_outlined),
              trailing: const Icon(Icons.keyboard_arrow_down),
              onTap: () =>
                  Get.dialog(
                    RadioListDialog(
                      value: controller.readerSettingsState.value.dualPageMode,
                      values: [(DualPageMode.auto, "auto".tr), (DualPageMode.enabled, "enable".tr), (DualPageMode.disabled, "disable".tr)],
                      title: "dual_page".tr,
                    ),
                  ).then((value) {
                    if (value != null) controller.changeDualPageMode(value);
                  }),
            ),
          ),
        ),
        Obx(() {
          final dualPageMode = switch (controller.readerSettingsState.value.dualPageMode) {
            DualPageMode.auto => Get.context!.shouldAutoUseDualPage(),
            DualPageMode.enabled => true,
            DualPageMode.disabled => false,
          };
          return Offstage(
            offstage: !dualPageMode || controller.readerSettingsState.value.direction == ReaderDirection.upToDown,
            child: SliderTile(
              title: "dual_page_spacing".tr,
              leading: const Icon(Icons.space_bar_outlined),
              min: 0,
              max: 60,
              divisions: 120,
              decimalPlaces: 1,
              value: controller.readerSettingsState.value.dualPageSpacing,
              onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(dualPageSpacing: value),
              onChangeEnd: (value) => controller.changeDualPageSpacing(value),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTheme(BuildContext context) {
    return ListView(
      children: [
        Obx(
          () => NormalTile(
            title: "font".tr,
            subtitle: controller.isFontFileAvailable.value ? controller.readerSettingsState.value.textFamily.toString() : "system_font".tr,
            leading: const Icon(Icons.format_shapes_outlined),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: () => Get.dialog(NormalListDialog(values: [(0, "system_font".tr), (1, "custom_font".tr)], title: "font".tr)).then((value) async {
              if (value == 0) {
                await controller.deleteFontDir();
                controller.changeReaderTextStyleFilePath(null);
                controller.changeReaderTextFamily(null);
                controller.checkFontFile(false);
                showSnackBar(message: "set_system_font_successfully".tr, context: Get.context!);
              } else if (value == 1) {
                final result = await controller.pickTextStyleFile();
                switch (result) {
                  case null:
                    return;
                  case true:
                    {
                      showSnackBar(message: "set_font_successfully".tr, context: Get.context!);
                      controller.checkFontFile(false);
                    }
                  case false:
                    showSnackBar(message: "set_font_failed".tr, context: Get.context!);
                }
              }
            }),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "font_color".tr,
            leading: const Icon(Icons.format_color_text_outlined),
            trailing: controller.currentTextColor.value == null
                ? const Icon(Icons.keyboard_arrow_down)
                : ColorIndicator(width: 20, height: 20, borderRadius: 100, color: controller.currentTextColor.value!),
            onTap: () => Get.dialog(NormalListDialog(values: [(0, "change_font_color".tr), (1, "reset_font_color".tr)], title: "font_color".tr)).then((value) {
              if (value == 0) {
                _buildColorPickerDialog(Get.context!, true);
              } else if (value == 1) {
                Get.context!.isDarkMode ? controller.changeReaderNightTextColor(null) : controller.changeReaderDayTextColor(null);
                showSnackBar(message: "reset_font_color_successfully".tr, context: Get.context!);
              }
            }),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "background_color".tr,
            leading: const Icon(Icons.format_color_fill_rounded),
            trailing: controller.currentBgColor.value == null
                ? const Icon(Icons.keyboard_arrow_down)
                : ColorIndicator(width: 20, height: 20, borderRadius: 100, color: controller.currentBgColor.value!),
            onTap: () =>
                Get.dialog(NormalListDialog(values: [(0, "change_background_color".tr), (1, "reset_background_color".tr)], title: "background_color".tr)).then((
                  value,
                ) {
                  if (value == 0) {
                    _buildColorPickerDialog(Get.context!, false);
                  } else if (value == 1) {
                    Get.context!.isDarkMode ? controller.changeReaderNightBgColor(null) : controller.changeReaderDayBgColor(null);
                    showSnackBar(message: "reset_background_color_successfully".tr, context: Get.context!);
                  }
                }),
          ),
        ),
        NormalTile(
          title: "background_image".tr,
          leading: const Icon(Icons.image_outlined),
          trailing: const Icon(Icons.keyboard_arrow_down),
          onTap: () => Get.dialog(NormalListDialog(values: [(0, "change_background_image".tr), (1, "reset_background_image".tr)], title: "background_image".tr))
              .then((value) async {
                if (value == 0) {
                  final result = await controller.pickBgImageFile(Get.context!.isDarkMode);
                  switch (result) {
                    case null:
                      return;
                    case true:
                      showSnackBar(message: "set_background_successfully".tr, context: Get.context!);
                    case false:
                      showSnackBar(message: "set_background_failed".tr, context: Get.context!);
                  }
                } else if (value == 1) {
                  Get.context!.isDarkMode ? controller.changeReaderNightBgImage(null) : controller.changeReaderDayBgImage(null);
                  showSnackBar(message: "reset_background_image_successfully".tr, context: Get.context!);
                }
              }),
        ),
      ],
    );
  }

  Widget _buildListen(BuildContext context) {
    final tts = TtsService.instance;
    return ListView(
      children: [
        Obx(
          () => NormalTile(
            title: "听书来源",
            subtitle: tts.providerLabel(tts.providerType.value),
            leading: const Icon(Icons.hub_outlined),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: () {
              Get.dialog(
                RadioListDialog<TtsProviderType>(
                  value: tts.providerType.value,
                  values: [
                    (TtsProviderType.system, tts.providerLabel(TtsProviderType.system)),
                    (TtsProviderType.volcengine, tts.providerLabel(TtsProviderType.volcengine)),
                    (TtsProviderType.google, tts.providerLabel(TtsProviderType.google)),
                  ],
                  title: "听书来源",
                ),
              ).then((value) async {
                if (value != null) {
                  await tts.setProviderType(value);
                }
              });
            },
          ),
        ),
        Obx(
          () => SwitchTile(
            title: "enabled_listening".tr,
            leading: const Icon(Icons.record_voice_over_outlined),
            onChanged: (v) => tts.setEnabled(v),
            value: tts.enabled.value,
          ),
        ),
        Obx(
          () => SwitchTile(
            title: "连续播放下一章",
            leading: const Icon(Icons.playlist_play_outlined),
            onChanged: (v) => tts.setAutoPlayNextChapter(v),
            value: tts.autoPlayNextChapter.value,
          ),
        ),
        Obx(
          () => Offstage(
            offstage: !tts.enabled.value,
            child: Column(
              children: [
                if (tts.isSystemProvider) ...[
                  NormalTile(
                    title: "open_tts_system_setting".tr,
                    leading: const Icon(Icons.settings_applications_outlined),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: tts.openAndroidTtsSettings,
                  ),
                  Obx(
                    () => NormalTile(
                      title: "tts_engine".tr,
                      subtitle: tts.engine.value == null
                          ? (Platform.isAndroid ? "auto".tr : "unsupportable_os_tip".tr)
                          : tts.displayEngineName(tts.engine.value!),
                      leading: const Icon(Icons.settings_outlined),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      onTap: () async {
                        await tts.refreshEngines();
                        Get.dialog(
                          NormalListDialog(
                            values: [(null, "auto".tr), ...tts.engines.map((value) => (value, tts.displayEngineName(value)))],
                            title: "tts_engine".tr,
                          ),
                        ).then((value) async {
                          if (value == null) {
                            tts.applyEngine(null);
                          } else {
                            await tts.applyEngine(value);
                            await tts.refreshVoices();
                          }
                        });
                      },
                    ),
                  ),
                  Obx(
                    () => NormalTile(
                      title: "timbre".tr,
                      subtitle: tts.voice.value == null ? "auto".tr : "${tts.voice.value!["name"]}(${tts.voice.value!["locale"]})",
                      leading: const Icon(Icons.surround_sound_outlined),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      onTap: () async {
                        await tts.refreshVoices();
                        Get.dialog(
                          NormalListDialog(
                            values: [(null, "auto".tr), ...tts.voices.map((value) => (value, "${value["name"]}(${value["locale"]})"))],
                            title: "timbre".tr,
                          ),
                        ).then((value) async {
                          if (value == null) {
                            tts.applyVoice(null);
                          } else {
                            await tts.applyVoice(value);
                          }
                        });
                      },
                    ),
                  ),
                ],
                if (tts.isVolcengineProvider) ...[
                  Obx(
                    () => NormalTile(
                      title: "Volcengine App ID",
                      subtitle: tts.volcengineAppId.value.isEmpty ? "未填写" : tts.volcengineAppId.value,
                      leading: const Icon(Icons.badge_outlined),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editTextValue(
                        context,
                        title: "Volcengine App ID",
                        initialValue: tts.volcengineAppId.value,
                        onSaved: tts.setVolcengineAppId,
                      ),
                    ),
                  ),
                  Obx(
                    () => NormalTile(
                      title: "Access Key",
                      subtitle: tts.volcengineAccessKey.value.isEmpty ? "未填写" : _maskSecret(tts.volcengineAccessKey.value),
                      leading: const Icon(Icons.key_outlined),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editTextValue(
                        context,
                        title: "Access Key",
                        initialValue: tts.volcengineAccessKey.value,
                        obscureText: true,
                        onSaved: tts.setVolcengineAccessKey,
                      ),
                    ),
                  ),
                  Obx(
                    () => NormalTile(
                      title: "Resource ID",
                      subtitle: tts.volcengineResourceId.value,
                      leading: const Icon(Icons.hub_outlined),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editTextValue(
                        context,
                        title: "Resource ID",
                        initialValue: tts.volcengineResourceId.value,
                        onSaved: tts.setVolcengineResourceId,
                      ),
                    ),
                  ),
                  Obx(
                    () => NormalTile(
                      title: "音色预设",
                      subtitle: tts.volcengineSpeakerLabel(tts.volcengineSpeaker.value),
                      leading: const Icon(Icons.library_music_outlined),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      onTap: () {
                        Get.dialog(
                          NormalListDialog(
                            values: TtsService.volcengineSpeakerPresets
                                .map((preset) => (preset.speaker, preset.label))
                                .toList(),
                            title: "音色预设",
                          ),
                        ).then((value) {
                          if (value != null) {
                            tts.setVolcengineSpeaker(value);
                          }
                        });
                      },
                    ),
                  ),
                  Obx(
                    () => NormalTile(
                      title: "Speaker",
                      subtitle: tts.volcengineSpeaker.value.isEmpty ? "未填写" : "${tts.volcengineSpeakerLabel(tts.volcengineSpeaker.value)}\n${tts.volcengineSpeaker.value}",
                      leading: const Icon(Icons.record_voice_over_outlined),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editTextValue(
                        context,
                        title: "Speaker",
                        initialValue: tts.volcengineSpeaker.value,
                        onSaved: tts.setVolcengineSpeaker,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      "当前火山引擎模式使用豆包语音合成 1.0 的 V3 接口。默认 Resource ID 为 seed-tts-1.0。上面的 5 个音色预设已经内置，也保留了手动输入 Speaker 的方式，方便你后续继续试其他音色。",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                if (tts.isGoogleProvider) ...[
                  Obx(
                    () => NormalTile(
                      title: "Google API Key",
                      subtitle: tts.googleApiKey.value.isEmpty ? "未填写" : _maskSecret(tts.googleApiKey.value),
                      leading: const Icon(Icons.key_outlined),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editTextValue(
                        context,
                        title: "Google API Key",
                        initialValue: tts.googleApiKey.value,
                        obscureText: true,
                        onSaved: tts.setGoogleApiKey,
                      ),
                    ),
                  ),
                  Obx(
                    () => NormalTile(
                      title: "Google 音色预设",
                      subtitle: tts.googleVoiceLabel(tts.googleVoice.value),
                      leading: const Icon(Icons.library_music_outlined),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      onTap: () {
                        final values = TtsService.googleVoicePresets.map((preset) => (preset.voice, preset.label)).toList();
                        Get.dialog(
                          NormalListDialog(
                            values: values,
                            title: "Google 音色预设",
                            subtitleBuilder: (context, index) => Text(TtsService.googleVoicePresets[index].gender),
                          ),
                        ).then((value) {
                          if (value != null) {
                            tts.setGoogleVoice(value);
                          }
                        });
                      },
                    ),
                  ),
                  Obx(
                    () => NormalTile(
                      title: "Google Voice",
                      subtitle: tts.googleVoice.value.isEmpty ? "未填写" : "${tts.googleVoiceLabel(tts.googleVoice.value)}\n${tts.googleVoice.value}",
                      leading: const Icon(Icons.record_voice_over_outlined),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editTextValue(
                        context,
                        title: "Google Voice",
                        initialValue: tts.googleVoice.value,
                        onSaved: tts.setGoogleVoice,
                      ),
                    ),
                  ),
                  Obx(
                    () => SliderTile(
                      title: "Google speakingRate",
                      leading: const Icon(Icons.speed),
                      min: 0.25,
                      max: 2.0,
                      divisions: 35,
                      decimalPlaces: 2,
                      value: tts.googleSpeakingRate.value,
                      onChanged: (v) => tts.googleSpeakingRate.value = v,
                      onChangeEnd: tts.setGoogleSpeakingRate,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      "当前 Google TTS 模式使用 Cloud Text-to-Speech 的 cmn-CN Chirp3-HD 音色。Google 的 speakingRate 默认 1.0，和系统 TTS 的参数范围不同。Chirp3-HD 当前不支持 pitch 参数，所以这里不显示音调设置。",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const Divider(height: 1),
                if (!tts.isGoogleProvider) ...[
                  Obx(
                    () => SliderTile(
                      title: "speech_rate".tr,
                      leading: const Icon(Icons.speed),
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      decimalPlaces: 1,
                      value: tts.rate.value,
                      onChanged: (v) => tts.rate.value = v,
                      onChangeEnd: (v) => tts.setRate(v),
                    ),
                  ),
                  Obx(
                    () => SliderTile(
                      title: "tone".tr,
                      leading: const Icon(Icons.graphic_eq),
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      decimalPlaces: 1,
                      value: tts.pitch.value,
                      onChanged: (v) => tts.pitch.value = v,
                      onChangeEnd: (v) => tts.setPitch(v),
                    ),
                  ),
                ],
                Obx(
                  () => SliderTile(
                    title: "volume".tr,
                    leading: const Icon(Icons.volume_up_outlined),
                    min: 0,
                    max: 1,
                    divisions: 20,
                    decimalPlaces: 2,
                    value: tts.volume.value,
                    onChanged: (v) => tts.volume.value = v,
                    onChangeEnd: (v) => tts.setVolume(v),
                  ),
                ),
                const Divider(height: 1),
                NormalTile(title: "refresh_setting".tr, subtitle: "refresh_tts_setting_tip".tr, leading: const Icon(Icons.refresh)),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => tts.refreshSettings(restartIfPlaying: true),
                      icon: const Icon(Icons.refresh),
                      label: Text("refresh_setting".tr),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => tts.speak("你好，欢迎使用听书功能。"),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("试听测试"),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editTextValue(
    BuildContext context, {
    required String title,
    required String initialValue,
    required void Function(String value) onSaved,
    bool obscureText = false,
    int minLines = 1,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscureText,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: title,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text("cancel".tr)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: Text("save".tr)),
        ],
      ),
    );

    if (result != null) {
      onSaved(result);
    }
  }

  String _maskSecret(String value) {
    if (value.length <= 8) return List.filled(value.length, "*").join();
    return "${value.substring(0, 4)}****${value.substring(value.length - 4)}";
  }

  String _previewText(String value, {int max = 60}) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return "未填写";
    if (text.length <= max) return text;
    return "${text.substring(0, max)}...";
  }

  Widget _buildAiAnalysis(BuildContext context) {
    final ai = AiAnalysisService.instance;
    final supported = ai.supportsAid(controller.aid);
    return ListView(
      children: [
        if (!supported)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              "当前仅对网络小说和本地 EPUB 启用 AI 分析，Markdown/TXT 暂不开放。",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Obx(
          () => SwitchTile(
            title: "启用 AI 分析",
            leading: const Icon(Icons.auto_awesome_outlined),
            onChanged: ai.setEnabled,
            value: ai.enabled.value,
          ),
        ),
        Obx(
          () => NormalTile(
            title: "Provider",
            subtitle: ai.provider.value,
            leading: const Icon(Icons.hub_outlined),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTextValue(
              context,
              title: "Provider",
              initialValue: ai.provider.value,
              onSaved: ai.setProvider,
            ),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "Base URL",
            subtitle: ai.baseUrl.value.isEmpty ? "未填写" : ai.baseUrl.value,
            leading: const Icon(Icons.link_outlined),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTextValue(
              context,
              title: "Base URL",
              initialValue: ai.baseUrl.value,
              onSaved: ai.setBaseUrl,
            ),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "API Key",
            subtitle: ai.apiKey.value.isEmpty ? "未填写" : _maskSecret(ai.apiKey.value),
            leading: const Icon(Icons.key_outlined),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTextValue(
              context,
              title: "API Key",
              initialValue: ai.apiKey.value,
              obscureText: true,
              onSaved: ai.setApiKey,
            ),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "Model",
            subtitle: ai.model.value.isEmpty ? "未填写" : ai.model.value,
            leading: const Icon(Icons.smart_toy_outlined),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTextValue(
              context,
              title: "Model",
              initialValue: ai.model.value,
              onSaved: ai.setModel,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                  onPressed: supported
                      ? () async {
                    try {
                      final models = await ai.fetchModels();
                      if (models.isEmpty) {
                        showSnackBar(message: "没有拉取到模型，当前供应商可能不支持 /models", context: context);
                        return;
                      }
                      if (!context.mounted) return;
                      Get.dialog(
                        NormalListDialog(
                          values: models.map((model) => (model, model)).toList(),
                          title: "选择模型",
                        ),
                      ).then((value) {
                        if (value != null) ai.setModel(value);
                      });
                    } catch (e) {
                      showSnackBar(message: "拉取模型失败: $e", context: context);
                    }
                  }
                      : null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text("拉取模型"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: supported
                      ? () async {
                    try {
                      await ai.testConnection();
                      showSnackBar(message: "AI 连接成功", context: context);
                    } catch (e) {
                      showSnackBar(message: "AI 连接失败: $e", context: context);
                    }
                  }
                      : null,
                  icon: const Icon(Icons.network_check_outlined),
                  label: const Text("测试连接"),
                ),
              ),
            ],
          ),
        ),
        Obx(
          () => SliderTile(
            title: "Temperature",
            leading: const Icon(Icons.thermostat_outlined),
            min: 0,
            max: 2,
            divisions: 20,
            decimalPlaces: 1,
            value: ai.temperature.value,
            onChanged: (v) => ai.temperature.value = v,
            onChangeEnd: ai.setTemperature,
          ),
        ),
        Obx(
          () => SliderTile(
            title: "最大请求 Tokens",
            leading: const Icon(Icons.format_list_numbered_outlined),
            min: 2000,
            max: 60000,
            divisions: 58,
            decimalPlaces: 0,
            value: ai.maxRequestTokens.value.toDouble(),
            onChanged: (v) => ai.maxRequestTokens.value = v.toInt(),
            onChangeEnd: (v) => ai.setMaxRequestTokens(v.toInt()),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "最大回复 Tokens",
            leading: const Icon(Icons.short_text_outlined),
            min: 256,
            max: 30000,
            divisions: 58,
            decimalPlaces: 0,
            value: ai.maxTokens.value.toDouble(),
            onChanged: (v) => ai.maxTokens.value = v.toInt(),
            onChangeEnd: (v) => ai.setMaxTokens(v.toInt()),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "系统提示词",
            subtitle: _previewText(ai.effectiveSystemPrompt),
            leading: const Icon(Icons.description_outlined),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTextValue(
              context,
              title: "系统提示词",
              initialValue: ai.effectiveSystemPrompt,
              minLines: 12,
              maxLines: 18,
              onSaved: ai.setSystemPrompt,
            ),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "用户提示词模板",
            subtitle: _previewText(ai.effectiveUserPromptTemplate),
            leading: const Icon(Icons.article_outlined),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTextValue(
              context,
              title: "用户提示词模板",
              initialValue: ai.effectiveUserPromptTemplate,
              minLines: 12,
              maxLines: 18,
              onSaved: ai.setUserPromptTemplate,
            ),
          ),
        ),
        Obx(
          () => NormalTile(
            title: "合并阶段系统提示词",
            subtitle: _previewText(ai.effectiveMergeSystemPrompt),
            leading: const Icon(Icons.merge_type_outlined),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editTextValue(
              context,
              title: "合并阶段系统提示词",
              initialValue: ai.effectiveMergeSystemPrompt,
              minLines: 12,
              maxLines: 18,
              onSaved: ai.setMergeSystemPrompt,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: ai.resetPrompts,
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text("恢复默认提示词"),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final text = controller.text.value.trim();
                final recentSummary = await ai.getRecentSummaryPreview(controller.aid, excludeCid: controller.cid);
                final bookMemory = await ai.getBookMemoryPreview(controller.aid);
                final preview = ai.renderUserPrompt(
                  chapterTitle: controller.chapterTitle.value,
                  chapterText: text.isEmpty ? "{{chapterText}}" : text,
                  recentSummary: recentSummary,
                  bookMemory: bookMemory,
                );
                await showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text("当前用户 Prompt 预览"),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(child: SelectableText(preview)),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text("confirm".tr)),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.preview_outlined),
              label: const Text("预览当前用户 Prompt"),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final preview = await ai.renderMergePromptPreview(
                    aid: controller.aid,
                    cid: controller.cid,
                    chapterTitle: controller.chapterTitle.value,
                  );
                  if (!context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text("合并阶段 Prompt 预览"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: SingleChildScrollView(child: SelectableText(preview)),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text("confirm".tr)),
                      ],
                    ),
                  );
                } catch (e) {
                  showSnackBar(message: "请先分析当前章节，再预览合并阶段 Prompt", context: context);
                }
              },
              icon: const Icon(Icons.merge_outlined),
              label: const Text("预览合并阶段 Prompt"),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            "支持占位符：{{chapterTitle}} {{chapterText}} {{recentSummary}} {{bookMemory}}。第一阶段负责章节抽取，第二阶段会带上已知人物和关系做合并。",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: supported ? () => _analyzeCurrentChapter(context) : null,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text("分析当前章节"),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: supported ? () => _showCurrentChapterAnalysis(context) : null,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text("查看当前章节分析结果"),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _analyzeCurrentChapter(BuildContext context) async {
    final ai = AiAnalysisService.instance;
    final text = controller.text.value;
    if (text.trim().isEmpty) {
      showSnackBar(message: "当前章节还在加载中", context: context);
      return;
    }

    showSnackBar(
      message: "正在分析当前章节...",
      context: context,
      duration: const Duration(days: 1),
    );
    try {
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
      showSnackBar(message: "AI 分析失败: $e", context: context);
    }
  }

  Future<void> _showCurrentChapterAnalysis(BuildContext context) async {
    final ai = AiAnalysisService.instance;
    try {
      final result = await ai.loadAnalysis(aid: controller.aid, cid: controller.cid);
      if (result == null) {
        final path = await ai.analysisPath(aid: controller.aid, cid: controller.cid);
        showSnackBar(message: "当前章节还没有分析结果: $path", context: context);
        return;
      }
      if (!context.mounted) return;
      await Get.to(() => AiChapterAnalysisPage(result: result));
    } catch (e) {
      showSnackBar(message: "读取 AI 分析结果失败: $e", context: context);
    }
  }

  Widget _buildPadding() {
    return ListView(
      children: [
        Obx(
          () => SliderTile(
            title: "left_margin".tr,
            leading: const Icon(Icons.border_left),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.leftMargin,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(leftMargin: value),
            onChangeEnd: (value) => controller.changeLeftMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "top_margin".tr,
            leading: const Icon(Icons.border_top),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.topMargin,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(topMargin: value),
            onChangeEnd: (value) => controller.changeTopMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "right_margin".tr,
            leading: const Icon(Icons.border_right),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.rightMargin,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(rightMargin: value),
            onChangeEnd: (value) => controller.changeRightMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "bottom_margin".tr,
            leading: const Icon(Icons.border_bottom),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.bottomMargin,
            onChanged: (value) => controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(bottomMargin: value),
            onChangeEnd: (value) => controller.changeBottomMargin(value),
          ),
        ),
        Obx(
          () => SliderTile(
            title: "bottomStatusBarHorizontalSpacing".tr,
            leading: const Icon(Icons.swap_horiz),
            min: 0,
            max: 100,
            divisions: 100,
            decimalPlaces: 0,
            value: controller.readerSettingsState.value.readerBottomStatusBarHorizontalSpacing,
            onChanged: (value) =>
                controller.readerSettingsState.value = controller.readerSettingsState.value.copyWith(readerBottomStatusBarHorizontalSpacing: value.toInt()),
            onChangeEnd: (value) => controller.changeReaderBottomStatusBarHorizontalSpacing(value.toInt()),
          ),
        ),
      ],
    );
  }

  /// [isChangeText] `true` 琛ㄧず淇敼瀛椾綋棰滆壊锛宍false` 琛ㄧず淇敼鑳屾櫙棰滆壊`
  void _buildColorPickerDialog(BuildContext context, bool isChangeText) async {
    final initColor = isChangeText
        ? controller.currentTextColor.value ?? Theme.of(context).colorScheme.onSurface
        : controller.currentBgColor.value ?? Theme.of(context).colorScheme.surface;
    final newColor = await showColorPickerDialog(
      context,
      initColor,
      showMaterialName: true,
      showColorName: true,
      showColorCode: true,
      materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(context).textTheme.bodySmall,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
      enableShadesSelection: false,
      actionButtons: ColorPickerActionButtons(dialogOkButtonLabel: "save".tr, dialogCancelButtonLabel: "cancel".tr),
      copyPasteBehavior: ColorPickerCopyPasteBehavior().copyWith(copyFormat: ColorPickerCopyFormat.hexRRGGBB),
    );
    if (newColor == initColor) return;
    if (Get.context!.isDarkMode) {
      isChangeText ? controller.changeReaderNightTextColor(newColor) : controller.changeReaderNightBgColor(newColor);
    } else {
      isChangeText ? controller.changeReaderDayTextColor(newColor) : controller.changeReaderDayBgColor(newColor);
    }

    showSnackBar(message: "color_set_successfully".tr, context: Get.context!);
  }
}

