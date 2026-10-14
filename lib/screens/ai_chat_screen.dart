import 'package:flutter/material.dart';

import '../services/ai_chat_service.dart';
import '../services/ai_settings.dart';
import '../utils/ai_provider.dart';
import '../widgets/formatted_markdown_text.dart';
import '../widgets/liquid_glass.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/design_tokens.dart';

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

  /// Pushes the assistant's settings, awaited so the key can be re-read on the
  /// way back. Optional so a test can skip the navigation.
  final Future<void> Function()? openSettings;

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
  
  // For streaming: index of the assistant message being streamed
  int? _streamingIndex;
  String? _lastUserQuestion;

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
    // Clean up any partial streaming message so it doesn't persist
    // if the user navigates away mid-stream
    if (_streamingIndex != null && _streamingIndex! < _messages.length) {
      final msg = _messages[_streamingIndex!];
      if (msg.text.trim().isEmpty) {
        _messages.removeAt(_streamingIndex!);
      }
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final settings = _settings;
    final question = _input.text;
    if (settings == null || !settings.isConfigured || _sending) return;
    final sanitized = sanitizeQuestion(question);
    if (sanitized.isEmpty) return;

    _lastUserQuestion = sanitized;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AiTurn(role: 'user', text: sanitized));
      // Add empty assistant message for streaming
      _messages.add(AiTurn(role: 'assistant', text: ''));
      _streamingIndex = _messages.length - 1;
      _input.clear();
    });
    _scrollToEnd();

    try {
      await _askStreaming(settings: settings, question: sanitized);

      // Streaming complete
      if (!mounted) return;
      setState(() => _streamingIndex = null);
    } on AiChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        // Remove the empty assistant message on error
        if (_streamingIndex != null && _streamingIndex! < _messages.length) {
          _messages.removeAt(_streamingIndex!);
        }
        _streamingIndex = null;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _retryLastQuestion() async {
    final settings = _settings;
    final question = _lastUserQuestion;
    if (settings == null || !settings.isConfigured || _sending || question == null) return;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AiTurn(role: 'user', text: question));
      _messages.add(AiTurn(role: 'assistant', text: ''));
      _streamingIndex = _messages.length - 1;
    });
    _scrollToEnd();

    try {
      await _askStreaming(settings: settings, question: question);

      if (!mounted) return;
      setState(() => _streamingIndex = null);
    } on AiChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        if (_streamingIndex != null && _streamingIndex! < _messages.length) {
          _messages.removeAt(_streamingIndex!);
        }
        _streamingIndex = null;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  /// Streams one reply into the pending assistant turn, and falls back to a
  /// single non-streaming call when the stream delivers nothing.
  ///
  /// **The fallback exists because a provider is free to ignore `stream: true`
  /// and answer with one JSON body.** The SSE parser reads no events from that,
  /// so the `await for` completes with zero chunks — a silent empty bubble, which
  /// is the "the assistant does not answer" report. One non-streaming call is
  /// cheap and turns that case into a reply.
  ///
  /// Throws [AiChatException] when neither path yields text, so the caller
  /// surfaces the reason rather than an empty bubble. Both call sites (`_send`
  /// and `_retryLastQuestion`) must have appended `user` + an empty `assistant`
  /// turn before calling this — the history slice below assumes it.
  Future<void> _askStreaming({
    required AiSettings settings,
    required String question,
  }) async {
    var receivedAnyChunk = false;
    final stream = _service.askStream(
      preset: settings.preset,
      apiKey: settings.apiKey,
      model: settings.model,
      telemetrySummary: widget.telemetrySummary,
      history: _messages.sublist(0, _messages.length - 2),
      question: question,
    );

    await for (final chunk in stream) {
      receivedAnyChunk = true;
      if (!mounted) return;
      setState(() {
        if (_streamingIndex != null && _streamingIndex! < _messages.length) {
          final current = _messages[_streamingIndex!];
          _messages[_streamingIndex!] = AiTurn(
            role: current.role,
            text: current.text + chunk,
          );
        }
      });
      _scrollToEnd();
    }
    if (receivedAnyChunk) return;

    if (!mounted) return;
    final reply = await _service.ask(
      preset: settings.preset,
      apiKey: settings.apiKey,
      model: settings.model,
      telemetrySummary: widget.telemetrySummary,
      history: _messages.sublist(0, _messages.length - 2),
      question: question,
    );
    if (reply.isEmpty) {
      throw const AiChatException('The model returned an empty reply.');
    }
    if (!mounted) return;
    setState(() {
      if (_streamingIndex != null && _streamingIndex! < _messages.length) {
        _messages[_streamingIndex!] = AiTurn(role: 'assistant', text: reply);
      }
    });
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
      itemCount: _messages.length + (_sending && _streamingIndex == null ? 1 : 0),
      itemBuilder: (context, index) {
        // Only show "Thinking..." indicator when NOT streaming (i.e., waiting for full response)
        // When streaming, the partial response is already in the bubble
        if (index == _messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppPalette.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.error.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppPalette.error,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppSurfaces.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: AppBorders.hairlineBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Analyzing telemetry...',
                        style: AppType.bodySm.copyWith(color: faintColor),
                      ),
                    ],
                  ),
                ),
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
              onPressed: _openSettings,
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

  /// Pushes Settings and **re-reads the key on the way back**.
  ///
  /// Without the re-read this screen keeps the `_settings` it loaded in
  /// `initState`, and the user who taps "Open settings", pastes a key and comes
  /// straight back lands on the same "No API key yet" screen they left — which
  /// reads as the save having failed when nothing did.
  Future<void> _openSettings() async {
    final open = widget.openSettings;
    if (open == null) return;
    await open();
    if (!mounted) return;
    await _load();
  }

  Widget _intro() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppPalette.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 16,
                color: AppPalette.error,
              ),
            ),
            const SizedBox(width: 8),
            Text('Current Telemetry Snapshot', style: AppType.labelUppercase),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.md),
        Text('SUGGESTED QUESTIONS', style: AppType.labelMicro.copyWith(color: faintColor)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                avatar: Icon(Icons.bolt, size: 14, color: AppPalette.error),
                backgroundColor: AppSurfaces.surface,
                side: AppBorders.hairline,
                label: Text(suggestion, style: AppType.bodySm),
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
          TextButton(
            onPressed: _sending ? null : _retryLastQuestion,
            child: const Text('Retry'),
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

/// One message bubble with distinct user vs assistant styling,
/// markdown formatting, and avatar icons.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                color: AppPalette.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppPalette.error.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppPalette.error,
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppSurfaces.surfaceAlt
                    : AppSurfaces.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.card),
                  topRight: const Radius.circular(AppRadius.card),
                  bottomLeft: Radius.circular(isUser ? AppRadius.card : 2),
                  bottomRight: Radius.circular(isUser ? 2 : AppRadius.card),
                ),
                border: isUser
                    ? Border.all(color: AppPalette.error.withValues(alpha: 0.25), width: 1)
                    : AppBorders.hairlineBorder,
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: FormattedMarkdownText(
                text: turn.text,
                isUser: isUser,
                baseStyle: AppType.bodyMd.copyWith(
                  height: 1.45,
                  color: isUser ? AppSurfaces.onSurface : null,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 2),
              decoration: BoxDecoration(
                color: AppSurfaces.surfaceAlt,
                shape: BoxShape.circle,
                border: AppBorders.hairlineBorder,
              ),
              child: Icon(
                Icons.person_outline,
                size: 18,
                color: AppSurfaces.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}