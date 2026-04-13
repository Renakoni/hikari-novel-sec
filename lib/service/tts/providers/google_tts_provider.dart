import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../common/log.dart';
import '../tts_provider.dart';

class GoogleTtsProvider extends TtsProvider {
  static const String endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize";
  static const int maxCacheFiles = 240;
  static const int maxCacheBytes = 160 * 1024 * 1024;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;

  String apiKey = "";
  String languageCode = "cmn-CN";
  String voiceName = "cmn-CN-Chirp3-HD-Enceladus";
  double speakingRate = 1.0;
  double pitch = 0.0;

  double _volume = 1.0;

  @override
  String get id => "google";

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        emit(const TtsProviderEvent(TtsProviderEventType.completed));
      }
    });
  }

  @override
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 2.0);
    await _player.setVolume(_volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> speak(String text) async {
    final cleaned = _sanitizeText(text);
    if (cleaned.isEmpty) {
      emit(TtsProviderEvent(TtsProviderEventType.error, message: "Google TTS 文本为空"));
      return;
    }
    if (apiKey.trim().isEmpty || voiceName.trim().isEmpty || languageCode.trim().isEmpty) {
      emit(TtsProviderEvent(TtsProviderEventType.error, message: "请先填写 Google TTS API Key，并选择音色"));
      return;
    }

    try {
      final audioPath = await _ensureAudioFile(cleaned);
      await _player.setFilePath(audioPath);
      await _player.setVolume(_volume.clamp(0.0, 1.0));
      await _player.play();
      emit(const TtsProviderEvent(TtsProviderEventType.started));
    } catch (e) {
      Log.d("[GoogleTtsProvider] speak failed: $e");
      emit(TtsProviderEvent(TtsProviderEventType.error, message: e.toString()));
    }
  }

  @override
  Future<void> preload(String text) async {
    final cleaned = _sanitizeText(text);
    if (cleaned.isEmpty) return;
    if (apiKey.trim().isEmpty || voiceName.trim().isEmpty || languageCode.trim().isEmpty) return;
    try {
      await _ensureAudioFile(cleaned);
    } catch (e) {
      Log.d("[GoogleTtsProvider] preload failed: $e");
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    emit(const TtsProviderEvent(TtsProviderEventType.paused));
  }

  @override
  Future<void> resume() async {
    await _player.play();
    emit(const TtsProviderEvent(TtsProviderEventType.resumed));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    emit(const TtsProviderEvent(TtsProviderEventType.stopped));
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await super.dispose();
  }

  Future<String> _ensureAudioFile(String text) async {
    text = _sanitizeText(text);
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory(path.join(dir.path, "tts_cache", "google"));
    await cacheDir.create(recursive: true);

    final hash = _fnv1a32(
      "$languageCode|$voiceName|${speakingRate.toStringAsFixed(2)}|${pitch.toStringAsFixed(2)}|$text",
    );
    final filePath = path.join(cacheDir.path, "$hash.mp3");
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }

    final audioConfig = <String, dynamic>{
      "audioEncoding": "MP3",
      "speakingRate": speakingRate.clamp(0.25, 4.0),
    };
    if (!_isChirp3HdVoice) {
      audioConfig["pitch"] = pitch.clamp(-20.0, 20.0);
    }

    final payload = {
      "input": {"text": text},
      "voice": {
        "languageCode": languageCode.trim(),
        "name": voiceName.trim(),
      },
      "audioConfig": audioConfig,
    };

    late final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        "$endpoint?key=${Uri.encodeComponent(apiKey.trim())}",
        data: payload,
        options: Options(headers: {HttpHeaders.contentTypeHeader: "application/json"}),
      );
    } on DioException catch (e) {
      Log.d("[GoogleTtsProvider] request text head: ${_debugTextHead(text)}");
      throw Exception(_formatGoogleError(e));
    }

    final audioContent = response.data?["audioContent"]?.toString();
    if (audioContent == null || audioContent.isEmpty) {
      throw Exception("Google TTS 未返回音频数据");
    }

    await file.writeAsBytes(base64Decode(audioContent), flush: true);
    await _trimCache(cacheDir);
    return filePath;
  }

  String _sanitizeText(String text) {
    return text
        .replaceAllMapped(RegExp(r'⟪([^⧸⟫\s]+)⧸[^⟫\s。，！？；、,]*⟫'), (match) => match.group(1) ?? '')
        .replaceAllMapped(RegExp(r'⟪([^⧸⟫\s]+)⧸[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹḿ]+'), (match) => match.group(1) ?? '')
        .replaceAll(RegExp(r'[⟪⟫⧸]'), '')
        .replaceAll(RegExp(r'…+'), '. ')
        .replaceAll(RegExp(r'[。！？；!?;]+'), '. ')
        .replaceAll(RegExp(r'[，、,]+'), '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _debugTextHead(String text) {
    final head = text.length <= 180 ? text : text.substring(0, 180);
    final codes = head.runes.take(24).map((e) => e.toRadixString(16)).join(' ');
    return "$head | runes=$codes";
  }

  String _formatGoogleError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data["error"];
      if (error is Map) {
        final message = error["message"]?.toString();
        final status = error["status"]?.toString();
        if (message != null && message.isNotEmpty) {
          return "Google TTS 请求失败${status == null ? "" : "[$status]"}: $message";
        }
      }
      return "Google TTS 请求失败: $data";
    }
    if (data != null) {
      return "Google TTS 请求失败: $data";
    }
    return "Google TTS 请求失败: ${e.message}";
  }

  bool get _isChirp3HdVoice => voiceName.contains("-Chirp3-HD-");

  Future<void> _trimCache(Directory cacheDir) async {
    final entities = await cacheDir.list().where((e) => e is File).cast<File>().toList();
    if (entities.isEmpty) return;

    final stats = <({File file, int size, DateTime modified})>[];
    var totalBytes = 0;
    for (final file in entities) {
      try {
        final stat = await file.stat();
        totalBytes += stat.size;
        stats.add((file: file, size: stat.size, modified: stat.modified));
      } catch (_) {
        continue;
      }
    }

    stats.sort((a, b) => a.modified.compareTo(b.modified));

    while (stats.length > maxCacheFiles || totalBytes > maxCacheBytes) {
      final oldest = stats.removeAt(0);
      totalBytes -= oldest.size;
      try {
        if (await oldest.file.exists()) {
          await oldest.file.delete();
        }
      } catch (_) {
        // Ignore cache eviction failures.
      }
    }
  }

  String _fnv1a32(String input) {
    const int prime = 0x01000193;
    int hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
