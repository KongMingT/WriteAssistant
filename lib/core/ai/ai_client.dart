import 'package:dio/dio.dart';

import 'models/ai_model_config.dart';

/// AI API 调用客户端
class AiClient {
  final Dio _dio;

  AiClient({Dio? dio}) : _dio = dio ?? Dio();

  /// 发送聊天请求（流式）
  Future<AiResponse> chat({
    required AiProvider provider,
    required String apiKey,
    required List<AiMessage> messages,
    String model = '',
    bool stream = false,
  }) async {
    final endpoint = _getEndpoint(provider);
    final modelName = model.isEmpty ? _defaultModel(provider) : model;

    final response = await _dio.post(
      endpoint,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': modelName,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': stream,
        'temperature': 0.8,
        'max_tokens': 4096,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final content = data['choices']?[0]?['message']?['content'] as String? ?? '';
      return AiResponse(content: content);
    } else {
      throw AiException('API 请求失败: ${response.statusCode} ${response.data}');
    }
  }

  String _getEndpoint(AiProvider provider) {
    // TODO: 支持自定义 endpoint
    return provider.defaultEndpoint;
  }

  String _defaultModel(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return 'deepseek-chat';
      case AiProvider.tongyi:
        return 'qwen-plus';
      case AiProvider.openai:
        return 'gpt-4o-mini';
      case AiProvider.moonshot:
        return 'moonshot-v1-8k';
    }
  }
}

/// 消息
class AiMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;

  const AiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// 响应
class AiResponse {
  final String content;

  const AiResponse({required this.content});
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => 'AiException: $message';
}
