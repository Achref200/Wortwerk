import 'dart:async';

import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_session_bloc.dart';
import '../../auth/application/auth_session_event.dart';
import '../../auth/domain/auth_account.dart';
import '../../auth/domain/auth_session_state.dart';
import '../../../design_system/components.dart';
import '../../../design_system/fritz_avatar.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../../../core/animations/animated_counter.dart';
import '../../../core/animations/confetti_burst.dart';
import '../../../core/animations/flame_controller.dart';
import '../../../core/animations/fritz_controller.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/l10n/wortwerk_strings.dart';
import '../../../features/notifications/application/push_notifications_controller.dart';
import '../../../features/fritz/application/fritz_tutor_controller.dart';
import '../../../features/fritz/application/speech_practice_service.dart';
import '../../../features/fritz/domain/fritz_message.dart';
import '../../streak/domain/learning_streak_summary.dart';
import '../../settings/application/learner_preferences_controller.dart';
import '../../settings/domain/learner_preferences.dart';
import '../../settings/domain/learner_preferences_repository.dart';

final class SecondaryPageScaffold extends StatelessWidget {
  const SecondaryPageScaffold({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScreenContent(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Zurück',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: LocalizedText(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (title == 'Fritz übt mit dir') const FritzAvatar(size: 48),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: LocalizedText(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
  }
}

final class StreakPage extends StatefulWidget {
  const StreakPage({required this.repository, super.key});

  final LearningStreakRepository repository;

  @override
  State<StreakPage> createState() => _StreakPageState();
}

final class _StreakPageState extends State<StreakPage> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      title: 'Dein Lernrhythmus',
      subtitle: 'Dranbleiben, ohne Druck.',
      children: [
        StreamBuilder<LearningStreakSummary>(
          key: ValueKey(_reload),
          stream: widget.repository.watchSummary(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StreakErrorCard(onRetry: () => setState(() => _reload++));
            }
            if (!snapshot.hasData) {
              return FlatCard(
                child: Semantics(
                  liveRegion: true,
                  label: 'Dein Lernrhythmus wird geladen',
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              );
            }

            final summary = snapshot.data!;
            if (!summary.profileExists) {
              return _StreakErrorCard(
                message: 'Dein Lernprofil ist gerade nicht verfügbar.',
                onRetry: () => setState(() => _reload++),
              );
            }
            return _StreakOverview(summary: summary);
          },
        ),
      ],
    );
  }
}

final class _StreakErrorCard extends StatelessWidget {
  const _StreakErrorCard({
    required this.onRetry,
    this.message = 'Dein Lernrhythmus konnte gerade nicht geladen werden.',
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 34),
          const SizedBox(height: 10),
          LocalizedText(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const LocalizedText('Erneut versuchen'),
          ),
        ],
      ),
    );
  }
}

/// Drives the streak flame from the saved streak count (SPEC §5.2).
///
/// The flame lights when a streak exists and celebrates when the count grows
/// between stream emissions.
final class _StreakFlameBadge extends StatefulWidget {
  const _StreakFlameBadge({required this.current});

  final int current;

  @override
  State<_StreakFlameBadge> createState() => _StreakFlameBadgeState();
}

final class _StreakFlameBadgeState extends State<_StreakFlameBadge> {
  late final FlameController _controller = FlameController(
    lit: widget.current > 0,
  );
  late int _previous = widget.current;

  @override
  void didUpdateWidget(_StreakFlameBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current > _previous && widget.current > 0) {
      _controller.celebrate();
    } else {
      _controller.setLit(widget.current > 0);
    }
    _previous = widget.current;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedStreakFlame(controller: _controller, size: 60);
}

final class _StreakOverview extends StatelessWidget {
  const _StreakOverview({required this.summary});

  final LearningStreakSummary summary;

  @override
  Widget build(BuildContext context) {
    final activeDays = summary.activeDayIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow('DEIN RUHETAG · ${_weekdayNames[summary.restWeekday]}'),
        const SizedBox(height: 10),
        FlatCard(
          color: WortwerkColors.c2,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _StreakFlameBadge(current: summary.current),
                  const SizedBox(width: 8),
                  AnimatedCounter(
                    value: summary.current,
                    duration: const Duration(milliseconds: 850),
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LocalizedText(
                summary.current == 1 ? 'Lerntag in Folge' : 'Lerntage in Folge',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              LocalizedText(
                summary.current == 0
                    ? 'Dein erster Lerntag beginnt mit einer kurzen Einheit. '
                          'Ein Ruhetag ist jede Woche eingeplant.'
                    : 'Schön, dass du wieder da bist. Dein Rhythmus bleibt '
                          'dein eigener.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: WortwerkColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeading(title: 'Diese Woche'),
        const SizedBox(height: 10),
        _WeekStrip(summary: summary),
        const SizedBox(height: 8),
        LocalizedText(
          '$activeDays von 7 aktiven Tagen · längster Rhythmus: '
          '${summary.longest} · Schutztage: ${summary.shields}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: 'Ein kleiner Schritt für heute'),
        const SizedBox(height: 10),
        _MissionRow(
          icon: Icons.menu_book_rounded,
          title: 'Eine Lektion beginnen',
          subtitle: '5 kurze Fragen · A1',
          color: WortwerkColors.a1,
          onPressed: () => context.push('/lesson/a1_greetings'),
        ),
        const SizedBox(height: 10),
        _MissionRow(
          icon: Icons.style_outlined,
          title: 'Ein Wort wiederholen',
          subtitle: 'Karteikarten',
          color: WortwerkColors.a2,
          onPressed: () => context.push('/flashcards'),
        ),
        const SizedBox(height: 10),
        _MissionRow(
          icon: Icons.forum_outlined,
          title: 'Einen Satz mit Fritz üben',
          subtitle: 'Gesprächsvorschau',
          color: WortwerkColors.b1,
          onPressed: () => context.push('/tutor'),
        ),
        const SizedBox(height: 18),
        const FlatCard(
          child: LocalizedText(
            'Ein Ruhetag pro Woche unterbricht deinen Lernrhythmus nicht. '
            'Ein verpasster Tag ist kein Grund, dich schlecht zu fühlen.',
          ),
        ),
      ],
    );
  }
}

const _weekdayNames = [
  'Sonntag',
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
];

final class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.summary});

  final LearningStreakSummary summary;

  static const _labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final monday = DateTime.utc(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
    );
    return FlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var index = 0; index < _labels.length; index++)
            _WeekdayMarker(
              label: _labels[index],
              date: monday.add(Duration(days: index)),
              summary: summary,
            ),
        ],
      ),
    );
  }
}

final class _WeekdayMarker extends StatelessWidget {
  const _WeekdayMarker({
    required this.label,
    required this.date,
    required this.summary,
  });

  final String label;
  final DateTime date;
  final LearningStreakSummary summary;

  @override
  Widget build(BuildContext context) {
    final dayId = _formatDayId(date);
    final isToday = dayId == _formatDayId(DateTime.now().toUtc());
    final isRestDay = date.weekday % 7 == summary.restWeekday;
    final isActive = summary.activeDayIds.contains(dayId);
    final color = isActive
        ? WortwerkColors.success
        : isRestDay
        ? WortwerkColors.c2
        : WortwerkColors.paper;
    final icon = isActive
        ? Icons.check_rounded
        : isRestDay
        ? Icons.spa_outlined
        : Icons.circle_outlined;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '$label${isToday ? ', heute' : ''}'
          '${isActive
              ? ', Lerntag'
              : isRestDay
              ? ', Ruhetag'
              : ', kein Lerntag'}',
      child: Column(
        children: [
          AnimatedContainer(
            duration: _motionDuration(context, 280),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isToday ? WortwerkColors.ink : WortwerkColors.line,
                width: isToday ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: WortwerkColors.ink),
          ),
          const SizedBox(height: 6),
          LocalizedText(label, style: Theme.of(context).textTheme.labelSmall),
          if (isToday)
            LocalizedText(
              'Heute',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: WortwerkColors.streak, fontSize: 9),
            ),
        ],
      ),
    );
  }
}

Duration _motionDuration(BuildContext context, int milliseconds) =>
    MediaQuery.of(context).disableAnimations
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

String _formatDayId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

final class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFEFC),
      borderRadius: BorderRadius.circular(WortwerkRadii.card),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(WortwerkRadii.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WortwerkRadii.card),
            border: Border.all(color: WortwerkColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    LocalizedText(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

final class FritzTutorPage extends StatefulWidget {
  const FritzTutorPage({
    required this.repository,
    required this.speechPracticeService,
    required this.preferencesRepository,
    super.key,
    this.initialPrompt = '',
    this.initialMode = 'chat',
    this.threadId = 'main',
  });

  final FritzChatRepository repository;
  final SpeechPracticeService speechPracticeService;
  final LearnerPreferencesRepository preferencesRepository;
  final String initialPrompt;
  final String initialMode;
  final String threadId;

  @override
  State<FritzTutorPage> createState() => _FritzTutorPageState();
}

final class _FritzTutorPageState extends State<FritzTutorPage> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final FritzTutorController _tutor;
  late final SpeechPracticeService _speech;
  SpeechCaptureState _speechState = SpeechCaptureState.idle;
  bool _speechOutputEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPrompt);
    _scrollController = ScrollController();
    _speech = widget.speechPracticeService;
    _tutor = FritzTutorController(
      repository: widget.repository,
      threadId: widget.threadId,
    )..addListener(_onTutorChanged);
    _loadSpeechPreference();
  }

  Future<void> _loadSpeechPreference() async {
    try {
      final preferences = await widget.preferencesRepository.load();
      if (mounted) {
        setState(() => _speechOutputEnabled = preferences.speechOutput);
      }
    } catch (_) {
      if (mounted) setState(() => _speechOutputEnabled = false);
    }
  }

  void _onTutorChanged() {
    _scrollToLatest();
    if (mounted) setState(() {});
  }

  void _scrollToLatest() {
    if (!mounted || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    if (_tutor.isSending || _tutor.sendFailure != null) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    if (_speechState == SpeechCaptureState.listening) {
      await _speech.stopListening();
      _setSpeechState(SpeechCaptureState.idle);
    }
    setState(() {});
    await _tutor.send(text, mode: widget.initialMode);
    if (!mounted || _tutor.sendFailure != null) return;
    _controller.clear();
    setState(() {});
  }

  void _setSpeechState(SpeechCaptureState state) {
    if (mounted) setState(() => _speechState = state);
  }

  Future<void> _toggleDictation() async {
    if (_speechState == SpeechCaptureState.listening) {
      await _speech.stopListening();
      _setSpeechState(SpeechCaptureState.idle);
      return;
    }
    _setSpeechState(SpeechCaptureState.listening);
    final started = await _speech.startListening(
      onText: (text) {
        if (!mounted || text.isEmpty) return;
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        setState(() {});
      },
      onState: _setSpeechState,
    );
    if (!started && _speechState == SpeechCaptureState.listening) {
      _setSpeechState(SpeechCaptureState.failed);
    }
  }

  Future<void> _speakReply(String text) async {
    try {
      await _speech.speakGerman(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            WortwerkLocalizations.of(context)(WText.fritzSpeechError),
          ),
        ),
      );
    }
  }

  Future<void> _retrySend() async {
    final failedText = _tutor.retryText;
    await _tutor.retrySend();
    if (!mounted || _tutor.sendFailure != null || failedText == null) return;
    if (_controller.text.trim() == failedText) _controller.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _tutor.removeListener(_onTutorChanged);
    _tutor
      ..removeListener(_scrollToLatest)
      ..dispose();
    _scrollController.dispose();
    _controller.dispose();
    unawaited(_speech.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      title: 'Fritz übt mit dir',
      subtitle: 'Auf Deutsch, Schritt für Schritt.',
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.goNamed(
              'tutor',
              queryParameters: {
                'thread':
                    'chat_${DateTime.now().toUtc().microsecondsSinceEpoch}',
              },
            ),
            icon: const Icon(Icons.add_comment_outlined),
            label: const LocalizedText('Neues Gespr\u00e4ch'),
          ),
        ),
        FlatCard(
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20),
              SizedBox(width: 9),
              Expanded(
                child: LocalizedText(
                  'Fritz ist ein KI-Lernassistent. Teile keine Passwörter oder '
                  'vertraulichen Daten.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 360,
          child: ListenableBuilder(
            listenable: _tutor,
            builder: (context, _) {
              if (_tutor.isLoading && !_tutor.hasMessages) {
                return const WLoadingState(message: 'Fritz wird bereit …');
              }
              final loadFailure = _tutor.loadFailure;
              if (loadFailure != null && !_tutor.hasMessages) {
                return WFailureState(
                  failure: loadFailure,
                  onRetry: _tutor.retryLoad,
                  title: 'Der Gesprächsverlauf ist nicht verfügbar.',
                );
              }
              if (loadFailure != null) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LocalizedText(
                      'Der gespeicherte Verlauf ist veraltet.',
                    ),
                    TextButton(
                      onPressed: _tutor.retryLoad,
                      child: const LocalizedText('Verlauf erneut laden'),
                    ),
                    Expanded(
                      child: _FritzConversationList(
                        controller: _tutor,
                        scrollController: _scrollController,
                        onSpeak: _speakReply,
                        speechOutputEnabled: _speechOutputEnabled,
                      ),
                    ),
                  ],
                );
              }
              if (!_tutor.hasMessages) {
                return const WEmptyState(
                  title: 'Womit möchtest du anfangen?',
                  message:
                      'Schreib einen Satz auf Deutsch. Fritz übt mit dir '
                      'auf deinem Niveau.',
                );
              }
              return _FritzConversationList(
                controller: _tutor,
                scrollController: _scrollController,
                onSpeak: _speakReply,
                speechOutputEnabled: _speechOutputEnabled,
              );
            },
          ),
        ),
        if (_tutor.sendFailure case final failure?) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Expanded(
                  child: LocalizedText(_fritzSendFailureMessage(failure.kind)),
                ),
                TextButton(
                  onPressed: _tutor.isSending ? null : _retrySend,
                  child: const LocalizedText('Erneut versuchen'),
                ),
                TextButton(
                  onPressed: _tutor.isSending ? null : _tutor.discardFailedSend,
                  child: const LocalizedText('Verwerfen'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _tutor.isSending ? null : _toggleDictation,
            icon: Icon(
              _speechState == SpeechCaptureState.listening
                  ? Icons.stop_rounded
                  : Icons.mic_none_rounded,
            ),
            label: Text(
              WortwerkLocalizations.of(context)(
                _speechState == SpeechCaptureState.listening
                    ? WText.fritzMicStop
                    : WText.fritzMicStart,
              ),
            ),
          ),
        ),
        if (_speechState != SpeechCaptureState.idle)
          Semantics(
            liveRegion: true,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                WortwerkLocalizations.of(context)(
                  _speechStateMessage(_speechState),
                ),
              ),
            ),
          ),
        Text(
          WortwerkLocalizations.of(context)(WText.fritzVoicePrivacy),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 4,
          maxLength: 1000,
          enabled: !_tutor.isSending,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            hintText: 'Schreib auf Deutsch …',
            filled: true,
            fillColor: const Color(0xFFFFFEFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: WortwerkColors.line),
            ),
            counterText: '',
            suffixIcon: IconButton(
              onPressed: _controller.text.trim().isEmpty || _tutor.isSending
                  ? null
                  : _send,
              tooltip: 'Senden',
              icon: _tutor.isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  String _fritzSendFailureMessage(AppFailureKind kind) => switch (kind) {
    AppFailureKind.network =>
      'Keine Verbindung. Deine Nachricht bleibt erhalten.',
    AppFailureKind.rateLimited =>
      'Fritz braucht eine kurze Pause. Versuche es später erneut.',
    AppFailureKind.contentMissing =>
      'Fritz ist noch nicht eingerichtet. Lernkarten kannst du weiter üben.',
    _ =>
      'Fritz konnte gerade nicht antworten. Deine Nachricht bleibt erhalten.',
  };

  WText _speechStateMessage(SpeechCaptureState state) => switch (state) {
    SpeechCaptureState.idle => WText.fritzMicStart,
    SpeechCaptureState.listening => WText.fritzMicListening,
    SpeechCaptureState.unavailable => WText.fritzMicUnavailable,
    SpeechCaptureState.permissionDenied => WText.fritzMicPermission,
    SpeechCaptureState.failed => WText.fritzMicError,
  };
}

final class _FritzMessageBubble extends StatelessWidget {
  const _FritzMessageBubble({
    required this.message,
    required this.onSpeak,
    required this.speechOutputEnabled,
  });

  final FritzMessage message;
  final VoidCallback onSpeak;
  final bool speechOutputEnabled;

  @override
  Widget build(BuildContext context) {
    final isLearner = message.role == FritzMessageRole.learner;
    final color = isLearner ? WortwerkColors.a1 : WortwerkColors.b1;
    return Align(
      alignment: isLearner ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WortwerkColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(message.text),
            if (!isLearner && speechOutputEnabled)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: WortwerkLocalizations.of(context)(
                    WText.fritzSpeakReply,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded, size: 19),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _FritzConversationList extends StatelessWidget {
  const _FritzConversationList({
    required this.controller,
    required this.scrollController,
    required this.onSpeak,
    required this.speechOutputEnabled,
  });

  final FritzTutorController controller;
  final ScrollController scrollController;
  final ValueChanged<String> onSpeak;
  final bool speechOutputEnabled;

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: scrollController,
    itemCount: controller.messages.length,
    itemBuilder: (context, index) => _FritzMessageBubble(
      message: controller.messages[index],
      onSpeak: () => onSpeak(controller.messages[index].text),
      speechOutputEnabled: speechOutputEnabled,
    ),
  );
}

final class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.localeController,
    required this.preferencesRepository,
    required this.pushNotifications,
    required this.authSession,
    super.key,
  });

  final LocaleController localeController;
  final LearnerPreferencesRepository preferencesRepository;
  final PushNotificationsController pushNotifications;
  final AuthSessionBloc authSession;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends State<SettingsPage> {
  late final LearnerPreferencesController _preferences;
  bool _savingLanguage = false;
  String? _languageError;

  @override
  void initState() {
    super.initState();
    _preferences = LearnerPreferencesController(
      repository: widget.preferencesRepository,
    )..load();
  }

  @override
  void dispose() {
    _preferences.dispose();
    super.dispose();
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    setState(() {
      _savingLanguage = true;
      _languageError = null;
    });
    try {
      await widget.localeController.setLanguage(language);
    } catch (_) {
      if (mounted) {
        setState(
          () => _languageError = 'Sprache konnte nicht gespeichert werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingLanguage = false);
    }
  }

  Future<void> _setPushEnabled(bool enabled) async {
    final service = widget.pushNotifications;
    if (enabled) {
      await service.enable(WortwerkLocalizations.of(context).language.code);
    } else {
      await service.disable();
    }
  }

  WText _pushProblemText(PushNotificationProblem problem) => switch (problem) {
    PushNotificationProblem.unavailable => WText.pushUnavailable,
    PushNotificationProblem.permissionDenied => WText.pushPermissionDenied,
    PushNotificationProblem.tokenUnavailable => WText.pushTokenUnavailable,
    PushNotificationProblem.serverError => WText.pushServerError,
  };

  String _preferenceFailure(AppFailureKind kind) => switch (kind) {
    AppFailureKind.network =>
      'Keine Verbindung. Einstellungen konnten nicht geladen werden.',
    AppFailureKind.permissionDenied =>
      'Diese Einstellungen sind fuer dein Konto nicht verfuegbar.',
    _ =>
      'Einstellungen konnten nicht gespeichert werden. Bitte erneut versuchen.',
  };

  Future<void> _chooseReminderTime(String value) async {
    final parts = value.split(':');
    final current = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final chosen = await showTimePicker(context: context, initialTime: current);
    if (chosen == null || !mounted) return;
    await _preferences.update(
      _preferences.state.preferences.copyWith(
        reminderTime:
            '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}',
      ),
    );
  }

  Widget _preferenceControls(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) {
      final state = _preferences.state;
      if (state.isLoading && !state.hasLoaded) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (state.failure != null && !state.hasLoaded) {
        return FlatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: LocalizedText(_preferenceFailure(state.failure!.kind)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.isLoading ? null : _preferences.load,
                icon: const Icon(Icons.refresh_rounded),
                label: const LocalizedText('Erneut versuchen'),
              ),
            ],
          ),
        );
      }
      final values = state.preferences;
      final disabled = state.isSaving;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isSaving) const LinearProgressIndicator(minHeight: 2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: const LocalizedText('Tagesziel'),
            trailing: DropdownButton<int>(
              value: values.dailyMinutes,
              onChanged: disabled
                  ? null
                  : (minutes) {
                      if (minutes == null) return;
                      _preferences.update(
                        values.copyWith(dailyMinutes: minutes),
                      );
                    },
              items: [
                for (final minutes in LearnerPreferences.dailyMinuteOptions)
                  DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes Minuten'),
                  ),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alarm_rounded),
            title: const LocalizedText('Erinnerung'),
            trailing: TextButton(
              onPressed: disabled
                  ? null
                  : () => _chooseReminderTime(values.reminderTime),
              child: Text(values.reminderTime),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.spa_outlined),
            title: const LocalizedText('Ruhetag pro Woche'),
            trailing: DropdownButton<int>(
              value: values.restWeekday,
              onChanged: disabled
                  ? null
                  : (weekday) {
                      if (weekday == null) return;
                      _preferences.update(
                        values.copyWith(restWeekday: weekday),
                      );
                    },
              items: [
                for (var weekday = 0; weekday < 7; weekday++)
                  DropdownMenuItem(
                    value: weekday,
                    child: LocalizedText(_weekdayNames[weekday]),
                  ),
              ],
            ),
          ),
          _SettingSwitch(
            title: 'Niveau anpassen',
            subtitle: 'Lernplan folgt deinem Fortschritt.',
            value: values.adaptiveLevel,
            onChanged: disabled
                ? null
                : (enabled) => _preferences.update(
                    values.copyWith(adaptiveLevel: enabled),
                  ),
          ),
          _SettingSwitch(
            title: 'Sprachausgabe',
            subtitle: 'Worter laut anhoeren.',
            value: values.speechOutput,
            onChanged: disabled
                ? null
                : (enabled) => _preferences.update(
                    values.copyWith(speechOutput: enabled),
                  ),
          ),
          const SizedBox(height: 16),
          const Eyebrow('BENACHRICHTIGUNGEN'),
          const SizedBox(height: 8),
          _SettingSwitch(
            title: 'Lernerinnerung',
            value: values.learningReminder,
            onChanged: disabled
                ? null
                : (enabled) => _preferences.update(
                    values.copyWith(learningReminder: enabled),
                  ),
          ),
          _SettingSwitch(
            title: 'Gruppennachrichten',
            value: values.groupMessages,
            onChanged: disabled
                ? null
                : (enabled) => _preferences.update(
                    values.copyWith(groupMessages: enabled),
                  ),
          ),
          _SettingSwitch(
            title: 'Wochenbericht',
            value: values.weeklySummary,
            onChanged: disabled
                ? null
                : (enabled) => _preferences.update(
                    values.copyWith(weeklySummary: enabled),
                  ),
          ),
          if (state.failure case final failure?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Semantics(
                liveRegion: true,
                child: LocalizedText(
                  _preferenceFailure(failure.kind),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (state.savedAt != null && state.failure == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LocalizedText('Auf deinem Profil gespeichert.'),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      title: 'Einstellungen',
      children: [
        const Eyebrow('SPRACHE'),
        const SizedBox(height: 8),
        SegmentedButton<AppLanguage>(
          segments: const [
            ButtonSegment(
              value: AppLanguage.de,
              label: LocalizedText('Deutsch'),
            ),
            ButtonSegment(
              value: AppLanguage.en,
              label: LocalizedText('English'),
            ),
          ],
          selected: {widget.localeController.language},
          onSelectionChanged: _savingLanguage
              ? null
              : (selection) => _changeLanguage(selection.first),
        ),
        if (_languageError != null) ...[
          const SizedBox(height: 8),
          LocalizedText(
            _languageError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        const Eyebrow('LERNEN'),
        const SizedBox(height: 8),
        _preferenceControls(context),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: widget.pushNotifications,
          builder: (context, _) {
            final service = widget.pushNotifications;
            final strings = WortwerkLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingSwitch(
                  title: strings(WText.pushPromptTitle),
                  subtitle: strings(WText.pushPromptBody),
                  value: service.enabled,
                  onChanged: service.isWorking ? null : _setPushEnabled,
                ),
                if (service.problem case final problem?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: LocalizedText(
                      strings(_pushProblemText(problem)),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _AccountSection(authSession: widget.authSession),
        const SizedBox(height: 14),
        const FlatCard(
          child: LocalizedText(
            'Einstellungen werden mit deinem Firebase-Profil synchronisiert.',
          ),
        ),
      ],
    );
  }
}

/// Maps a shared failure onto the catalog entry the learner should read.
WText _failureText(AppFailureKind kind) => switch (kind) {
  AppFailureKind.network => WText.failureNetwork,
  AppFailureKind.timeout => WText.failureTimeout,
  AppFailureKind.unauthenticated => WText.failureUnauthenticated,
  AppFailureKind.permissionDenied => WText.failurePermissionDenied,
  AppFailureKind.notFound => WText.failureNotFound,
  AppFailureKind.rateLimited => WText.failureRateLimited,
  AppFailureKind.serverError => WText.failureServer,
  AppFailureKind.validation => WText.failureValidation,
  AppFailureKind.conflict => WText.failureConflict,
  AppFailureKind.contentMissing => WText.failureContentMissing,
  AppFailureKind.unknown => WText.failureTitle,
};

/// The Konto block of Settings: verification, sign-out and deletion.
///
/// Progress and failures come from the session bloc rather than local
/// `setState`, so the account lifecycle has exactly one owner. Destructive
/// actions are confirmed in a sheet first (SPEC 4.13).
final class _AccountSection extends StatefulWidget {
  const _AccountSection({required this.authSession});

  final AuthSessionBloc authSession;

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

final class _AccountSectionState extends State<_AccountSection> {
  StreamSubscription<AuthSessionNotice>? _notices;

  @override
  void initState() {
    super.initState();
    _notices = widget.authSession.notices.listen(_onNotice);
  }

  @override
  void dispose() {
    unawaited(_notices?.cancel());
    super.dispose();
  }

  void _onNotice(AuthSessionNotice notice) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final strings = WortwerkLocalizations.of(context);
    final message = switch (notice) {
      AuthSessionNotice.verificationSent => strings(
        WText.accountVerificationSent,
      ),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<bool> _confirm({
    required WText title,
    required WText body,
    required WText action,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final strings = WortwerkLocalizations.of(sheetContext);
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings(title), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(strings(body)),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: WortwerkColors.flameRed,
                  foregroundColor: WortwerkColors.paper,
                ),
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(strings(action)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(strings(WText.accountCancel)),
              ),
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _signOut() async {
    final confirmed = await _confirm(
      title: WText.accountSignOutConfirmTitle,
      body: WText.accountSignOutConfirmBody,
      action: WText.accountSignOutAction,
    );
    if (!confirmed || !mounted) return;
    widget.authSession.add(const AuthSessionSignOutRequested());
  }

  Future<void> _delete() async {
    final account = widget.authSession.state.account;
    if (account == null) return;
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          _DeleteAccountSheet(requiresPassword: account.hasPasswordProvider),
    );
    if (password == null || !mounted) return;
    widget.authSession.add(AuthSessionDeletionRequested(password: password));
  }

  String _statusTitle(WortwerkStrings strings, AuthAccount? account) {
    if (account == null || account.isAnonymous) {
      return strings(WText.accountGuestStatus);
    }
    return strings(
      account.emailVerified
          ? WText.accountVerifiedBadge
          : WText.accountUnverifiedBadge,
    );
  }

  String _statusBody(WortwerkStrings strings, AuthAccount? account) {
    final email = account?.email;
    if (account == null || account.isAnonymous || email == null) {
      return strings(WText.accountGuestStatusBody);
    }
    return strings.signedInAs(email);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthSessionBloc, AuthSessionState>(
      bloc: widget.authSession,
      builder: (context, session) {
        final account = session.account;
        final strings = WortwerkLocalizations.of(context);
        final busy = session.isPending;
        final failure = session.failure;
        final canVerify =
            account != null &&
            !account.isAnonymous &&
            account.email != null &&
            !account.emailVerified;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('KONTO'),
            const SizedBox(height: 8),
            FlatCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _statusTitle(strings, account),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_statusBody(strings, account)),
                  if (canVerify) ...[
                    const SizedBox(height: 12),
                    Text(
                      strings(WText.accountVerifyBody),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: busy
                          ? null
                          : () => widget.authSession.add(
                              const AuthSessionVerificationRequested(),
                            ),
                      child: Text(strings(WText.accountVerifyAction)),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => widget.authSession.add(
                              const AuthSessionReloadRequested(),
                            ),
                      child: Text(strings(WText.accountRefreshAction)),
                    ),
                  ],
                  if (account?.hasPasswordProvider ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      strings(WText.accountDeleteWarning),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (failure != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      strings(_failureText(failure.kind)),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.authSession.add(
                      const AuthSessionFailureDismissed(),
                    ),
                    tooltip: strings(WText.accountCancel),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: Text(strings(WText.accountSignOutAction)),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: busy || account == null || account.isAnonymous
                  ? null
                  : _delete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: WortwerkColors.flameRed,
              ),
              label: Text(
                strings(WText.accountDeleteAction),
                style: const TextStyle(color: WortwerkColors.flameRed),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Confirmation sheet for deletion; returns the re-authentication password,
/// an empty string when the account needs none, and `null` when cancelled.
final class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.requiresPassword});

  final bool requiresPassword;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

final class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final TextEditingController _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = WortwerkLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings(WText.accountDeleteConfirmTitle),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(strings(WText.accountDeleteConfirmBody)),
          if (widget.requiresPassword) ...[
            const SizedBox(height: 16),
            Text(
              strings(WText.accountDeleteWarning),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: _hidePassword,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings(WText.accountDeletePasswordLabel),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  tooltip: strings(
                    _hidePassword
                        ? WText.authShowPassword
                        : WText.authHidePassword,
                  ),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WortwerkColors.flameRed,
              foregroundColor: WortwerkColors.paper,
            ),
            onPressed: () => Navigator.of(context).pop(_password.text),
            child: Text(strings(WText.accountDeleteAction)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings(WText.accountCancel)),
          ),
        ],
      ),
    );
  }
}

final class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: LocalizedText(title),
      subtitle: subtitle == null ? null : LocalizedText(subtitle!),
      value: value,
      onChanged: onChanged,
      activeThumbColor: WortwerkColors.ink,
    );
  }
}

final class LevelUpPage extends StatelessWidget {
  const LevelUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      title: 'Ein neuer Abschnitt',
      subtitle: 'Ein Schritt, auf den du stolz sein kannst.',
      children: [
        const _LevelUpCelebration(),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => context.go('/path'),
          child: const LocalizedText('Weiterlernen'),
        ),
      ],
    );
  }
}

final class _LevelUpCelebration extends StatefulWidget {
  const _LevelUpCelebration();

  @override
  State<_LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

final class _LevelUpCelebrationState extends State<_LevelUpCelebration> {
  static const _sparkColors = [
    WortwerkColors.streak,
    WortwerkColors.flameRed,
    WortwerkColors.a1,
    WortwerkColors.b1,
    WortwerkColors.b2,
    WortwerkColors.c2,
  ];

  final FritzController _fritz = FritzController(mood: FritzMood.celebrate);

  @override
  void dispose() {
    _fritz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1450),
      curve: Curves.easeOutBack,
      builder: (context, progress, _) => SizedBox(
        height: 350,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 25 + 8 * (1 - progress),
              child: Opacity(
                opacity: progress.clamp(0, 1).toDouble(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFC),
                    borderRadius: BorderRadius.circular(WortwerkRadii.pill),
                    border: Border.all(color: WortwerkColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: WortwerkColors.streak.withValues(alpha: 0.13),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: WortwerkColors.streak,
                      ),
                      SizedBox(width: 7),
                      LocalizedText('EIN NEUER ABSCHNITT'),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _LevelUpSparkPainter(
                    progress: progress,
                    colors: _sparkColors,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ConfettiBurst(
                  particleCount: 80,
                  duration: const Duration(milliseconds: 1200),
                  colors: _sparkColors,
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, 14 * (1 - progress.clamp(0, 1))),
              child: Transform.scale(
                scale: 0.82 + progress.clamp(0, 1) * 0.18,
                child: Opacity(
                  opacity: progress.clamp(0, 1).toDouble(),
                  child: FlatCard(
                    color: Color.lerp(
                      WortwerkColors.a1,
                      WortwerkColors.c2,
                      progress.clamp(0, 1),
                    )!,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: 0.10 * (1 - progress.clamp(0, 1)),
                          child: FritzMoodAvatar(controller: _fritz, size: 116),
                        ),
                        const SizedBox(height: 16),
                        LocalizedText(
                          'Weiter in deinem Tempo.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        LocalizedText(
                          'Dein nächstes Lernziel wartet auf dich.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LevelUpSparkPainter extends CustomPainter {
  const _LevelUpSparkPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  static const _sparkPositions = [
    Offset(0.10, 0.25),
    Offset(0.83, 0.14),
    Offset(0.16, 0.76),
    Offset(0.87, 0.70),
    Offset(0.50, 0.08),
    Offset(0.49, 0.91),
    Offset(0.04, 0.50),
    Offset(0.96, 0.42),
    Offset(0.27, 0.09),
    Offset(0.74, 0.90),
    Offset(0.08, 0.88),
    Offset(0.92, 0.90),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _sparkPositions.length; index++) {
      final position = _sparkPositions[index];
      final distance = 6 + 25 * progress;
      final point = Offset(
        position.dx * size.width,
        position.dy * size.height - distance,
      );
      final radius = (2 + (index % 3)) * progress;
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = colors[index % colors.length].withValues(
            alpha: (0.22 + 0.78 * progress).clamp(0, 1).toDouble(),
          ),
      );
      if (index.isEven) {
        final arm = radius * 1.8;
        final paint = Paint()
          ..color = colors[index % colors.length].withValues(
            alpha: progress.clamp(0, 1).toDouble(),
          )
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(point.dx - arm, point.dy),
          Offset(point.dx + arm, point.dy),
          paint,
        );
        canvas.drawLine(
          Offset(point.dx, point.dy - arm),
          Offset(point.dx, point.dy + arm),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LevelUpSparkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
