import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:flutter/material.dart';

import '../core/error/app_failure.dart';
import '../core/l10n/wortwerk_strings.dart';
import 'fritz_avatar.dart';
import 'wortwerk_theme.dart';

final class ScreenContent extends StatelessWidget {
  const ScreenContent({
    required this.children,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 28),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: padding, children: children);
  }
}

final class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    super.key,
    this.trailing,
    this.onTrailingPressed,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LocalizedText(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (trailing != null)
          TextButton(
            onPressed: onTrailingPressed,
            child: LocalizedText(trailing!),
          ),
      ],
    );
  }
}

final class FlatCard extends StatelessWidget {
  const FlatCard({
    required this.child,
    super.key,
    this.color = const Color(0xFFFFFEFC),
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = WortwerkRadii.card,
    this.border = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border
            ? Border.all(color: WortwerkColors.line, width: 1)
            : null,
      ),
      child: child,
    );
  }
}

final class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return LocalizedText(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color ?? WortwerkColors.muted, letterSpacing: 1),
    );
  }
}

final class CircleAction extends StatelessWidget {
  const CircleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: const Color(0xFFFFFEFC),
        foregroundColor: WortwerkColors.ink,
        side: const BorderSide(color: WortwerkColors.line),
      ),
      icon: Icon(icon),
    );
  }
}

final class WLoadingState extends StatelessWidget {
  const WLoadingState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedFritzAvatar(size: 64),
          const SizedBox(height: 14),
          LocalizedText(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SizedBox(
            width: 112,
            child: LinearProgressIndicator(value: reduceMotion ? 1 : null),
          ),
        ],
      ),
    );
  }
}

final class WEmptyState extends StatelessWidget {
  const WEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AnimatedFritzAvatar(size: 72),
        const SizedBox(height: 16),
        LocalizedText(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LocalizedText(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: LocalizedText(actionLabel!)),
        ],
      ],
    );
  }
}

final class WFailureState extends StatelessWidget {
  const WFailureState({
    required this.failure,
    required this.onRetry,
    this.title,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _iconFor(failure.kind),
          size: 44,
          color: theme.colorScheme.error,
          semanticLabel: title,
        ),
        const SizedBox(height: 14),
        LocalizedText(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LocalizedText(
          _messageFor(WortwerkLocalizations.of(context), failure.kind),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const LocalizedText('Erneut versuchen'),
        ),
      ],
    );
  }

  IconData _iconFor(AppFailureKind kind) => switch (kind) {
    AppFailureKind.network => Icons.cloud_off_outlined,
    AppFailureKind.timeout => Icons.hourglass_empty_rounded,
    AppFailureKind.contentMissing ||
    AppFailureKind.notFound => Icons.menu_book_outlined,
    AppFailureKind.permissionDenied ||
    AppFailureKind.unauthenticated => Icons.lock_outline_rounded,
    _ => Icons.sync_problem_rounded,
  };

  String _messageFor(WortwerkStrings strings, AppFailureKind kind) =>
      strings(switch (kind) {
        AppFailureKind.network => WText.failureNetwork,
        AppFailureKind.timeout => WText.failureTimeout,
        AppFailureKind.contentMissing => WText.failureContentMissing,
        AppFailureKind.notFound => WText.failureNotFound,
        AppFailureKind.permissionDenied => WText.failurePermissionDenied,
        AppFailureKind.unauthenticated => WText.failureUnauthenticated,
        AppFailureKind.rateLimited => WText.failureRateLimited,
        AppFailureKind.validation => WText.failureValidation,
        AppFailureKind.conflict => WText.failureConflict,
        AppFailureKind.serverError ||
        AppFailureKind.unknown => WText.failureServer,
      });
}
