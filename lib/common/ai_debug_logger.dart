import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AiDebugLogger {
  static const _fileName = 'hikari_ai_debug.txt';
  static const _channel = MethodChannel('hikari/debug_files');

  static Future<File> logFile() async {
    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('downloadFilePath', {'name': _fileName});
        if (path != null && path.trim().isNotEmpty) return File(path);
      } catch (_) {}
    }
    final dir = await _baseDir();
    return File('${dir.path}/$_fileName');
  }

  static Future<String> readLog() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<String>('readDownloadTextFile', {'name': _fileName}) ?? '';
      } catch (_) {}
    }
    final file = await logFile();
    return await file.exists() ? file.readAsString() : '';
  }

  static Future<void> clearLog() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('writeDownloadTextFile', {'name': _fileName, 'text': ''});
        return;
      } catch (_) {}
    }
    final file = await logFile();
    if (await file.exists()) {
      await file.writeAsString('', flush: true);
    }
  }

  static Future<Directory> _baseDir() async {
    if (Platform.isAndroid) {
      final download = await _writableAndroidDownloadDir();
      if (download != null) return download;
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    return getApplicationDocumentsDirectory();
  }

  static Future<Directory?> _writableAndroidDownloadDir() async {
    final candidates = <String>[
      '${Platform.environment['EXTERNAL_STORAGE'] ?? '/storage/emulated/0'}/Download',
      '/sdcard/Download',
    ];

    for (final path in candidates.toSet()) {
      try {
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final probe = File('${dir.path}/.hikari_ai_debug_probe');
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return dir;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> log(String event, Map<String, dynamic> data) async {
    try {
      final payload = {
        'time': DateTime.now().toIso8601String(),
        'event': event,
        ...data,
      };
      const encoder = JsonEncoder.withIndent('  ');
      final text = '${encoder.convert(payload)}\n\n';
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('appendDownloadTextFile', {'name': _fileName, 'text': text});
          return;
        } catch (_) {}
      }
      final file = await logFile();
      await file.writeAsString(text, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static String maskSecret(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (text.length <= 8) return '***';
    return '${text.substring(0, 4)}****${text.substring(text.length - 4)}';
  }

  static String preview(String value, {int max = 800}) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...(truncated)';
  }
}
