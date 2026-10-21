import 'package:flutter/material.dart';

import '../services/ai_chat_service.dart';
import '../services/ai_settings.dart';
import '../utils/ai_provider.dart';
import '../widgets/formatted_markdown_text.dart';
import '../widgets/liquid_glass.dart';
import 'dashboard/utils/design_tokens.dart';
import 'dashboard/widgets/glass_hero_card.dart';

/// Ask the model a question about the current telemetry.
///
/// **The telemetry summary is passed in, not read.** The dashboard owns the live
/// values and rebuilds on its own poll; reaching into it from here would make a
/// chat screen depend on a screen's private state, which is the one thing the
/// layering in this app is for. It arrives as a callback and is called once per
/// question, so the answer describes the readings at the moment of asking rather
/// than at the moment the screen opened.
///
/// **Nothing is persisted.** The transcript lives in this [State] and dies with
/// the screen, so closing the assistant leaves no conversation on the device.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.telemetrySummary,
    this.openSettings,
  });

  /// Rebuilt for every question, so the assistant answers from the current
  /// readings rather than from whatever they were when the screen opened.
  /// See [buildTelemetrySummary].
  final String Function() telemetrySummary;

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

  /// The wall clock each turn was sent, parallel to [_messages].
  ///
  /// **A parallel list rather than a field on [AiTurn], because `AiTurn` is the
  /// wire format.** A timestamp the model never asked for is a field that then has
  /// to stay out of the request body and out of thirty-odd tests, for no benefit.
  /// Here it is one local list, and both lists are only written through
  /// [_addTurn] and [_removeStreaming] — which is the only reason they stay the
  /// same length.
  final _sentAt = <DateTime>[];

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
    final pending = _streamingIndex;
    if (pending != null && pending < _messages.length) {
      if (_messages[pending].text.trim().isEmpty) {
        _removeStreaming();
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
      _addTurn('user', sanitized);
      // Add empty assistant message for streaming
      _addTurn('assistant', '');
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
        _removeStreaming();
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
    if (settings == null ||
        !settings.isConfigured ||
        _sending ||
        question == null) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _addTurn('user', question);
      _addTurn('assistant', '');
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
        _removeStreaming();
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
    // One snapshot per question, taken here rather than in `initState`: the
    // stream and its non-streaming fallback are one request and must see the
    // same readings.
    final telemetrySummary = widget.telemetrySummary();
    var receivedAnyChunk = false;
    final stream = _service.askStream(
      preset: settings.preset,
      apiKey: settings.apiKey,
      model: settings.model,
      telemetrySummary: telemetrySummary,
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
      telemetrySummary: telemetrySummary,
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

  /// Appends one turn and stamps it. The only writer of [_messages].
  void _addTurn(String role, String text) {
    _messages.add(AiTurn(role: role, text: text));
    _sentAt.add(DateTime.now());
  }

  /// Drops the assistant turn that was being streamed, if it is still there.
  void _removeStreaming() {
    final index = _streamingIndex;
    if (index == null || index >= _messages.length) return;
    _messages.removeAt(index);
    if (index < _sentAt.length) _sentAt.removeAt(index);
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
      // The flat page colour rather than `AppBackground`'s sweep: this screen is
      // a list of white bubbles and nothing else, and the gradient behind them
      // buys nothing. What it *does* need is for the few lines that are drawn
      // **on** this colour — the app bar title, the unconfigured state, the
      // intro headings — to use page ink rather than card ink. Card ink is navy
      // in both ramps since the cards went near-white, and that measured
      // **2.10:1** on the dark ramp's page value and is the reason the app bar
      // title could not be read at all in dark mode.
      backgroundColor: AppSurfaces.page,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppGlass.pageInkStrong,
        // The reference centres a plain title and hangs one round action on each
        // side of it, so the default back arrow is replaced rather than kept
        // alongside a second affordance for the same thing.
        automaticallyImplyLeading: false,
        centerTitle: true,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Center(
            child: GlassCircleButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              fill: AppSurfaces.surface,
              ink: AppSurfaces.onSurface,
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
        title: Text(
          'Ask the assistant',
          style: AppType.headlineMd.copyWith(color: AppGlass.pageInkStrong),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: GlassCircleButton(
                icon: Icons.delete_outline,
                tooltip: 'Clear conversation',
                fill: AppSurfaces.surface,
                ink: AppSurfaces.onSurface,
                // Disabled rather than hidden while a reply is in flight: clearing
                // the transcript mid-request would let the reply arrive into an
                // empty history and then contradict it.
                onPressed: _sending || _messages.isEmpty
                    ? null
                    : () => setState(() {
                        _messages.clear();
                        _sentAt.clear();
                      }),
              ),
            ),
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
      itemCount:
          _messages.length + (_sending && _streamingIndex == null ? 1 : 0),
      itemBuilder: (context, index) {
        // Only show "Thinking..." indicator when NOT streaming (i.e., waiting for full response)
        // When streaming, the partial response is already in the bubble
        if (index == _messages.length) {
          // Plain page ink, no card: this is an assistant turn waiting for its
          // text, so it wears the same shape an assistant turn has once the text
          // arrives. A spinner inside a card reads as a different thing.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const _AssistantOrb(size: 36),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Reading the telemetry...',
                  style: AppType.bodySm.copyWith(color: AppGlass.pageInkSoft),
                ),
              ],
            ),
          );
        }
        return _Bubble(
          turn: _messages[index],
          sentAt: index < _sentAt.length ? _sentAt[index] : null,
        );
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
            Icon(Icons.key_off_outlined, size: 40, color: AppGlass.pageInkSoft),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No API key yet',
              style: AppType.headlineMd.copyWith(color: AppGlass.pageInkStrong),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The assistant uses your own key, for your own provider. The app '
              'ships none, and nothing is sent anywhere until you ask '
              'something.',
              style: AppType.bodySm.copyWith(color: AppGlass.pageInkSoft),
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
        _SnapshotPanel(build: widget.telemetrySummary),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'SUGGESTED QUESTIONS',
          style: AppType.labelMicro.copyWith(color: AppGlass.pageInkSoft),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                avatar: Icon(Icons.bolt, size: 14, color: AppPalette.accent),
                backgroundColor: AppSurfaces.surface,
                side: AppBorders.hairline,
                label: Text(
                  suggestion,
                  style: AppType.bodySm.copyWith(color: AppSurfaces.onSurface),
                ),
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
          Expanded(child: Text(message, style: AppType.bodySm)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppSurfaces.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: configured && !_sending,
                minLines: 1,
                maxLines: 4,
                maxLength: kMaxQuestionChars,
                textCapitalization: TextCapitalization.sentences,
                style: AppType.bodyMd.copyWith(color: AppSurfaces.onSurface),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: configured
                      ? 'Message'
                      : 'Add an API key in Settings first',
                  hintStyle: AppType.bodyMd.copyWith(
                    color: AppSurfaces.onSurfaceVariant,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // The send button lights up when there is something to send, and a
            // button that stays live on an empty field makes the disabled state
            // look broken rather than deliberate. Listening to the controller
            // rather than to `onChanged: setState` keeps a keystroke off the
            // transcript, which is the expensive part of this screen.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _input,
              builder: (context, value, _) => _SendButton(
                onPressed:
                    configured && !_sending && value.text.trim().isNotEmpty
                    ? _send
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `11:28 am` — a 12-hour clock, which is what the reference prints.
///
/// Top-level because [_Bubble] needs it and the state class does not, and a
/// static private on the state would be a worse answer than a plain function.
/// Hand-rolled rather than `intl`'s `DateFormat.jm()`: one format, no dependency.
String _timeLabel(DateTime at) {
  final hour24 = at.hour;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${hour24 < 12 ? 'am' : 'pm'}';
}

/// What the assistant can see, collapsed until it is asked for.
///
/// **Collapsed by default, and that is a device observation rather than a
/// preference.** Once every telemetry key started carrying its unit the block
/// grew past a full screen on this phone: the suggested questions — the one part
/// of this screen a user can act on in one tap — ended up below the fold, with
/// nothing on screen to scroll towards. The disclosure is still worth having; it
/// just cannot be the first thing shown at full size.
class _SnapshotPanel extends StatefulWidget {
  const _SnapshotPanel({required this.build});

  final String Function() build;

  @override
  State<_SnapshotPanel> createState() => _SnapshotPanelState();
}

class _SnapshotPanelState extends State<_SnapshotPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One tap target for the whole header row, so the row does not have to be
        // a row of separately-pressable pieces.
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.button),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppPalette.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      size: 16,
                      color: AppPalette.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'CURRENT TELEMETRY',
                      style: AppType.labelUppercase.copyWith(
                        color: AppGlass.pageInkStrong,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: AppMotion.state,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: AppGlass.pageInkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: AppSpacing.xs),
          // Called here and not in the parent, so the text and nothing else
          // reads the snapshot once: two `widget.telemetrySummary()` calls could
          // straddle a poll and describe two different instants.
          AppCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                widget.build(),
                style: AppType.code.copyWith(
                  color: AppSurfaces.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Taken fresh for each question, so answers use the readings as they '
            'are when you ask.',
            style: AppType.bodySm.copyWith(color: AppGlass.pageInkSoft),
          ),
        ],
      ],
    );
  }
}

/// One turn of the transcript.
///
/// **The two roles are drawn differently, and the difference is the reference's:
/// the user gets a white pill and the assistant gets no pill at all.** A reply
/// drawn as a card reads as an object; a reply sitting on the page under its own
/// label reads as prose. That also retires the 78%-width cap the user bubble
/// needed — it existed to stop a bubble running the full width, and the reply is
/// no longer one.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn, this.sentAt});

  final AiTurn turn;

  /// Null only if [_messages] and [_sentAt] ever drift, which writing every turn
  /// through one helper is what prevents.
  final DateTime? sentAt;

  @override
  Widget build(BuildContext context) =>
      turn.role == 'user' ? _userTurn(context) : _assistantTurn();

  Widget _userTurn(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppSurfaces.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.subtle,
          ),
          child: FormattedMarkdownText(
            text: turn.text,
            isUser: true,
            baseStyle: AppType.bodyMd.copyWith(
              height: 1.45,
              color: AppSurfaces.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _assistantTurn() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AssistantOrb(),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeLabel(sentAt ?? DateTime.now()),
                    style: AppType.labelMicro.copyWith(
                      color: AppGlass.pageInkSoft,
                    ),
                  ),
                  Text(
                    'AI Assistant',
                    style: AppType.strong.copyWith(
                      color: AppGlass.pageInkStrong,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FormattedMarkdownText(
            text: turn.text,
            isUser: false,
            baseStyle: AppType.bodyMd.copyWith(
              height: 1.5,
              color: AppGlass.pageInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// The assistant's avatar: the app's own hero gradient in a circle.
///
/// **Navy rather than the reference's pink-orange sphere.** That orb is a mascot;
/// this is a solar monitor. The hero is already the strongest colour in the app,
/// so reusing it keeps one identity colour instead of adding a second — and it
/// replaces a red-tinted circle, which was a status colour used as decoration.
class _AssistantOrb extends StatelessWidget {
  const _AssistantOrb({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: AppGlass.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.auto_awesome, size: size * 0.42, color: Colors.white),
    );
  }
}

/// The composer's send button: the reference's solid accent circle.
///
/// An arrow rather than the reference's microphone, because the app has no speech
/// input — a mic that records nothing is worse than an arrow.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: 'Send',
      child: SizedBox.square(
        dimension: 44,
        child: Material(
          // Required for the same reason it is in `GlassCircleButton`: the
          // decorated Container below paints over any ink layer above it.
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: enabled
                    ? const LinearGradient(
                        colors: AppGlass.heroGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: enabled ? null : AppSurfaces.surfaceMuted,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: enabled ? Colors.white : AppSurfaces.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
