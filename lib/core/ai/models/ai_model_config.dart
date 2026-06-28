import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _secureStorage = FlutterSecureStorage();

/// 支持的 AI 模型供应商
enum AiProvider {
  deepseek('DeepSeek', 'https://api.deepseek.com/v1/chat/completions'),
  tongyi('通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'),
  openai('OpenAI', 'https://api.openai.com/v1/chat/completions'),
  moonshot('Moonshot(月之暗面)', 'https://api.moonshot.cn/v1/chat/completions');

  final String displayName;
  final String defaultEndpoint;
  const AiProvider(this.displayName, this.defaultEndpoint);
}

/// 单个 AI 模型配置
class AiModelConfig {
  final AiProvider provider;
  final String endpoint;
  final String model;
  final String apiKey;

  const AiModelConfig({
    required this.provider,
    required this.endpoint,
    required this.model,
    required this.apiKey,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'endpoint': endpoint,
        'model': model,
      };
}

/// 安全存储 Key 常量
class AiStorageKeys {
  static const deepseekKey = 'ai_deepseek_api_key';
  static const tongyiKey = 'ai_tongyi_api_key';
  static const openaiKey = 'ai_openai_api_key';
  static const moonshotKey = 'ai_moonshot_api_key';
  static const activeProvider = 'ai_active_provider';
  static const customEndpoint = 'ai_custom_endpoint';
  static const customModel = 'ai_custom_model';

  static String keyFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.deepseek:
        return deepseekKey;
      case AiProvider.tongyi:
        return tongyiKey;
      case AiProvider.openai:
        return openaiKey;
      case AiProvider.moonshot:
        return moonshotKey;
    }
  }
}

/// 获取已保存的 API Key
Future<String?> getApiKey(AiProvider provider) async {
  return _secureStorage.read(key: AiStorageKeys.keyFor(provider));
}

/// 保存 API Key
Future<void> saveApiKey(AiProvider provider, String key) async {
  await _secureStorage.write(key: AiStorageKeys.keyFor(provider), value: key);
}

/// 删除 API Key
Future<void> deleteApiKey(AiProvider provider) async {
  await _secureStorage.delete(key: AiStorageKeys.keyFor(provider));
}

/// 获取当前激活的供应商
Future<AiProvider> getActiveProvider() async {
  final value = await _secureStorage.read(key: AiStorageKeys.activeProvider);
  return AiProvider.values.firstWhere(
    (p) => p.name == value,
    orElse: () => AiProvider.deepseek,
  );
}

/// 保存当前激活的供应商
Future<void> setActiveProvider(AiProvider provider) async {
  await _secureStorage.write(key: AiStorageKeys.activeProvider, value: provider.name);
}

// ===== Riverpod Provider =====

/// 当前 AI 模型配置 Provider
final aiConfigProvider = FutureProvider<({AiProvider provider, String? apiKey})>((ref) async {
  final provider = await getActiveProvider();
  final apiKey = await getApiKey(provider);
  return (provider: provider, apiKey: apiKey);
});
