import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/ai_provider.dart';

const _aiStorage = FlutterSecureStorage();
const _aiApiKeyKey = 'ai_api_key';
const _aiProviderKey = 'ai_provider';
const _aiModelKey = 'ai_model';
const _aiEndpointKey = 'ai_endpoint';

/// The user's AI assistant configuration, as saved.
///
/// **The API key is the user's own and is stored beside the ThingsBoard token
/// in `flutter_secure_storage`**, never in `SharedPreferences` and never in a
/// build config. There is no production key in this app: without a key here the
/// assistant is simply switched off, and it stays off across restarts rather
/// than falling back to anything.
class AiSettings {
  const AiSettings({
    required this.provider,
    required this.model,
    required this.endpoint,
    required this.apiKey,
  });

  final AiProvider provider;
  final String model;

  /// Only used for [AiProvider.custom]; the presets carry their own.
  final String endpoint;
  final String apiKey;

  /// False when there is no key, which is the whole "is it configured" test.
  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  /// The preset for [provider], except that custom carries the typed URL.
  AiProviderPreset get preset {
    final base = presetFor(provider);
    if (base.endpoint.isNotEmpty) return base;
    return AiProviderPreset(
      provider: AiProvider.custom,
      label: base.label,
      endpoint: endpoint.trim(),
      defaultModel: model,
    );
  }

  /// Load the saved configuration, falling back to no key and the first preset.
  static Future<AiSettings> load() async {
    final storedProvider = await _aiStorage.read(key: _aiProviderKey);
    final provider = AiProvider.values.firstWhere(
      (p) => p.name == storedProvider,
      // A stored name that no longer exists after a downgrade must not throw on
      // launch; fall back rather than blocking the app on a setting.
      orElse: () => AiProvider.openai,
    );
    return AiSettings(
      provider: provider,
      model: await _aiStorage.read(key: _aiModelKey) ?? '',
      endpoint: await _aiStorage.read(key: _aiEndpointKey) ?? '',
      apiKey: await _aiStorage.read(key: _aiApiKeyKey) ?? '',
    );
  }

  Future<void> save() async {
    await _aiStorage.write(key: _aiProviderKey, value: provider.name);
    await _aiStorage.write(key: _aiModelKey, value: model.trim());
    await _aiStorage.write(key: _aiEndpointKey, value: endpoint.trim());
    await _aiStorage.write(key: _aiApiKeyKey, value: apiKey.trim());
  }

  /// Forget the key, leaving the provider and model in place.
  ///
  /// Reached from Settings so a key can be revoked from the device without the
  /// user retyping a URL and a model name.
  Future<void> clearApiKey() => _aiStorage.delete(key: _aiApiKeyKey);
}