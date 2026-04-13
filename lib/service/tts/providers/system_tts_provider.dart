import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/service/tts/tts_provider.dart';

import '../../../common/log.dart';

class SystemTtsProvider extends TtsProvider {
  static const String multiTtsEnginePackage = 'org.nobody.multitts';
  static const List<String> _preferredLocales = <String>['zh-CN', 'zh-TW', 'zh-HK', 'en-US'];

  final FlutterTts _tts = FlutterTts();

  bool _pauseRequested = false;
  bool _stopRequested = false;
  bool _initialized = false;

  @override
  String get id => "system";

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}

    _tts.setStartHandler(() {
      emit(const TtsProviderEvent(TtsProviderEventType.started));
    });
    _tts.setCompletionHandler(() {
      emit(const TtsProviderEvent(TtsProviderEventType.completed));
    });
    _tts.setCancelHandler(() {
      if (_pauseRequested) {
        _pauseRequested = false;
        emit(const TtsProviderEvent(TtsProviderEventType.paused));
        return;
      }
      _stopRequested = false;
      emit(const TtsProviderEvent(TtsProviderEventType.stopped));
    });
    _tts.setPauseHandler(() {
      _pauseRequested = false;
      emit(const TtsProviderEvent(TtsProviderEventType.paused));
    });
    _tts.setContinueHandler(() {
      _pauseRequested = false;
      emit(const TtsProviderEvent(TtsProviderEventType.resumed));
    });
    _tts.setErrorHandler((message) {
      if (_pauseRequested) {
        _pauseRequested = false;
        emit(const TtsProviderEvent(TtsProviderEventType.paused));
        return;
      }
      _stopRequested = false;
      emit(TtsProviderEvent(TtsProviderEventType.error, message: message));
    });
  }

  @override
  Future<List<String>> getEngines() async {
    if (!Platform.isAndroid) return const [];
    try {
      final result = await _tts.getEngines;
      final list = (result as List?)?.cast<String>() ?? <String>[];
      list.sort((a, b) {
        if (a == multiTtsEnginePackage && b != multiTtsEnginePackage) return -1;
        if (b == multiTtsEnginePackage && a != multiTtsEnginePackage) return 1;
        return a.compareTo(b);
      });
      return list;
    } catch (e) {
      Log.d("[SystemTtsProvider] getEngines failed: $e");
      return const [];
    }
  }

  @override
  Future<void> applyEngine(String? engine) async {
    if (!Platform.isAndroid || engine == null || engine.isEmpty) return;
    try {
      await _tts.setEngine(engine);
    } catch (err) {
      Log.d("[SystemTtsProvider] setEngine failed: $err");
    }
    await _applyBestLanguage();
  }

  @override
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final result = await _tts.getVoices;
      final list = <Map<String, String>>[];
      if (result is List) {
        for (final v in result) {
          if (v is Map) {
            final name = v["name"]?.toString();
            final locale = v["locale"]?.toString();
            if (name != null && locale != null) {
              list.add({"name": name, "locale": locale});
            }
          }
        }
      }
      return list;
    } catch (e) {
      Log.d("[SystemTtsProvider] getVoices failed: $e");
      return const [];
    }
  }

  @override
  Future<void> applyVoice(Map<String, String>? voice) async {
    if (voice == null) return;
    try {
      await _tts.setVoice(voice);
    } catch (err) {
      Log.d("[SystemTtsProvider] setVoice failed: $err");
    }
  }

  @override
  Future<void> setRate(double value) => _tts.setSpeechRate(value);

  @override
  Future<void> setPitch(double value) => _tts.setPitch(value);

  @override
  Future<void> setVolume(double value) => _tts.setVolume(value);

  @override
  Future<void> speak(String text) async {
    await _applyBestLanguage();
    final result = await _tts.speak(text);
    if (result is int && result == 0 && !_stopRequested && !_pauseRequested) {
      emit(TtsProviderEvent(TtsProviderEventType.error, message: "系统 TTS 启动失败"));
    }
  }

  @override
  Future<void> pause() async {
    _pauseRequested = true;
    _stopRequested = false;
    try {
      await _tts.pause();
    } catch (_) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> resume() async {
    final dynamic ttsDyn = _tts;
    try {
      await ttsDyn.continueSpeaking();
    } catch (_) {
      try {
        await ttsDyn.resume();
      } catch (_) {
        emit(TtsProviderEvent(TtsProviderEventType.error, message: "系统 TTS 不支持继续播放"));
      }
    }
  }

  @override
  Future<void> stop() async {
    _stopRequested = true;
    _pauseRequested = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _applyBestLanguage() async {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    final candidates = <String>{deviceLocale, ..._preferredLocales}.toList();

    for (final loc in candidates) {
      if (await _trySetLanguage(loc)) {
        return;
      }
    }
  }

  Future<bool> _trySetLanguage(String locale) async {
    try {
      final available = await _tts.isLanguageAvailable(locale);
      if (available == null) {
        await _tts.setLanguage(locale);
        return true;
      }
      if (available is bool && !available) return false;
      await _tts.setLanguage(locale);
      return true;
    } catch (_) {
      return false;
    }
  }
}
