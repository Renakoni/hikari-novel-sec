import 'package:dio/dio.dart';

import '../../common/ai_debug_logger.dart';
import 'ai_provider_config.dart';

class AiChatProvider {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
    ),
  );

  Future<String> chat({
    required AiProviderConfig config,
    required List<Map<String, String>> messages,
  }) async {
    final baseUrl = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (baseUrl.isEmpty || config.apiKey.trim().isEmpty || config.model.trim().isEmpty) {
      throw Exception('AI 分析配置未完成');
    }

    final body = <String, dynamic>{
      'model': config.model.trim(),
      'messages': messages,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'stream': false,
    };
    if (config.model.contains('Qwen3')) {
      body['enable_thinking'] = false;
    }

    await AiDebugLogger.log('chat_request', {
      'provider': config.provider,
      'baseUrl': baseUrl,
      'apiKey': AiDebugLogger.maskSecret(config.apiKey),
      'model': config.model,
      'temperature': config.temperature,
      'maxTokens': config.maxTokens,
      'messages': messages
          .map((message) => {
                'role': message['role'],
                'contentPreview': AiDebugLogger.preview(message['content'] ?? ''),
                'contentLength': (message['content'] ?? '').length,
              })
          .toList(),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/chat/completions',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer ${config.apiKey.trim()}', 'Content-Type': 'application/json'}),
      );

      final data = response.data;
      final choices = data?['choices'];
      final firstChoice = choices is List && choices.isNotEmpty ? choices.first : null;
      final message = firstChoice is Map ? firstChoice['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) {
        await AiDebugLogger.log('chat_response', {
          'statusCode': response.statusCode,
          'contentLength': content.length,
          'contentPreview': AiDebugLogger.preview(content),
        });
        return content;
      }
      if (content is List) {
        final text = content.map((item) {
          if (item is String) return item;
          if (item is Map && item['type'] == 'text') return item['text']?.toString() ?? '';
          return '';
        }).join();
        if (text.trim().isNotEmpty) return text;
      }
      await AiDebugLogger.log('chat_empty_response', {'statusCode': response.statusCode});
      throw Exception('AI 返回为空');
    } catch (e) {
      await AiDebugLogger.log('chat_error', {
        'baseUrl': baseUrl,
        'model': config.model,
        'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<List<String>> fetchModels(AiProviderConfig config) async {
    final baseUrl = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (baseUrl.isEmpty || config.apiKey.trim().isEmpty) {
      throw Exception('AI Base URL 或 API Key 未填写');
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/models',
        options: Options(headers: {'Authorization': 'Bearer ${config.apiKey.trim()}'}),
      );
      final raw = response.data?['data'];
      final models = raw is List
          ? raw.map((item) {
              if (item is Map) return item['id']?.toString() ?? '';
              return '';
            }).where((id) => id.trim().isNotEmpty).toList()
          : <String>[];
      await AiDebugLogger.log('fetch_models', {
        'baseUrl': baseUrl,
        'apiKey': AiDebugLogger.maskSecret(config.apiKey),
        'statusCode': response.statusCode,
        'count': models.length,
        'modelsPreview': models.take(30).toList(),
      });
      return models;
    } catch (e) {
      await AiDebugLogger.log('fetch_models_error', {
        'baseUrl': baseUrl,
        'apiKey': AiDebugLogger.maskSecret(config.apiKey),
        'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<void> testConnection(AiProviderConfig config) async {
    final text = await chat(
      config: config,
      messages: const [
        {'role': 'system', 'content': '你是一个连接测试助手。'},
        {'role': 'user', 'content': '只输出 OK'},
      ],
    );
    if (text.trim().isEmpty) throw Exception('AI 返回为空');
  }
}
