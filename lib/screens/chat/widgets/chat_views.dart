import 'package:flutter/material.dart';

import '../../../utils/ai_provider.dart';
import '../../../widgets/formatted_markdown_text.dart';
import '../../../widgets/liquid_glass.dart';
import '../../dashboard/utils/design_tokens.dart';

/// The transcript, in one place so the state class holds behaviour only.
///
/// Extracted because the four views below are pure functions of data plus
/// callbacks: they read no controller, no stream and no service. Keeping them on
/// `_AiChatScreenState` made 300 lines of layout sit between `_send` and
/// `_askStreaming`, which are the two methods a reader comes here for.
class ChatTranscript extends StatelessWidget {
  const ChatTranscript({
    super.key,
    required this.messages,
    required this.sentAt,
    required this.scroll,
    required this.configured,
    required this.sending,
    required this.streamingIndex,
    required this.telemetrySummary,
    required this.onSuggestion,
    required this.onOpenSettings,
  });

  final List<AiTurn> messages;
  final List<DateTime> sentAt;
  final ScrollController scroll;
  final bool configured;
  final bool sending;
  final int? streamingIndex;
  final String Function() telemetrySummary;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (!configured) {
      return ChatUnconfigured(onOpenSettings: onOpenSettings);
    }
    if (messages.isEmpty) {
      return ChatIntro(
        telemetrySummary: telemetrySummary,
        sending: sending,
        onSuggestion: onSuggestion,
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // Only show "Thinking..." when NOT streaming: a streaming reply is
      // already in its bubble, so a second indicator would claim two requests.
      itemCount: messages.length + (sending && streamingIndex == null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return const ChatThinkingRow();
        return ChatBubble(
          turn: messages[index],
          sentAt: index < sentAt.length ? sentAt[index] : null,
        );
      },
    );
  }
}

/// An assistant turn waiting for its first chunk.
///
/// Plain page ink, no card: this wears the same shape an assistant turn has once
/// the text arrives, so the transcript does not change structure when it fills.
class ChatThinkingRow extends StatelessWidget {
  const ChatThinkingRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const AssistantOrb(size: 36),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Reading the telemetry...',
            style: AppType.bodySm.copyWith(color: AppGlass.pageInkSoft),
          ),
        ],
      ),
    );
  }
}

/// The empty state, and the only place the key is asked for.
class ChatUnconfigured extends StatelessWidget {
  const ChatUnconfigured({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
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
              onPressed: onOpenSettings,
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
}

/// The suggested-questions state, above a collapsed telemetry snapshot.
class ChatIntro extends StatelessWidget {
  const ChatIntro({
    super.key,
    required this.telemetrySummary,
    required this.sending,
    required this.onSuggestion,
  });

  static const suggestions = [
    'How much power is the panel making right now?',
    'What is the battery doing?',
    'Is anything outside its alert limits?',
    'How much energy has been produced today?',
  ];

  final String Function() telemetrySummary;
  final bool sending;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        SnapshotPanel(build: telemetrySummary),
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
            for (final suggestion in suggestions)
              ActionChip(
                avatar: Icon(Icons.bolt, size: 14, color: AppPalette.accent),
                backgroundColor: AppSurfaces.surface,
                side: AppBorders.hairline,
                label: Text(
                  suggestion,
                  style: AppType.bodySm.copyWith(color: AppSurfaces.onSurface),
                ),
                onPressed: sending ? null : () => onSuggestion(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}

/// One line saying what went wrong, with retry and dismiss.
class ChatErrorBanner extends StatelessWidget {
  const ChatErrorBanner({
    super.key,
    required this.message,
    required this.retryEnabled,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final bool retryEnabled;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
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
            onPressed: retryEnabled ? onRetry : null,
            child: const Text('Retry'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The rounded pill at the bottom, with the send button on its right.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.input,
    required this.configured,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController input;
  final bool configured;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
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
                controller: input,
                enabled: configured && !sending,
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
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // The send button lights up when there is something to send, and a
            // button that stays live on an empty field makes the disabled state
            // look broken rather than deliberate. Listening to the controller
            // rather than to `onChanged: setState` keeps a keystroke off the
            // transcript, which is the expensive part of this screen.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: input,
              builder: (context, value, _) => SendButton(
                onPressed: configured && !sending && value.text.trim().isNotEmpty
                    ? onSend
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
/// Hand-rolled rather than `intl`'s `DateFormat.jm()`: one format, no dependency.
String timeLabel(DateTime at) {
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
class SnapshotPanel extends StatefulWidget {
  const SnapshotPanel({super.key, required this.build});

  final String Function() build;

  @override
  State<SnapshotPanel> createState() => _SnapshotPanelState();
}

class _SnapshotPanelState extends State<SnapshotPanel> {
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
          // reads the snapshot once: two `telemetrySummary()` calls could
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
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.turn, this.sentAt});

  final AiTurn turn;

  /// Null only if the message and timestamp lists ever drift, which writing
  /// every turn through one helper is what prevents.
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
              const AssistantOrb(),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel(sentAt ?? DateTime.now()),
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
class AssistantOrb extends StatelessWidget {
  const AssistantOrb({super.key, this.size = 36});

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
class SendButton extends StatelessWidget {
  const SendButton({super.key, required this.onPressed});

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
