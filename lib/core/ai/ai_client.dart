import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'models/ai_model_config.dart';

class AiClient {
  late final Dio _dio;

  AiClient({Dio? dio}) {
    _dio = (dio ?? Dio())
      ..options.connectTimeout = const Duration(seconds: 30)
      ..options.receiveTimeout = const Duration(seconds: 120);
    _dio.interceptors.add(_RetryInterceptor());
  }

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

  Stream<String> chatStream({
    required AiProvider provider,
    required String apiKey,
    required List<AiMessage> messages,
    String model = '',
  }) async* {
    final endpoint = _getEndpoint(provider);
    final modelName = model.isEmpty ? _defaultModel(provider) : model;

    final response = await _dio.post(
      endpoint,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': modelName,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': true,
        'temperature': 0.8,
        'max_tokens': 4096,
      },
    );

    if (response.statusCode != 200) {
      throw AiException('API 请求失败: ${response.statusCode}');
    }

    final responseStream = response.data.stream as Stream<List<int>>;
    await for (final chunk in responseStream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'] as String?;
            if (content != null) yield content;
          } catch (_) {}
        }
      }
    }
  }

  String _getEndpoint(AiProvider provider) {
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

class _RetryInterceptor extends Interceptor {
  final int maxRetries = 2;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && err.requestOptions.extra['retryCount'] == null) {
      for (int i = 0; i < maxRetries; i++) {
        await Future.delayed(Duration(seconds: (i + 1) * 2));
        try {
          err.requestOptions.extra['retryCount'] = i + 1;
          final response = await Dio().fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (_) {
          continue;
        }
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response != null && err.response!.statusCode! >= 500);
  }
}

class AiMessage {
  final String role;
  final String content;

  const AiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

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
