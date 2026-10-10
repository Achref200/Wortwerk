import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/animated_counter.dart';
import '../../../core/l10n/localized_text.dart';
import '../../../design_system/components.dart';
import '../../../design_system/fritz_avatar.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../../auth/application/auth_session_bloc.dart';
import '../../auth/domain/auth_account.dart';
import '../../auth/domain/auth_session_state.dart';
import '../domain/learner_profile.dart';
import '../domain/learner_profile_repository.dart';

final class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.authSession,
    required this.repository,
    super.key,
  });

  final AuthSessionBloc authSession;
  final LearnerProfileRepository repository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

final class _ProfilePageState extends State<ProfilePage> {
  late Stream<LearnerProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = widget.repository.watchProfile();
  }

  void _retry() {
    setState(() => _profileStream = widget.repository.watchProfile());
  }

  Future<void> _editName(String currentName) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DisplayNameSheet(initialName: currentName),
    );
    if (name == null || !mounted) return;
    try {
      await widget.repository.updateDisplayName(name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: LocalizedText('Der Name konnte nicht gespeichert werden.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthSessionBloc, AuthSessionState>(
        bloc: widget.authSession,
        builder: (context, session) {
          if (!session.isResolved) {
            return _ProfileStateCard(
              child: Semantics(
                liveRegion: true,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final account = session.account;
          if (account == null) {
            return _ProfileShell(
              children: [
                const _ProfileStateCard(
                  child: LocalizedText(
                    'Melde dich an, um dein Lernprofil zu sehen.',
                  ),
                ),
                FilledButton(
                  onPressed: () => context.push('/account'),
                  child: const LocalizedText('Anmelden oder Konto erstellen'),
                ),
              ],
            );
          }
          return StreamBuilder<LearnerProfile?>(
            stream: _profileStream,
            builder: (context, snapshot) {
              if (snapshot.hasError && !snapshot.hasData) {
                return _ProfileShell(
                  children: [
                    _ProfileStateCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: LocalizedText(
                              'Dein Profil ist gerade nicht verfuegbar.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const LocalizedText('Erneut versuchen'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _ProfileShell(
                  children: [
                    _ProfileStateCard(
                      child: Semantics(
                        liveRegion: true,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ],
                );
              }
              final profile = snapshot.data;
              if (profile == null) {
                return _ProfileShell(
                  children: [
                    const _ProfileStateCard(
                      child: LocalizedText(
                        'Dein Lernprofil wird noch eingerichtet.',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const LocalizedText('Erneut versuchen'),
                    ),
                  ],
                );
              }
              return _buildProfile(context, account, profile);
            },
          );
        },
      );

  Widget _buildProfile(
    BuildContext context,
    AuthAccount account,
    LearnerProfile profile,
  ) {
    final name = profile.displayName.trim().isEmpty
        ? (account.displayName?.trim().isNotEmpty == true
              ? account.displayName!.trim()
              : 'Deutsch-Lernende Person')
        : profile.displayName;
    return _ProfileShell(
      children: [
        Row(
          children: [
            Expanded(
              child: LocalizedText(
                'Dein Profil',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            CircleAction(
              icon: Icons.settings_outlined,
              label: 'Einstellungen',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FlatCard(
          color: WortwerkColors.a1,
          child: Column(
            children: [
              const FritzAvatar(size: 92),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                account.email ??
                    (account.isAnonymous ? 'Gastsitzung' : 'Konto verbunden'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Level ${profile.level}')),
                  Chip(label: Text('${profile.dailyMinutes} Minuten pro Tag')),
                  for (final goal in profile.goals) Chip(label: Text(goal)),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _editName(profile.displayName),
                icon: const Icon(Icons.edit_outlined),
                label: const LocalizedText('Namen bearbeiten'),
              ),
              if (account.isAnonymous) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => context.push('/account'),
                  child: const LocalizedText(
                    'Konto verknuepfen und Fortschritt sichern',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: 'Dein Fortschritt'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfileMetric(
                title: 'XP insgesamt',
                value: profile.xpTotal,
                icon: Icons.auto_awesome_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileMetric(
                title: 'Lerntage in Folge',
                value: profile.currentStreak,
                icon: Icons.local_fire_department_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ProfileMetric(
          title: 'Laengste Serie',
          value: profile.longestStreak,
          icon: Icons.emoji_events_outlined,
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: 'Dein Lernweg'),
        const SizedBox(height: 12),
        _ProfileLink(
          icon: Icons.route_outlined,
          title: 'Level und Einheiten',
          onPressed: () => context.go('/path'),
        ),
        const SizedBox(height: 10),
        _ProfileLink(
          icon: Icons.local_fire_department_outlined,
          title: 'Lernrhythmus',
          onPressed: () => context.push('/streak'),
        ),
        const SizedBox(height: 10),
        _ProfileLink(
          icon: Icons.notifications_none_rounded,
          title: 'Benachrichtigungen',
          onPressed: () => context.push('/notifications'),
        ),
      ],
    );
  }
}

final class _ProfileShell extends StatelessWidget {
  const _ProfileShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ScreenContent(children: children);
}

final class _ProfileStateCard extends StatelessWidget {
  const _ProfileStateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: FlatCard(child: child),
    ),
  );
}

final class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FlatCard(
    child: Row(
      children: [
        Icon(icon, color: WortwerkColors.streak),
        const SizedBox(width: 10),
        Expanded(child: LocalizedText(title)),
        AnimatedCounter(
          value: value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}

final class _DisplayNameSheet extends StatefulWidget {
  const _DisplayNameSheet({required this.initialName});

  final String initialName;

  @override
  State<_DisplayNameSheet> createState() => _DisplayNameSheetState();
}

final class _DisplayNameSheetState extends State<_DisplayNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 64) {
      setState(() => _error = 'Gib einen Namen mit 1 bis 64 Zeichen ein.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      8,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LocalizedText(
          'Dein Name',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 64,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: 'Anzeigename',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const LocalizedText('Speichern')),
      ],
    ),
  );
}

final class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFFEFC),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WortwerkColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
