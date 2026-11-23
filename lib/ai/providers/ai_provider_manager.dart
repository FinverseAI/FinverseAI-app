import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_provider_config.dart';
import 'ai_constants.dart';
import '../../services/system/logger_service.dart';

/// AI 服务商管理服务
///
/// 管理多个服务商配置和能力绑定
class AIProviderManager {
  static const String _tag = 'AIProviderManager';
  static const String _keyProviders = 'ai_providers_v2';
  static const String _keyBinding = 'ai_capability_binding_v2';

  /// FinVerse AI status, from GET {finverseApiBaseUrl}/ai/status.
  /// The endpoint is session-guarded, so before sign-in (and whenever the
  /// backend key is unset) every check fails and capability reports
  /// "not configured" — that is the honest answer until auth lands.
  static DateTime? _finverseStatusCheckedAt;
  static bool _finverseStatusConfigured = false;
  static String? _finverseStatusPrimaryModel;

  /// Backend pieces capture still needs. Flip each to true when the
  /// endpoint ships (see CAPTURE-PLAN.md §2.1/§2.2); until then the
  /// matching capability honestly reports "not configured".
  static const bool _finverseExtractReady = false; // POST /api/ai/extract
  static const bool _finverseTranscribeReady = false; // POST /api/ai/transcribe
  static const bool _finverseVisionReady = false; // vision in /api/ai/extract

  /// Whether the FinVerse backend reports its AI as configured.
  /// Cached for 60s; any failure (no session, no key, offline) is false.
  static Future<bool> isFinverseAiConfigured() async {
    final now = DateTime.now();
    if (_finverseStatusCheckedAt != null &&
        now.difference(_finverseStatusCheckedAt!).inSeconds < 60) {
      return _finverseStatusConfigured;
    }
    var configured = false;
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get<Map<String, dynamic>>(
        '${AIConstants.finverseApiBaseUrl}/ai/status',
      );
      final data = response.data;
      if (response.statusCode == 200 && data != null) {
        configured = data['configured'] == true;
        final model = data['primaryModel'];
        if (model is String && model.isNotEmpty) {
          _finverseStatusPrimaryModel = model;
        }
      }
    } catch (e) {
      logger.info(_tag, 'FinVerse AI status check failed: $e');
      configured = false;
    }
    _finverseStatusCheckedAt = now;
    _finverseStatusConfigured = configured;
    return configured;
  }

  /// Primary model name last reported by GET /api/ai/status, if any.
  static String? get finversePrimaryModel => _finverseStatusPrimaryModel;

  /// 全局回调:任何改了 providers / binding / custom_prompt 的地方都会打到这里,
  /// sync_providers 启动时注入一个"推送 AI 配置到 server"的实现,就能把变更
  /// 无感同步到另一台设备 + web。fire-and-forget,不抛。
  static void Function()? onConfigChanged;

  /// 保存自定义提示词。跟 providers/binding 同套路,走统一的 onConfigChanged。
  static Future<void> saveCustomPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_custom_prompt', prompt);
    try {
      onConfigChanged?.call();
    } catch (e, st) {
      logger.warning(_tag, 'onConfigChanged 触发失败: $e', st);
    }
  }

  /// 生成简单的唯一ID
  static String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'provider_${timestamp}_$random';
  }

  /// 获取所有服务商配置
  static Future<List<AIServiceProviderConfig>> getProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyProviders);

    if (jsonStr == null || jsonStr.isEmpty) {
      // 首次使用，尝试从旧配置迁移
      await migrateFromOldConfig();

      // 迁移后重新读取
      final migratedStr = prefs.getString(_keyProviders);
      if (migratedStr == null || migratedStr.isEmpty) {
        // 如果迁移后仍为空，初始化默认服务商
        final defaultProviders = [AIServiceProviderConfig.finverseDefault];
        await _saveProviders(defaultProviders);
        return defaultProviders;
      }
      // 迁移成功，继续解析
      return _parseProviders(migratedStr);
    }

    return _parseProviders(jsonStr);
  }

  /// 解析服务商配置 JSON
  static Future<List<AIServiceProviderConfig>> _parseProviders(String jsonStr) async {
    try {
      final jsonList = jsonDecode(jsonStr) as List;
      var providers = jsonList
          .map((e) => AIServiceProviderConfig.fromJson(e as Map<String, dynamic>))
          .toList();

      // FinVerse AI is the only provider now: drop any stored Zhipu/custom
      // provider (no per-user provider configuration) and make sure the
      // built-in FinVerse provider is present.
      providers.removeWhere((p) => p.id != AIConstants.finverseProviderId);
      if (!providers.any((p) => p.id == AIConstants.finverseProviderId)) {
        providers.insert(0, AIServiceProviderConfig.finverseDefault);
        await _saveProviders(providers);
      }

      return providers;
    } catch (e, st) {
      logger.error(_tag, '解析服务商配置失败', e, st);
      return [AIServiceProviderConfig.finverseDefault];
    }
  }

  /// 获取单个服务商配置
  static Future<AIServiceProviderConfig?> getProvider(String id) async {
    final providers = await getProviders();
    try {
      return providers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 添加服务商
  static Future<AIServiceProviderConfig> addProvider({
    required String name,
    required String apiKey,
    required String baseUrl,
    String textModel = '',
    String visionModel = '',
    String audioModel = '',
  }) async {
    final providers = await getProviders();

    final newProvider = AIServiceProviderConfig(
      id: _generateId(),
      name: name,
      isBuiltIn: false,
      apiKey: apiKey,
      baseUrl: baseUrl,
      textModel: textModel,
      visionModel: visionModel,
      audioModel: audioModel,
      createdAt: DateTime.now(),
    );

    providers.add(newProvider);
    await _saveProviders(providers);

    logger.info(_tag, '添加服务商: ${newProvider.name}');
    return newProvider;
  }

  /// 直接添加服务商配置（保留原始 ID，用于配置导入）
  static Future<void> addProviderWithConfig(AIServiceProviderConfig provider) async {
    final providers = await getProviders();
    providers.add(provider);
    await _saveProviders(providers);
    logger.info(_tag, '导入服务商: ${provider.name} (ID: ${provider.id})');
  }

  /// 更新服务商
  static Future<void> updateProvider(AIServiceProviderConfig provider) async {
    final providers = await getProviders();
    final index = providers.indexWhere((p) => p.id == provider.id);

    if (index >= 0) {
      providers[index] = provider;
      await _saveProviders(providers);
      logger.info(_tag, '更新服务商: ${provider.name}');
    }
  }

  /// 删除服务商
  static Future<bool> deleteProvider(String id) async {
    final providers = await getProviders();
    final provider = providers.firstWhere(
      (p) => p.id == id,
      orElse: () => AIServiceProviderConfig.finverseDefault,
    );

    // 内置服务商不可删除
    if (provider.isBuiltIn) {
      logger.warning(_tag, '无法删除内置服务商');
      return false;
    }

    providers.removeWhere((p) => p.id == id);
    await _saveProviders(providers);

    // 如果删除的服务商正在使用，重置为默认
    final binding = await getCapabilityBinding();
    var needUpdate = false;
    var newBinding = binding;

    if (binding.textProviderId == id) {
      newBinding = newBinding.copyWith(
          textProviderId: AIConstants.finverseProviderId);
      needUpdate = true;
    }
    if (binding.visionProviderId == id) {
      newBinding = newBinding.copyWith(
          visionProviderId: AIConstants.finverseProviderId);
      needUpdate = true;
    }
    if (binding.speechProviderId == id) {
      newBinding = newBinding.copyWith(
          speechProviderId: AIConstants.finverseProviderId);
      needUpdate = true;
    }

    if (needUpdate) {
      await saveCapabilityBinding(newBinding);
    }

    logger.info(_tag, '删除服务商: ${provider.name}');
    return true;
  }

  /// 保存服务商列表
  static Future<void> _saveProviders(List<AIServiceProviderConfig> providers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(providers.map((p) => p.toJson()).toList());
    await prefs.setString(_keyProviders, jsonStr);
    try {
      onConfigChanged?.call();
    } catch (e, st) {
      logger.warning(_tag, 'onConfigChanged 触发失败: $e', st);
    }
  }

  /// 获取能力绑定配置
  static Future<AICapabilityBinding> getCapabilityBinding() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyBinding);

    if (jsonStr == null || jsonStr.isEmpty) {
      return AICapabilityBinding.defaultBinding;
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AICapabilityBinding.fromJson(json);
    } catch (e, st) {
      logger.error(_tag, '解析能力绑定失败', e, st);
      return AICapabilityBinding.defaultBinding;
    }
  }

  /// 保存能力绑定配置。保存后触发 onConfigChanged,把当前 AI 全量配置推到 server。
  static Future<void> saveCapabilityBinding(AICapabilityBinding binding) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(binding.toJson());
    await prefs.setString(_keyBinding, jsonStr);
    logger.info(_tag, '保存能力绑定: text=${binding.textProviderId}, vision=${binding.visionProviderId}, speech=${binding.speechProviderId}');
    try {
      onConfigChanged?.call();
    } catch (e, st) {
      logger.warning(_tag, 'onConfigChanged 触发失败: $e', st);
    }
  }

  /// 当前 AI 配置的完整 snapshot,用于推给 server 同步到另一端。
  /// 包括 providers / binding / custom_prompt / strategy 和几个开关。
  static Future<Map<String, dynamic>> snapshotForSync() async {
    final prefs = await SharedPreferences.getInstance();
    final providers = await getProviders();
    final binding = await getCapabilityBinding();
    final snapshot = <String, dynamic>{
      'providers': providers.map((p) => p.toJson()).toList(),
      'binding': binding.toJson(),
      'custom_prompt': prefs.getString('ai_custom_prompt') ?? '',
      'strategy': prefs.getString('ai_strategy') ?? '',
      'bill_extraction_enabled':
          prefs.getBool('ai_bill_extraction_enabled') ?? false,
      'use_vision': prefs.getBool('ai_use_vision') ?? false,
    };
    // 语音设置仅在本机曾显式配置时才携带。server 端 ai_config 是整包替换,
    // 若未设置端携带空值回推,会清空他机在 server 上配好的语音设置。
    if (prefs.containsKey(AIConstants.keyVoiceTriggerMode)) {
      snapshot['voice_trigger_mode'] =
          prefs.getString(AIConstants.keyVoiceTriggerMode);
    }
    if (prefs.containsKey(AIConstants.keyVoiceSilenceTimeoutMs)) {
      snapshot['voice_silence_timeout_ms'] =
          prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs);
    }
    return snapshot;
  }

  /// 把 server /profile/me 返回的 ai_config dict 落到本地 SharedPreferences。
  /// 只改跟 server 不同的字段,避免 saveXxx 回调再次触发 onConfigChanged 循环。
  static Future<void> applyFromServer(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();

    // providers(比较序列化后的 string,简单又稳)
    final rawProviders = config['providers'];
    if (rawProviders is List) {
      final jsonStr = jsonEncode(rawProviders);
      if (prefs.getString(_keyProviders) != jsonStr) {
        await prefs.setString(_keyProviders, jsonStr);
      }
    }

    final rawBinding = config['binding'];
    if (rawBinding is Map<String, dynamic>) {
      final jsonStr = jsonEncode(rawBinding);
      if (prefs.getString(_keyBinding) != jsonStr) {
        await prefs.setString(_keyBinding, jsonStr);
      }
    }

    final prompt = config['custom_prompt'] as String?;
    if (prompt != null && prefs.getString('ai_custom_prompt') != prompt) {
      await prefs.setString('ai_custom_prompt', prompt);
    }

    final strategy = config['strategy'] as String?;
    if (strategy != null && strategy.isNotEmpty &&
        prefs.getString('ai_strategy') != strategy) {
      await prefs.setString('ai_strategy', strategy);
    }

    final billEnabled = config['bill_extraction_enabled'] as bool?;
    if (billEnabled != null &&
        prefs.getBool('ai_bill_extraction_enabled') != billEnabled) {
      await prefs.setBool('ai_bill_extraction_enabled', billEnabled);
    }

    final useVision = config['use_vision'] as bool?;
    if (useVision != null && prefs.getBool('ai_use_vision') != useVision) {
      await prefs.setBool('ai_use_vision', useVision);
    }

    // 语音触发方式 / 静音阈值（仅当与本地不同才写，避免触发同步回环）
    final voiceTriggerMode = config['voice_trigger_mode'] as String?;
    if (voiceTriggerMode != null &&
        voiceTriggerMode.isNotEmpty &&
        prefs.getString(AIConstants.keyVoiceTriggerMode) != voiceTriggerMode) {
      await prefs.setString(AIConstants.keyVoiceTriggerMode, voiceTriggerMode);
    }
    final voiceSilenceTimeout =
        (config['voice_silence_timeout_ms'] as num?)?.toInt();
    if (voiceSilenceTimeout != null &&
        prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs) !=
            voiceSilenceTimeout) {
      await prefs.setInt(
          AIConstants.keyVoiceSilenceTimeoutMs, voiceSilenceTimeout);
    }
    logger.info(_tag, 'AI 配置已从 server 应用到本地');
  }

  /// 设置单个能力的服务商
  static Future<void> setCapabilityProvider(
    AICapabilityType type,
    String providerId,
  ) async {
    final binding = await getCapabilityBinding();
    AICapabilityBinding newBinding;

    switch (type) {
      case AICapabilityType.text:
        newBinding = binding.copyWith(textProviderId: providerId);
        break;
      case AICapabilityType.vision:
        newBinding = binding.copyWith(visionProviderId: providerId);
        break;
      case AICapabilityType.speech:
        newBinding = binding.copyWith(speechProviderId: providerId);
        break;
    }

    await saveCapabilityBinding(newBinding);
  }

  /// 获取指定能力的服务商配置
  static Future<AIServiceProviderConfig?> getProviderForCapability(
    AICapabilityType type,
  ) async {
    final binding = await getCapabilityBinding();
    String? providerId;

    switch (type) {
      case AICapabilityType.text:
        providerId = binding.textProviderId;
        break;
      case AICapabilityType.vision:
        providerId = binding.visionProviderId;
        break;
      case AICapabilityType.speech:
        providerId = binding.speechProviderId;
        break;
    }

    if (providerId == null) {
      return AIServiceProviderConfig.finverseDefault;
    }

    return await getProvider(providerId);
  }

  /// 指定能力对应的 provider 是否已配置好。
  ///
  /// For the built-in FinVerse AI provider, "configured" means the backend
  /// reports its AI as configured (GET /api/ai/status) AND the backend
  /// piece that capability needs exists (extract / transcribe / vision).
  /// Until those endpoints ship, every capability honestly reports
  /// "not configured" and capture buttons stay disabled.
  static Future<bool> isCapabilityConfigured(AICapabilityType type) async {
    final provider = await getProviderForCapability(type);
    if (provider == null) return false;
    if (provider.id != AIConstants.finverseProviderId) {
      return provider.isValid;
    }
    if (!await isFinverseAiConfigured()) return false;
    switch (type) {
      case AICapabilityType.text:
        return _finverseExtractReady;
      case AICapabilityType.vision:
        return _finverseExtractReady && _finverseVisionReady;
      case AICapabilityType.speech:
        return _finverseTranscribeReady && _finverseExtractReady;
    }
  }

  /// 迁移旧配置到新格式：只保留 FinVerse AI，丢弃旧的智谱/自定义服务商。
  static Future<void> migrateFromOldConfig() async {
    final prefs = await SharedPreferences.getInstance();

    // 检查是否已迁移
    if (prefs.containsKey(_keyProviders)) {
      return;
    }

    logger.info(_tag, '开始迁移旧配置：切换到 FinVerse AI');

    await _saveProviders([AIServiceProviderConfig.finverseDefault]);

    // 设置能力绑定
    await saveCapabilityBinding(AICapabilityBinding.defaultBinding);

    logger.info(_tag, '配置迁移完成');
  }
}
