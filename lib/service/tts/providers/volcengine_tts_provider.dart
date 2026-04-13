import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../common/log.dart';
import '../tts_provider.dart';

class VolcengineTtsProvider extends TtsProvider {
  static const String endpoint = "https://openspeech.bytedance.com/api/v3/tts/unidirectional/sse";
  static const int maxCacheFiles = 240;
  static const int maxCacheBytes = 160 * 1024 * 1024;
  static const String defaultContextInstruction = "请用平稳、自然、克制的旁白语气朗读，保持整章前后语气一致，避免明显情绪波动，语速均匀。";

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;

  String appId = "";
  String accessKey = "";
  String resourceId = "seed-tts-1.0";
  String speaker = "";
  String contextInstruction = defaultContextInstruction;
  String? emotion;
  int? emotionScale;

  double _rate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;

  @override
  String get id => "volcengine";

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
  Future<void> setRate(double value) async {
    _rate = value.clamp(0.1, 2.0);
  }

  @override
  Future<void> setPitch(double value) async {
    _pitch = value.clamp(0.5, 2.0);
  }

  @override
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 2.0);
    await _player.setVolume(_volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> speak(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      emit(TtsProviderEvent(TtsProviderEventType.error, message: "火山引擎 TTS 文本为空"));
      return;
    }
    if (appId.trim().isEmpty || accessKey.trim().isEmpty || resourceId.trim().isEmpty || speaker.trim().isEmpty) {
      emit(TtsProviderEvent(TtsProviderEventType.error, message: "请先填写火山引擎 App ID、Access Key、Resource ID 和 Speaker"));
      return;
    }

    try {
      final audioPath = await _ensureAudioFile(cleaned);
      await _player.setFilePath(audioPath);
      await _player.setVolume(_volume.clamp(0.0, 1.0));
      await _player.play();
      emit(const TtsProviderEvent(TtsProviderEventType.started));
    } catch (e) {
      Log.d("[VolcengineTtsProvider] speak failed: $e");
      emit(TtsProviderEvent(TtsProviderEventType.error, message: e.toString()));
    }
  }

  @override
  Future<void> preload(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    if (appId.trim().isEmpty || accessKey.trim().isEmpty || resourceId.trim().isEmpty || speaker.trim().isEmpty) return;
    try {
      await _ensureAudioFile(cleaned);
    } catch (e) {
      Log.d("[VolcengineTtsProvider] preload failed: $e");
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
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory(path.join(dir.path, "tts_cache", "volcengine"));
    await cacheDir.create(recursive: true);

    final hash = _fnv1a32(
      "$resourceId|$speaker|${emotion ?? ""}|${emotionScale ?? ""}|${_rate.toStringAsFixed(2)}|${_pitch.toStringAsFixed(2)}|${_volume.toStringAsFixed(2)}|${_normalizedContextInstruction()}|$text",
    );
    final filePath = path.join(cacheDir.path, "$hash.mp3");
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }

    final audioParams = <String, dynamic>{
      "format": "mp3",
      "sample_rate": 24000,
    };
    if (emotion != null && emotion!.trim().isNotEmpty) {
      audioParams["emotion"] = emotion!.trim();
    }
    if (emotionScale != null) {
      audioParams["emotion_scale"] = emotionScale;
    }

    final payload = {
      "user": {"uid": "hikari_novel_flutter"},
      "req_params": {
        "text": text,
        "speaker": speaker.trim(),
        "context_texts": [_normalizedContextInstruction()],
        "audio_params": audioParams,
      },
    };

    final response = await _dio.post(
      endpoint,
      data: payload,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          "X-Api-App-Id": appId.trim(),
          "X-Api-Access-Key": accessKey.trim(),
          "X-Api-Resource-Id": resourceId.trim(),
          "X-Api-Request-Id": "${DateTime.now().microsecondsSinceEpoch}",
          HttpHeaders.contentTypeHeader: "application/json",
          HttpHeaders.acceptHeader: "text/event-stream",
        },
      ),
    );

    final stream = response.data;
    if (stream is! ResponseBody) {
      throw Exception("火山引擎 TTS 返回格式异常");
    }

    final bytes = await _collectSseAudio(stream.stream);
    if (bytes.isEmpty) {
      throw Exception("火山引擎 TTS 未返回音频数据");
    }

    await file.writeAsBytes(bytes, flush: true);
    await _trimCache(cacheDir);
    return filePath;
  }

  String _normalizedContextInstruction() {
    final cleaned = contextInstruction.trim();
    return cleaned.isEmpty ? defaultContextInstruction : cleaned;
  }

  Future<Uint8List> _collectSseAudio(Stream<List<int>> stream) async {
    final audio = BytesBuilder(copy: false);
    final decoder = Utf8Decoder();
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(decoder.convert(chunk));
      var content = buffer.toString();
      var splitIndex = content.indexOf('\n\n');
      while (splitIndex != -1) {
        final frame = content.substring(0, splitIndex);
        content = content.substring(splitIndex + 2);
        _consumeSseFrame(frame, audio);
        splitIndex = content.indexOf('\n\n');
      }
      buffer
        ..clear()
        ..write(content);
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      _consumeSseFrame(remaining, audio);
    }
    return audio.toBytes();
  }

  void _consumeSseFrame(String frame, BytesBuilder audio) {
    for (final line in frame.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final jsonText = trimmed.substring(5).trim();
      if (jsonText.isEmpty) continue;

      final body = jsonDecode(jsonText) as Map<String, dynamic>;
      final code = body["code"];
      if (code == 0) {
        final data = body["data"]?.toString();
        if (data != null && data.isNotEmpty && data != "null") {
          audio.add(base64Decode(data));
        }
        continue;
      }
      if (code == 20000000) {
        return;
      }

      final message = body["message"]?.toString() ?? "火山引擎 TTS 合成失败";
      throw Exception(message);
    }
  }

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
