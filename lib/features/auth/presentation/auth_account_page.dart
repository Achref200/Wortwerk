import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:flutter/material.dart';

import '../../../design_system/wortwerk_theme.dart';
import '../domain/auth_account.dart';
import '../domain/auth_repository.dart';

/// A standalone account page for continuing as a guest or linking an account.
class AuthAccountPage extends StatefulWidget {
  const AuthAccountPage({
    required this.repository,
    this.onContinueAsGuest,
    this.onAccountLinked,
    super.key,
  });

  final AuthRepository repository;
  final ValueChanged<AuthAccount>? onContinueAsGuest;
  final ValueChanged<AuthAccount>? onAccountLinked;

  @override
  State<AuthAccountPage> createState() => _AuthAccountPageState();
}

class _AuthAccountPageState extends State<AuthAccountPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _signInMode = false;
  bool _hidePassword = true;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<AuthAccount?> _runAccountAction(
    Future<AuthAccount> Function() action,
  ) async {
    if (_busy) return null;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    AuthAccount? account;
    try {
      account = await action();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _localizedError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return account;
  }

  Future<void> _continueAsGuest() async {
    final account = await _runAccountAction(
      widget.repository.ensureGuestSession,
    );
    if (!mounted || account == null) return;
    setState(
      () => _statusMessage = 'Deine Gastsitzung ist auf diesem Gerät bereit.',
    );
    widget.onContinueAsGuest?.call(account);
  }

  Future<void> _linkAccount(Future<AuthAccount> Function() action) async {
    final account = await _runAccountAction(action);
    if (!mounted || account == null) return;
    setState(
      () => _statusMessage = 'Dein Konto ist mit dieser Sitzung verknüpft.',
    );
    widget.onAccountLinked?.call(account);
  }

  Future<void> _sendEmailLink() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() {
        _errorMessage =
            'Gib eine gültige E-Mail-Adresse ein, um einen Anmeldelink zu '
            'erhalten.';
        _statusMessage = null;
      });
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await widget.repository.sendEmailLink(email: email);
      if (mounted) {
        setState(
          () => _statusMessage =
              'Wir haben einen Link an $email gesendet. Öffne ihn auf diesem '
              'Gerät, um deine Gastsitzung zu verknüpfen.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _localizedError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_looksLikeEmail(email)) {
      setState(() {
        _errorMessage = 'Gib eine g\u00fcltige E-Mail-Adresse ein.';
        _statusMessage = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Dein Passwort braucht mindestens sechs Zeichen.';
        _statusMessage = null;
      });
      return;
    }
    final account = await _runAccountAction(
      () => _signInMode
          ? widget.repository.signInWithEmailPassword(
              email: email,
              password: password,
            )
          : widget.repository.createEmailPasswordAccount(
              email: email,
              password: password,
            ),
    );
    if (!mounted || account == null) return;
    setState(() {
      _statusMessage = _signInMode
          ? 'Du bist angemeldet.'
          : 'Dein Konto ist erstellt. Dein Lernfortschritt ist verkn\u00fcpft.';
    });
    widget.onAccountLinked?.call(account);
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() {
        _errorMessage = 'Gib zuerst deine E-Mail-Adresse ein.';
        _statusMessage = null;
      });
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await widget.repository.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(
          () => _statusMessage =
              'Falls ein Konto zu dieser Adresse geh\u00f6rt, ist eine E-Mail '
              'zum Zur\u00fccksetzen des Passworts unterwegs.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _localizedError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    return at > 0 && at < value.length - 3 && value.lastIndexOf('.') > at + 1;
  }

  String _localizedError(Object error) {
    if (error is AuthFailure) return error.userMessage;
    return 'Die Anmeldung hat gerade nicht geklappt. Bitte versuche es erneut.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccountHero(),
                  const SizedBox(height: 24),
                  AnimatedSize(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: _busy
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Semantics(
                              liveRegion: true,
                              label: 'Deine Sitzung wird sicher verknüpft',
                              child: const LinearProgressIndicator(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  LocalizedText(
                    'Dein Lernen – überall dabei.',
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  LocalizedText(
                    'Starte als Gast und verknüpfe dein Konto, wann immer du '
                    'möchtest. So bleibt dein Lernfortschritt mit derselben '
                    'Sitzung verbunden.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: WortwerkColors.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _buildProviderButton(
                    label: 'Mit Google fortfahren',
                    icon: const LocalizedText(
                      'G',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: WortwerkColors.ink,
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _linkAccount(widget.repository.linkGoogle),
                  ),
                  const SizedBox(height: 12),
                  _buildProviderButton(
                    label: 'Mit Apple fortfahren',
                    icon: const Icon(Icons.apple, size: 22),
                    onPressed: _busy
                        ? null
                        : () => _linkAccount(widget.repository.linkApple),
                  ),
                  const SizedBox(height: 20),
                  _PasswordAccountCard(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    busy: _busy,
                    signInMode: _signInMode,
                    hidePassword: _hidePassword,
                    onToggleMode: () => setState(() {
                      _signInMode = !_signInMode;
                      _errorMessage = null;
                      _statusMessage = null;
                    }),
                    onTogglePassword: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    onSubmit: _submitPassword,
                    onReset: _sendPasswordReset,
                    onSendEmailLink: _sendEmailLink,
                  ),
                  AnimatedSize(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: _buildAccountMessage(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _busy ? null : _continueAsGuest,
                    child: _busy
                        ? SizedBox.square(
                            dimension: 20,
                            child: Semantics(
                              label: 'Wird geladen',
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const LocalizedText('Weiter als Gast'),
                  ),
                  const SizedBox(height: 10),
                  LocalizedText(
                    'Dein Lernfortschritt bleibt auf diesem Gerät, bis du ein '
                    'Konto verknüpfst.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderButton({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: LocalizedText(label),
      ),
    );
  }

  Widget _buildAccountMessage() {
    final error = _errorMessage;
    if (error != null) {
      return Padding(
        key: const ValueKey('account-error'),
        padding: const EdgeInsets.only(top: 16),
        child: _MessageCard(message: error, error: true),
      );
    }
    final status = _statusMessage;
    if (status != null) {
      return Padding(
        key: const ValueKey('account-status'),
        padding: const EdgeInsets.only(top: 16),
        child: _MessageCard(message: status),
      );
    }
    return const SizedBox.shrink(key: ValueKey('account-no-message'));
  }
}

class _AccountHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0.72, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: WortwerkColors.c2,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 38,
            color: WortwerkColors.ink,
            semanticLabel: 'Lernbuch-Symbol',
          ),
        ),
      ),
    );
  }
}

class _PasswordAccountCard extends StatelessWidget {
  const _PasswordAccountCard({
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.signInMode,
    required this.hidePassword,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onReset,
    required this.onSendEmailLink,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final bool signInMode;
  final bool hidePassword;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onReset;
  final VoidCallback onSendEmailLink;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedText(
              signInMode ? 'Anmelden' : 'Konto mit Passwort erstellen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            LocalizedText(
              signInMode
                  ? 'Melde dich mit deinem bestehenden Wortwerk-Konto an. '
                        'Der Gastfortschritt dieser Sitzung wird nicht automatisch '
                        'in ein bestehendes Konto übertragen.'
                  : 'Dein Konto sichert deinen Lernfortschritt auf mehreren Ger\u00e4ten.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('account-email'),
              controller: emailController,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-Mail-Adresse',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('account-password'),
              controller: passwordController,
              enabled: !busy,
              obscureText: hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: signInMode
                  ? const [AutofillHints.password]
                  : const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Passwort',
                helperText: signInMode ? null : 'Mindestens sechs Zeichen',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  tooltip: hidePassword
                      ? 'Passwort anzeigen'
                      : 'Passwort verbergen',
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: LocalizedText(signInMode ? 'Anmelden' : 'Konto erstellen'),
            ),
            TextButton.icon(
              onPressed: busy ? null : onSendEmailLink,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const LocalizedText('Stattdessen E-Mail-Link senden'),
            ),
            if (signInMode)
              TextButton(
                onPressed: busy ? null : onReset,
                child: const LocalizedText('Passwort vergessen?'),
              ),
            TextButton(
              onPressed: busy ? null : onToggleMode,
              child: LocalizedText(
                signInMode
                    ? 'Noch kein Konto? Jetzt erstellen'
                    : 'Schon ein Konto? Anmelden',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? Theme.of(context).colorScheme.error
        : WortwerkColors.ink;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: error
            ? Theme.of(context).colorScheme.errorContainer
            : WortwerkColors.b2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LocalizedText(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
