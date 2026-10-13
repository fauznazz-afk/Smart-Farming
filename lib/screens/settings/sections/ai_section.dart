import 'package:flutter/material.dart';

import '../../../services/ai_settings.dart';
import '../../../utils/ai_provider.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../widgets/settings_fields.dart';

/// Provider, model, endpoint and API key for the in-app AI assistant.
///
/// **The key is the user's own.** There is no production key in this app and
/// nothing falls back to one: with no key the assistant is off, and it stays off
/// across restarts. It goes to `flutter_secure_storage` beside the ThingsBoard
/// token, never to `SharedPreferences`.
///
/// **This section saves itself, on change, rather than joining the screen's Save
/// button.** The button calls `SettingsController.save`, which validates and
/// writes everything at once; a key that only reaches storage when the user
/// remembers to press Save on an unrelated page is a worse default than an
/// immediate write, and a credential is exactly the field where "I typed it but
/// is it saved" should never be a question. Every other field on that screen
/// keeps the button.
class AiSection extends StatefulWidget {
  const AiSection({super.key});

  @override
  State<AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<AiSection> {
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _endpoint = TextEditingController();

  AiProvider _provider = AiProvider.openai;
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await AiSettings.load();
    // The back gesture can dispose this before the keystore read returns.
    if (!mounted) return;
    setState(() {
      _provider = settings.provider;
      _model.text = settings.model.isEmpty
          ? presetFor(settings.provider).defaultModel
          : settings.model;
      _endpoint.text = settings.endpoint;
      _apiKey.text = settings.apiKey;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  AiSettings get _current => AiSettings(
    provider: _provider,
    model: _model.text,
    endpoint: _endpoint.text,
    apiKey: _apiKey.text,
  );

  Future<void> _persist() async {
    await _current.save();
    if (mounted) setState(() => _saved = true);
  }

  void _onProviderChanged(AiProvider? provider) {
    if (provider == null) return;
    setState(() {
      _provider = provider;
      // Switching provider refills the model with that provider's default,
      // because a model name from one vendor is meaningless to another. The
      // typed endpoint is left alone: it only applies to Custom.
      _model.text = presetFor(provider).defaultModel;
      _saved = false;
    });
    _persist();
  }

  Future<void> _clearKey() async {
    await _current.clearApiKey();
    if (!mounted) return;
    setState(() {
      _apiKey.clear();
      _saved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key removed from this device.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(),
      );
    }
    final isCustom = _provider == AiProvider.custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<AiProvider>(
          initialValue: _provider,
          decoration: settingsFieldDecoration(
            label: 'Provider',
            helperText: 'Your own API key is used. The app ships none.',
          ),
          items: kAiProviderPresets
              .map(
                (preset) => DropdownMenuItem(
                  value: preset.provider,
                  child: Text(preset.label),
                ),
              )
              .toList(),
          onChanged: _onProviderChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _model,
          decoration: settingsFieldDecoration(
            label: 'Model',
            prefixIcon: const Icon(Icons.memory),
          ),
          onSubmitted: (_) => _persist(),
        ),
        // Only Custom needs a URL, so only Custom shows one. A field that is
        // ignored is a field whose contents the user cannot trust.
        if (isCustom) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _endpoint,
            keyboardType: TextInputType.url,
            decoration: settingsFieldDecoration(
              label: 'Chat endpoint (HTTPS)',
              prefixIcon: const Icon(Icons.link),
            ),
            onSubmitted: (_) => _persist(),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _apiKey,
          obscureText: true,
          // `enableSuggestions` and autocorrect would put a credential into the
          // keyboard's learning store, which on some IMEs syncs off-device.
          autocorrect: false,
          enableSuggestions: false,
          decoration: settingsFieldDecoration(
            label: 'API key',
            prefixIcon: const Icon(Icons.key),
          ).copyWith(
            suffixIcon: _apiKey.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove key',
                    onPressed: _clearKey,
                  ),
          ),
          onChanged: (_) => setState(() => _saved = false),
          onSubmitted: (_) => _persist(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _saved
              ? 'Saved to this device only.'
              : 'Stored in secure storage. It is never sent anywhere except the '
                    'provider above, and only when you ask a question.',
          style: AppType.bodySm.copyWith(color: AppSurfaces.onSurfaceVariant),
        ),
      ],
    );
  }
}