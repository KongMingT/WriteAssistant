import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _secureStorage = FlutterSecureStorage();

/// 支持的 AI 模型供应商
enum AiProvider {
  deepseek('DeepSeek', 'https://api.deepseek.com/v1/chat/completions', 'deepseek-chat'),
  tongyi('通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions', 'qwen-plus'),
  openai('OpenAI', 'https://api.openai.com/v1/chat/completions', 'gpt-4o-mini'),
  moonshot('Moonshot(月之暗面)', 'https://api.moonshot.cn/v1/chat/completions', 'moonshot-v1-8k');

  final String displayName;
  final String defaultEndpoint;
  final String defaultModel;
  const AiProvider(this.displayName, this.defaultEndpoint, this.defaultModel);
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

  /// 自定义端点 Key（按供应商隔离，便于切换时不影响其他供应商）
  static String endpointKeyFor(AiProvider provider) => 'ai_custom_endpoint_${provider.name}';

  /// 自定义模型 Key（按供应商隔离）
  static String modelKeyFor(AiProvider provider) => 'ai_custom_model_${provider.name}';
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

/// 获取自定义端点（无则返回 null）
Future<String?> getCustomEndpoint(AiProvider provider) async {
  return _secureStorage.read(key: AiStorageKeys.endpointKeyFor(provider));
}

/// 保存自定义端点
Future<void> saveCustomEndpoint(AiProvider provider, String endpoint) async {
  await _secureStorage.write(key: AiStorageKeys.endpointKeyFor(provider), value: endpoint);
}

/// 获取自定义模型名（无则返回 null）
Future<String?> getCustomModel(AiProvider provider) async {
  return _secureStorage.read(key: AiStorageKeys.modelKeyFor(provider));
}

/// 保存自定义模型名
Future<void> saveCustomModel(AiProvider provider, String model) async {
  await _secureStorage.write(key: AiStorageKeys.modelKeyFor(provider), value: model);
}

/// 删除自定义端点
Future<void> deleteCustomEndpoint(AiProvider provider) async {
  await _secureStorage.delete(key: AiStorageKeys.endpointKeyFor(provider));
}

/// 删除自定义模型名
Future<void> deleteCustomModel(AiProvider provider) async {
  await _secureStorage.delete(key: AiStorageKeys.modelKeyFor(provider));
}

// ===== Riverpod Provider =====

/// 当前 AI 模型配置 Provider
final aiConfigProvider = FutureProvider<({AiProvider provider, String? apiKey})>((ref) async {
  final provider = await getActiveProvider();
  final apiKey = await getApiKey(provider);
  return (provider: provider, apiKey: apiKey);
});
