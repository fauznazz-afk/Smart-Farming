import 'package:flutter/material.dart';

import '../services/ai_chat_service.dart';
import '../services/ai_settings.dart';
import '../utils/ai_provider.dart';
import 'dashboard/utils/design_tokens.dart';
import '../widgets/liquid_glass.dart';

/// Ask the model a question about the current telemetry.
///
/// **The telemetry summary is passed in, not read.** The dashboard owns the live
/// values and rebuilds on its own poll; reaching into it from here would make a
/// chat screen depend on a screen's private state, which is the one thing the
/// layering in this app is for.
///
/// **Nothing is persisted.** The transcript lives in this [State] and dies with
/// the screen, so closing the assistant leaves no conversation on the device.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.telemetrySummary,
    this.openSettings,
  });

  /// The block the model is allowed to answer from. See [buildTelemetrySummary].
  final String telemetrySummary;

  /// Sends the user to the assistant's settings. Optional so a test can skip
  /// the navigation.
  final VoidCallback? openSettings;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const AiChatService _service = AiChatService();

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AiTurn>[];

  AiSettings? _settings;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await AiSettings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final settings = _settings;
    final question = _input.text;
    if (settings == null || !settings.isConfigured || _sending) return;
    // The sanitised text is what is appended, so the bubble on screen and the
    // text on the wire are the same string. Sending one and showing the other is
    // how a length cut becomes invisible.
    final sanitized = sanitizeQuestion(question);
    if (sanitized.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AiTurn(role: 'user', text: sanitized));
      _input.clear();
    });
    _scrollToEnd();

    try {
      final reply = await _service.ask(
        preset: settings.preset,
        apiKey: settings.apiKey,
        model: settings.model,
        telemetrySummary: widget.telemetrySummary,
        history: _messages.sublist(0, _messages.length - 1),
        question: sanitized,
      );
      if (!mounted) return;
      setState(() => _messages.add(AiTurn(role: 'assistant', text: reply)));
    } on AiChatException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.state,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSurfaces.page,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Ask the assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear conversation',
            // Disabled rather than hidden while a reply is in flight: clearing
            // the transcript mid-request would let the reply arrive into an
            // empty history and then contradict it.
            onPressed: _sending || _messages.isEmpty
                ? null
                : () => setState(_messages.clear),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(child: _transcript()),
                  _error == null
                      ? const SizedBox.shrink()
                      : _errorBanner(_error!),
                  _composer(),
                ],
              ),
      ),
    );
  }

  Widget _transcript() {
    final settings = _settings;
    if (settings == null || !settings.isConfigured) {
      return _unconfigured();
    }
    if (_messages.isEmpty) return _intro();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Thinking...'),
              ],
            ),
          );
        }
        return _Bubble(turn: _messages[index]);
      },
    );
  }

  /// The empty state, and the only place the key is asked for.
  Widget _unconfigured() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key_off_outlined,
              size: 40,
              color: AppSurfaces.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No API key yet',
              style: AppType.headlineMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The assistant uses your own key, for your own provider. The app '
              'ships none, and nothing is sent anywhere until you ask '
              'something.',
              style: AppType.bodySm.copyWith(
                color: AppSurfaces.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: widget.openSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: const Text('Open settings'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                textStyle: AppType.buttonLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Ask about the readings below', style: AppType.labelUppercase),
        const SizedBox(height: AppSpacing.sm),
        // The summary is on screen, not just in the prompt. The user is being
        // told exactly what the model can see, which is the honest way to answer
        // "what are you sending?".
        AppCard(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              widget.telemetrySummary,
              style: AppType.bodySm.copyWith(
                fontFamily: AppType.mono,
                color: AppSurfaces.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                label: Text(suggestion),
                onPressed: _sending ? null : () => _askSuggestion(suggestion),
              ),
          ],
        ),
      ],
    );
  }

  void _askSuggestion(String question) {
    _input.text = question;
    _send();
  }

  static const _suggestions = [
    'How much power is the panel making right now?',
    'What is the battery doing?',
    'Is anything outside its alert limits?',
    'How much energy has been produced today?',
  ];

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      color: AppSurfaces.surfaceAlt,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: AppSurfaces.onSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppType.bodySm),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    final configured = _settings?.isConfigured ?? false;
    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.surface,
        border: Border(top: AppBorders.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: configured && !_sending,
              minLines: 1,
              maxLines: 4,
              maxLength: kMaxQuestionChars,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintText: configured
                    ? 'Ask about the readings...'
                    : 'Add an API key in Settings first',
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filled(
            icon: const Icon(Icons.send, size: 20),
            tooltip: 'Send',
            onPressed: configured && !_sending ? _send : null,
          ),
        ],
      ),
    );
  }
}

/// One message. The user's turns are tinted with the accent; the model's are a
/// plain card.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isUser
              ? AppSurfaces.surfaceAlt
              : AppSurfaces.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: AppBorders.hairlineBorder,
        ),
        child: Text(turn.text, style: AppType.bodyMd),
      ),
    );
  }
}