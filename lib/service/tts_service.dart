import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/tts_provider_type.dart';
import 'package:hikari_novel_flutter/service/tts/providers/google_tts_provider.dart';
import 'package:hikari_novel_flutter/service/tts/providers/system_tts_provider.dart';
import 'package:hikari_novel_flutter/service/tts/providers/volcengine_tts_provider.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/log.dart';
import 'local_storage_service.dart';
import 'tts/tts_provider.dart';

class TtsService extends GetxService {
  static const MethodChannel _intentChannel = MethodChannel('hikari/system_intents');

  static TtsService get instance => Get.find<TtsService>();

  static const String multiTtsEnginePackage = SystemTtsProvider.multiTtsEnginePackage;

  final enabled = false.obs;
  final providerType = TtsProviderType.system.obs;
  final engine = RxnString();
  final voice = Rxn<Map<String, String>>();
  final rate = 0.5.obs;
  final pitch = 1.0.obs;
  final volume = 1.0.obs;

  final engines = <String>[].obs;
  final voices = <Map<String, String>>[].obs;

  final isPlaying = false.obs;
  final isPaused = false.obs;
  final lastSpokenText = ''.obs;

  final isSessionActive = false.obs;
  final sessionTitle = ''.obs;
  final sessionProgress = 0.0.obs;
  final currentChunkText = ''.obs;
  final currentChunkIndex = 0.obs;
  final currentChunkTotal = 0.obs;

  final volcengineAppId = ''.obs;
  final volcengineAccessKey = ''.obs;
  final volcengineResourceId = 'seed-tts-1.0'.obs;
  final volcengineSpeaker = ''.obs;
  final googleApiKey = ''.obs;
  final googleLanguageCode = 'cmn-CN'.obs;
  final googleVoice = ''.obs;
  final googleSpeakingRate = 1.0.obs;
  final googlePitch = 0.0.obs;

  static const List<({String label, String speaker, String? emotion, int? emotionScale})> volcengineSpeakerPresets = [
    (label: "深夜播客 neutral", speaker: "zh_male_shenyeboke_emo_v2_mars_bigtts", emotion: "neutral", emotionScale: 2),
    (label: "儒雅青年", speaker: "zh_male_ruyaqingnian_mars_bigtts", emotion: null, emotionScale: null),
    (label: "悬疑解说", speaker: "zh_male_changtianyi_mars_bigtts", emotion: null, emotionScale: null),
    (label: "擎苍", speaker: "zh_male_qingcang_mars_bigtts", emotion: null, emotionScale: null),
    (label: "温柔淑女", speaker: "zh_female_wenroushunv_mars_bigtts", emotion: null, emotionScale: null),
  ];

  static const List<({String label, String voice, String gender})> googleVoicePresets = [
    (label: "Enceladus", voice: "cmn-CN-Chirp3-HD-Enceladus", gender: "男声"),
    (label: "Fenrir", voice: "cmn-CN-Chirp3-HD-Fenrir", gender: "男声"),
    (label: "Iapetus", voice: "cmn-CN-Chirp3-HD-Iapetus", gender: "男声"),
    (label: "Orus", voice: "cmn-CN-Chirp3-HD-Orus", gender: "男声"),
    (label: "Puck", voice: "cmn-CN-Chirp3-HD-Puck", gender: "男声"),
    (label: "Rasalgethi", voice: "cmn-CN-Chirp3-HD-Rasalgethi", gender: "男声"),
    (label: "Schedar", voice: "cmn-CN-Chirp3-HD-Schedar", gender: "男声"),
    (label: "Umbriel", voice: "cmn-CN-Chirp3-HD-Umbriel", gender: "男声"),
    (label: "Gacrux", voice: "cmn-CN-Chirp3-HD-Gacrux", gender: "女声"),
    (label: "Vindemiatrix", voice: "cmn-CN-Chirp3-HD-Vindemiatrix", gender: "女声"),
  ];

  List<String> _chunks = const [];
  int _chunkIndex = 0;
  static const int _defaultMaxChunkLen = 280;
  static const int _googleMaxChunkLen = 500;
  static const int _googleMaxSentenceLen = 180;

  final SystemTtsProvider _systemProvider = SystemTtsProvider();
  final VolcengineTtsProvider _volcengineProvider = VolcengineTtsProvider();
  final GoogleTtsProvider _googleProvider = GoogleTtsProvider();
  late TtsProvider _provider;
  StreamSubscription<TtsProviderEvent>? _providerSub;
  bool _initialized = false;
  bool _pauseRequested = false;

  bool get isSystemProvider => providerType.value == TtsProviderType.system;

  bool get isVolcengineProvider => providerType.value == TtsProviderType.volcengine;

  bool get isGoogleProvider => providerType.value == TtsProviderType.google;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _clearStartupAudioCache();

    enabled.value = LocalStorageService.instance.getReaderTtsEnabled();
    providerType.value = TtsProviderType.fromStorage(LocalStorageService.instance.getReaderTtsProvider());
    engine.value = LocalStorageService.instance.getReaderTtsEngine();
    voice.value = LocalStorageService.instance.getReaderTtsVoice();
    rate.value = LocalStorageService.instance.getReaderTtsRate();
    pitch.value = LocalStorageService.instance.getReaderTtsPitch();
    volume.value = LocalStorageService.instance.getReaderTtsVolume();

    volcengineAppId.value = LocalStorageService.instance.getReaderTtsVolcengineAppId();
    volcengineAccessKey.value = LocalStorageService.instance.getReaderTtsVolcengineAccessKey();
    volcengineResourceId.value = LocalStorageService.instance.getReaderTtsVolcengineResourceId();
    if (volcengineResourceId.value.isEmpty || volcengineResourceId.value == "seed-tts-2.0") {
      volcengineResourceId.value = "seed-tts-1.0";
      LocalStorageService.instance.setReaderTtsVolcengineResourceId(volcengineResourceId.value);
    }
    volcengineSpeaker.value = LocalStorageService.instance.getReaderTtsVolcengineSpeaker();
    if (volcengineSpeaker.value.isEmpty) {
      volcengineSpeaker.value = volcengineSpeakerPresets.first.speaker;
      LocalStorageService.instance.setReaderTtsVolcengineSpeaker(volcengineSpeaker.value);
    }
    googleApiKey.value = LocalStorageService.instance.getReaderTtsGoogleApiKey();
    googleLanguageCode.value = LocalStorageService.instance.getReaderTtsGoogleLanguageCode();
    googleVoice.value = LocalStorageService.instance.getReaderTtsGoogleVoice();
    if (googleVoice.value.isEmpty) {
      googleVoice.value = googleVoicePresets.first.voice;
      LocalStorageService.instance.setReaderTtsGoogleVoice(googleVoice.value);
    }
    googleSpeakingRate.value = LocalStorageService.instance.getReaderTtsGoogleSpeakingRate();
    googlePitch.value = LocalStorageService.instance.getReaderTtsGooglePitch();

    await _bindProvider(providerType.value, reinitialize: true);
  }

  Future<void> _clearStartupAudioCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final cacheDir = Directory(path.join(dir.path, "tts_cache"));
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      Log.d("[TtsService] clear startup audio cache failed: $e");
    }
  }

  String providerLabel(TtsProviderType type) => switch (type) {
    TtsProviderType.system => "系统 TTS",
    TtsProviderType.volcengine => "火山引擎",
    TtsProviderType.google => "Google TTS",
  };

  String displayEngineName(String enginePackage) {
    if (enginePackage == multiTtsEnginePackage) return "MultiTTS";
    return "system_tts".tr;
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    LocalStorageService.instance.setReaderTtsEnabled(value);
    if (!value) {
      await stop();
    }
  }

  Future<void> setProviderType(TtsProviderType type) async {
    if (providerType.value == type) return;
    await stop();
    providerType.value = type;
    LocalStorageService.instance.setReaderTtsProvider(type.storageValue);
    await _bindProvider(type, reinitialize: true);
  }

  Future<void> refreshEngines() async {
    if (!isSystemProvider) {
      engines.clear();
      return;
    }
    engines.assignAll(await _provider.getEngines());
  }

  Future<void> refreshVoices() async {
    if (!isSystemProvider) {
      voices.clear();
      return;
    }
    voices.assignAll(await _provider.getVoices());
  }

  Future<void> applyEngine(String? value) async {
    engine.value = value;
    LocalStorageService.instance.setReaderTtsEngine(value);
    if (!isSystemProvider) return;
    await _provider.applyEngine(value);
    await refreshVoices();
  }

  Future<void> applyVoice(Map<String, String>? value) async {
    voice.value = value;
    LocalStorageService.instance.setReaderTtsVoice(value);
    if (!isSystemProvider) return;
    await _provider.applyVoice(value);
  }

  Future<void> setRate(double value) async {
    rate.value = value;
    LocalStorageService.instance.setReaderTtsRate(value);
    await _provider.setRate(value);
  }

  Future<void> setPitch(double value) async {
    pitch.value = value;
    LocalStorageService.instance.setReaderTtsPitch(value);
    await _provider.setPitch(value);
  }

  Future<void> setVolume(double value) async {
    volume.value = value;
    LocalStorageService.instance.setReaderTtsVolume(value);
    await _provider.setVolume(value);
  }

  void setVolcengineAppId(String value) {
    volcengineAppId.value = value.trim();
    LocalStorageService.instance.setReaderTtsVolcengineAppId(volcengineAppId.value);
    _syncVolcengineConfig();
  }

  void setVolcengineAccessKey(String value) {
    volcengineAccessKey.value = value.trim();
    LocalStorageService.instance.setReaderTtsVolcengineAccessKey(volcengineAccessKey.value);
    _syncVolcengineConfig();
  }

  void setVolcengineResourceId(String value) {
    volcengineResourceId.value = value.trim().isEmpty ? "seed-tts-1.0" : value.trim();
    LocalStorageService.instance.setReaderTtsVolcengineResourceId(volcengineResourceId.value);
    _syncVolcengineConfig();
  }

  void setVolcengineSpeaker(String value) {
    volcengineSpeaker.value = value.trim();
    LocalStorageService.instance.setReaderTtsVolcengineSpeaker(volcengineSpeaker.value);
    _syncVolcengineConfig();
  }

  void setGoogleApiKey(String value) {
    googleApiKey.value = value.trim();
    LocalStorageService.instance.setReaderTtsGoogleApiKey(googleApiKey.value);
    _syncGoogleConfig();
  }

  void setGoogleVoice(String value) {
    googleVoice.value = value.trim();
    LocalStorageService.instance.setReaderTtsGoogleVoice(googleVoice.value);
    _syncGoogleConfig();
  }

  void setGoogleSpeakingRate(double value) {
    googleSpeakingRate.value = value.clamp(0.25, 4.0);
    LocalStorageService.instance.setReaderTtsGoogleSpeakingRate(googleSpeakingRate.value);
    _syncGoogleConfig();
  }

  void setGooglePitch(double value) {
    googlePitch.value = value.clamp(-20.0, 20.0);
    LocalStorageService.instance.setReaderTtsGooglePitch(googlePitch.value);
    _syncGoogleConfig();
  }

  String volcengineSpeakerLabel(String speaker) {
    for (final preset in volcengineSpeakerPresets) {
      if (preset.speaker == speaker) return preset.label;
    }
    return speaker;
  }

  String googleVoiceLabel(String voice) {
    for (final preset in googleVoicePresets) {
      if (preset.voice == voice) return "${preset.label}（${preset.gender}）";
    }
    return voice;
  }

  ({String label, String speaker, String? emotion, int? emotionScale})? _volcenginePresetForSpeaker(String speaker) {
    for (final preset in volcengineSpeakerPresets) {
      if (preset.speaker == speaker) return preset;
    }
    return null;
  }

  Future<void> refreshSettings({bool restartIfPlaying = true}) async {
    if (!enabled.value) return;

    if (restartIfPlaying && (isPlaying.value || isPaused.value || isSessionActive.value)) {
      final text = lastSpokenText.value;
      final title = sessionTitle.value;
      final wasSession = isSessionActive.value;
      await stop();
      await _provider.setRate(rate.value);
      await _provider.setPitch(pitch.value);
      await _provider.setVolume(volume.value);
      _syncVolcengineConfig();
      _syncGoogleConfig();
      if (text.trim().isNotEmpty) {
        if (wasSession) {
          await startChapter(text, title: title);
        } else {
          await speak(text);
        }
      }
      return;
    }

    await _provider.setRate(rate.value);
    await _provider.setPitch(pitch.value);
    await _provider.setVolume(volume.value);
    _syncVolcengineConfig();
    _syncGoogleConfig();
  }

  Future<void> openAndroidTtsSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _intentChannel.invokeMethod('openTtsSettings');
    } catch (e) {
      Log.d("[TtsService] openTtsSettings failed: $e");
      showSnackBar(message: "${"unable_to_open_system_setting".tr}: $e", context: Get.context!);
    }
  }

  Future<void> openAndroidApp(String packageName) async {
    if (!Platform.isAndroid) return;
    try {
      await _intentChannel.invokeMethod('openApp', {'package': packageName});
    } catch (e) {
      Log.d("[TtsService] openApp failed: $e");
    }
  }

  Future<void> openMultiTtsStore() async {
    final pkg = multiTtsEnginePackage;
    final market = Uri.parse('market://details?id=$pkg');
    final web = Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
    if (await canLaunchUrl(market)) {
      await launchUrl(market, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  bool get isMultiTtsInstalled => engines.contains(multiTtsEnginePackage);

  Future<void> speak(String text) async {
    if (!enabled.value) return;
    await _prepareProvider();
    isSessionActive.value = false;
    _chunks = const [];
    _chunkIndex = 0;
    sessionProgress.value = 0.0;
    final cleaned = _sanitizeTextForTts(text);
    lastSpokenText.value = cleaned;
    await _provider.speak(cleaned);
  }

  Future<void> startChapter(String fullText, {String title = ''}) async {
    if (!enabled.value) return;
    await _prepareProvider();
    final cleaned = _sanitizeTextForTts(fullText);
    if (cleaned.isEmpty) return;

    sessionTitle.value = title;
    isSessionActive.value = true;
    _pauseRequested = false;
    isPaused.value = false;
    lastSpokenText.value = cleaned;

    _chunks = _splitToChunks(
      cleaned,
      maxChunkLen: _currentMaxChunkLen,
      maxSentenceLen: isGoogleProvider ? _googleMaxSentenceLen : null,
    );
    _chunkIndex = 0;
    currentChunkIndex.value = 0;
    currentChunkTotal.value = _chunks.length;
    sessionProgress.value = 0.0;

    await _speakCurrentChunk();
  }

  Future<void> resumeSession() async {
    if (!enabled.value) return;
    await _prepareProvider();

    if (!isSessionActive.value) {
      if (lastSpokenText.value.trim().isNotEmpty) {
        await speak(lastSpokenText.value);
      }
      return;
    }

    if (isPaused.value) {
      _pauseRequested = false;
      isPlaying.value = true;
      isPaused.value = false;
      await _provider.resume();
      return;
    }

    await _speakCurrentChunk();
  }

  Future<void> pauseSession() async {
    if (!enabled.value) return;
    _pauseRequested = true;
    isPlaying.value = false;
    isPaused.value = true;
    await _provider.pause();
  }

  Future<void> pause() async {
    await pauseSession();
  }

  Future<void> stop() async {
    await _provider.stop();
    _endSession();
  }

  Future<void> _bindProvider(TtsProviderType type, {bool reinitialize = false}) async {
    await _providerSub?.cancel();
    _provider = switch (type) {
      TtsProviderType.system => _systemProvider,
      TtsProviderType.volcengine => _volcengineProvider,
      TtsProviderType.google => _googleProvider,
    };

    if (reinitialize) {
      await _provider.init();
    }

    _providerSub = _provider.events.listen(_handleProviderEvent);
    _syncVolcengineConfig();
    _syncGoogleConfig();
    await _provider.setRate(rate.value);
    await _provider.setPitch(pitch.value);
    await _provider.setVolume(volume.value);

    if (isSystemProvider) {
      await refreshEngines();
      if (engine.value != null && engine.value!.isNotEmpty) {
        await _provider.applyEngine(engine.value);
      }
      await refreshVoices();
      if (voice.value != null) {
        await _provider.applyVoice(voice.value);
      }
    } else {
      engines.clear();
      voices.clear();
    }
  }

  Future<void> _prepareProvider() async {
    await _provider.setRate(rate.value);
    await _provider.setPitch(pitch.value);
    await _provider.setVolume(volume.value);
    _syncVolcengineConfig();
    _syncGoogleConfig();
  }

  void _syncVolcengineConfig() {
    _volcengineProvider
      ..appId = volcengineAppId.value
      ..accessKey = volcengineAccessKey.value
      ..resourceId = volcengineResourceId.value
      ..speaker = volcengineSpeaker.value
      ..contextInstruction = VolcengineTtsProvider.defaultContextInstruction
      ..emotion = _volcenginePresetForSpeaker(volcengineSpeaker.value)?.emotion
      ..emotionScale = _volcenginePresetForSpeaker(volcengineSpeaker.value)?.emotionScale;
  }

  void _syncGoogleConfig() {
    _googleProvider
      ..apiKey = googleApiKey.value
      ..languageCode = googleLanguageCode.value
      ..voiceName = googleVoice.value
      ..speakingRate = googleSpeakingRate.value
      ..pitch = googlePitch.value;
  }

  Future<void> _speakCurrentChunk() async {
    if (!isSessionActive.value) return;
    if (_chunkIndex < 0 || _chunkIndex >= _chunks.length) {
      _endSession();
      return;
    }

    sessionProgress.value = _chunks.isEmpty ? 0.0 : (_chunkIndex / _chunks.length).clamp(0.0, 1.0);
    final currentChunk = _chunks[_chunkIndex];
    currentChunkText.value = currentChunk;
    currentChunkIndex.value = _chunkIndex + 1;
    currentChunkTotal.value = _chunks.length;
    _prefetchNextChunk();
    await _provider.speak(currentChunk);
    if (_pauseRequested) {
      await _provider.pause();
    }
  }

  void _prefetchNextChunk() {
    final nextIndex = _chunkIndex + 1;
    if (nextIndex < 0 || nextIndex >= _chunks.length) return;
    unawaited(_provider.preload(_chunks[nextIndex]));
  }

  void _handleProviderEvent(TtsProviderEvent event) {
    switch (event.type) {
      case TtsProviderEventType.started:
      case TtsProviderEventType.resumed:
        if (_pauseRequested) {
          isPlaying.value = false;
          isPaused.value = true;
          break;
        }
        isPlaying.value = true;
        isPaused.value = false;
        break;
      case TtsProviderEventType.paused:
        isPlaying.value = false;
        isPaused.value = true;
        break;
      case TtsProviderEventType.stopped:
        _endSession();
        break;
      case TtsProviderEventType.completed:
        if (!isSessionActive.value) {
          isPlaying.value = false;
          isPaused.value = false;
          return;
        }
        if (isPaused.value) return;
        _chunkIndex += 1;
        if (_chunkIndex >= _chunks.length) {
          _endSession();
          return;
        }
        _speakCurrentChunk();
        break;
      case TtsProviderEventType.error:
        _endSession();
        if (event.message != null && event.message!.trim().isNotEmpty) {
          showSnackBar(message: event.message!, context: Get.context!);
        } else {
          showSnackBar(message: "listen_to_books_failed_tip".tr, context: Get.context!);
        }
        break;
    }
  }

  void _endSession() {
    isSessionActive.value = false;
    isPlaying.value = false;
    isPaused.value = false;
    _pauseRequested = false;
    _chunks = const [];
    _chunkIndex = 0;
    currentChunkText.value = '';
    currentChunkIndex.value = 0;
    currentChunkTotal.value = 0;
    sessionProgress.value = 0.0;
  }

  int get _currentMaxChunkLen => isGoogleProvider ? _googleMaxChunkLen : _defaultMaxChunkLen;

  String _sanitizeTextForTts(String text) {
    return text
        .replaceAllMapped(RegExp(r'⟪([^⧸⟫\s]+)⧸[^⟫\s。，！？；、,]*⟫'), (match) => match.group(1) ?? '')
        .replaceAllMapped(RegExp(r'⟪([^⧸⟫\s]+)⧸[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹḿ]+'), (match) => match.group(1) ?? '')
        .replaceAll(RegExp(r'[⟪⟫⧸]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _splitToChunks(String text, {required int maxChunkLen, int? maxSentenceLen}) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const [];

    final paragraphs = normalized.split(RegExp(r'\n\s*\n+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final chunks = <String>[];

    for (final paragraph in paragraphs.isEmpty ? [normalized] : paragraphs) {
      final sentences = _splitByPriority(paragraph, maxSentenceLen: maxSentenceLen);
      final buf = StringBuffer();

      for (final sentence in sentences) {
        final part = sentence.trim();
        if (part.isEmpty) continue;

        if (buf.length == 0) {
          if (part.length <= maxChunkLen) {
            buf.write(part);
          } else {
            chunks.addAll(_splitHard(part, maxChunkLen: maxChunkLen));
          }
          continue;
        }

        if (buf.length + part.length <= maxChunkLen) {
          buf.write(part);
        } else {
          final chunk = buf.toString().trim();
          if (chunk.isNotEmpty) {
            chunks.add(chunk);
          }
          buf.clear();

          if (part.length <= maxChunkLen) {
            buf.write(part);
          } else {
            chunks.addAll(_splitHard(part, maxChunkLen: maxChunkLen));
          }
        }
      }

      final remain = buf.toString().trim();
      if (remain.isNotEmpty) {
        chunks.add(remain);
      }
    }

    return chunks.where((e) => e.isNotEmpty).toList();
  }

  List<String> _splitByPriority(String paragraph, {int? maxSentenceLen}) {
    final sentenceExp = RegExp(r'.+?(?:[。！？；!?;…]+|$)', dotAll: true);
    final matches = sentenceExp.allMatches(paragraph);
    final sentences = matches.map((m) => m.group(0)!.trim()).where((e) => e.isNotEmpty).toList();
    final baseSentences = sentences.isEmpty ? [paragraph] : sentences;
    if (maxSentenceLen == null) return baseSentences;
    return baseSentences.expand((sentence) => _splitLongSentenceForGoogle(sentence, maxSentenceLen: maxSentenceLen)).toList();
  }

  List<String> _splitLongSentenceForGoogle(String sentence, {required int maxSentenceLen}) {
    final trimmed = sentence.trim();
    if (trimmed.length <= maxSentenceLen) return [trimmed];

    final pieces = <String>[];
    var remaining = trimmed;
    while (remaining.length > maxSentenceLen) {
      final candidate = remaining.substring(0, maxSentenceLen);
      var splitIndex = _lastIndexOfAny(candidate, ['，', '、', ',', ' ']);
      if (splitIndex <= maxSentenceLen ~/ 2) {
        splitIndex = maxSentenceLen;
      }
      var piece = remaining.substring(0, splitIndex).trim();
      if (piece.isNotEmpty && !RegExp(r'[。！？；!?;.]$').hasMatch(piece)) {
        piece = "$piece. ";
      }
      pieces.add(piece);
      remaining = remaining.substring(splitIndex).trimLeft();
    }

    if (remaining.isNotEmpty) {
      pieces.add(remaining);
    }
    return pieces;
  }

  List<String> _splitHard(String text, {required int maxChunkLen}) {
    final pieces = <String>[];
    var remaining = text.trim();

    while (remaining.length > maxChunkLen) {
      final candidate = remaining.substring(0, maxChunkLen);
      final splitIndex = _findSplitPoint(candidate, maxChunkLen: maxChunkLen);
      pieces.add(remaining.substring(0, splitIndex).trim());
      remaining = remaining.substring(splitIndex).trimLeft();
    }

    if (remaining.isNotEmpty) {
      pieces.add(remaining);
    }
    return pieces;
  }

  int _findSplitPoint(String text, {required int maxChunkLen}) {
    final paragraphCut = _lastIndexOfAny(text, ['\n\n']);
    if (paragraphCut > maxChunkLen ~/ 2) return paragraphCut;

    final sentenceCut = _lastIndexOfAny(text, ['。', '！', '？', '；', '!', '?', ';']);
    if (sentenceCut > maxChunkLen ~/ 2) return sentenceCut;

    final softCut = _lastIndexOfAny(text, ['，', '、', ',', ' ']);
    if (softCut > maxChunkLen ~/ 2) return softCut;

    return text.length;
  }

  int _lastIndexOfAny(String text, List<String> needles) {
    var best = -1;
    for (final needle in needles) {
      final idx = text.lastIndexOf(needle);
      if (idx > best) {
        best = idx + needle.length;
      }
    }
    return best;
  }
}

