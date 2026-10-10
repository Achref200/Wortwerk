import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/localized_text.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/wortwerk_strings.dart';
import '../../../design_system/components.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../domain/inbox_notification.dart';
import '../domain/notifications_repository.dart';

final class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.repository, super.key});

  final NotificationsRepository repository;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

final class _NotificationsPageState extends State<NotificationsPage> {
  late Stream<List<InboxNotification>> _inbox;
  List<InboxNotification>? _cachedInbox;

  @override
  void initState() {
    super.initState();
    _inbox = widget.repository.watchInbox();
  }

  void _retry() => setState(() => _inbox = widget.repository.watchInbox());

  Future<void> _markRead(InboxNotification notification) async {
    if (notification.isRead) return;
    try {
      await widget.repository.markRead(notification.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            WortwerkLocalizations.of(context)
                .fromSource('Dieser Hinweis konnte nicht gelesen werden.'),
          ),
        ),
      );
    }
  }

  void _open(InboxNotification notification) {
    unawaited(_markRead(notification));
    final link = notification.deepLink;
    if (link == null) return;
    final uri = Uri.tryParse(link);
    if (uri == null ||
        uri.hasScheme ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//')) {
      return;
    }
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final strings = WortwerkLocalizations.of(context);
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
                    'Hinweise',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 52, bottom: 14),
              child: LocalizedText('Du bist auf dem Laufenden.'),
            ),
            StreamBuilder<List<InboxNotification>>(
              stream: _inbox,
              builder: (context, snapshot) {
                if (snapshot.hasData) _cachedInbox = snapshot.data;
                if (snapshot.hasError &&
                    !snapshot.hasData &&
                    _cachedInbox == null) {
                  return _errorState(strings);
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 52),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final notifications =
                    snapshot.data ??
                    _cachedInbox ??
                    const <InboxNotification>[];
                final content = notifications.isEmpty
                    ? _emptyState(strings)
                    : _groupedNotifications(notifications, strings);
                if (!snapshot.hasError) return content;
                return Column(children: [_staleDataWarning(strings), content]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(WortwerkStrings strings) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 42),
        const SizedBox(height: 12),
        LocalizedText(
          strings(WText.notifLoadError),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh_rounded),
          label: LocalizedText(strings(WText.retry)),
        ),
      ],
    ),
  );

  Widget _emptyState(WortwerkStrings strings) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42),
    child: Column(
      children: [
        const Icon(Icons.notifications_none_rounded, size: 48),
        const SizedBox(height: 16),
        LocalizedText(
          strings(WText.notifEmpty),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        LocalizedText(
          strings(WText.notifEmptyBody),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _staleDataWarning(WortwerkStrings strings) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: WortwerkColors.paper,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(child: LocalizedText(strings(WText.notifLoadError))),
        TextButton(
          onPressed: _retry,
          child: LocalizedText(strings(WText.retry)),
        ),
      ],
    ),
  );

  Widget _groupedNotifications(
    List<InboxNotification> notifications,
    WortwerkStrings strings,
  ) {
    final now = DateTime.now();
    final groups = <String, List<InboxNotification>>{};
    for (final notification in notifications) {
      final localDate = notification.createdAt.toLocal();
      final age = DateTime(now.year, now.month, now.day)
          .difference(DateTime(localDate.year, localDate.month, localDate.day))
          .inDays;
      final heading = age <= 0
          ? strings(WText.notifToday)
          : age == 1
          ? strings(WText.notifYesterday)
          : strings(WText.notifEarlier);
      groups.putIfAbsent(heading, () => []).add(notification);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Eyebrow(entry.key.toUpperCase()),
          const SizedBox(height: 6),
          for (final notification in entry.value)
            _notificationTile(notification, strings),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _notificationTile(
    InboxNotification notification,
    WortwerkStrings strings,
  ) {
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Icon(
        _icon(notification.kind),
        color: notification.isRead ? WortwerkColors.muted : WortwerkColors.ink,
      ),
      title: Row(
        children: [
          Expanded(child: LocalizedText(_title(notification, strings))),
          if (!notification.isRead)
            Semantics(
              label: strings(WText.notifUnread),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: WortwerkColors.streak,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(_body(notification, strings)),
            const SizedBox(height: 4),
            Text(
              _timeLabel(notification.createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      onTap: () => _open(notification),
    );
    if (notification.isRead) return tile;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: WortwerkColors.paper,
        child: const Icon(Icons.done_rounded),
      ),
      onDismissed: (_) => _markRead(notification),
      child: tile,
    );
  }

  String _title(
    InboxNotification notification,
    WortwerkStrings strings,
  ) => switch (notification.kind) {
    InboxNotificationKind.levelUnlocked => strings(
      WText.notifLevelUnlockedTitle,
    ),
    InboxNotificationKind.learningReminder => strings(WText.notifReminderTitle),
    InboxNotificationKind.groupMessage => strings(WText.notifGroupMessageTitle),
    InboxNotificationKind.unknown => strings(WText.notifGenericTitle),
  };

  String _body(
    InboxNotification notification,
    WortwerkStrings strings,
  ) => switch (notification.kind) {
    InboxNotificationKind.levelUnlocked when notification.level != null =>
      strings.levelUnlockedBody(notification.level!),
    InboxNotificationKind.levelUnlocked => strings(WText.notifGenericBody),
    InboxNotificationKind.learningReminder => strings(WText.notifReminderBody),
    InboxNotificationKind.groupMessage => strings(WText.notifGroupMessageBody),
    InboxNotificationKind.unknown => strings(WText.notifGenericBody),
  };

  IconData _icon(InboxNotificationKind kind) => switch (kind) {
    InboxNotificationKind.levelUnlocked => Icons.auto_awesome_outlined,
    InboxNotificationKind.learningReminder => Icons.wb_sunny_outlined,
    InboxNotificationKind.groupMessage => Icons.forum_outlined,
    InboxNotificationKind.unknown => Icons.notifications_none_rounded,
  };

  String _timeLabel(DateTime timestamp) {
    final date = timestamp.toLocal();
    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    if (isToday) return time;
    final dateLabel =
        WortwerkLocalizations.of(context).language == AppLanguage.en
        ? '${date.month}/${date.day}/${date.year}'
        : '${date.day}.${date.month}.${date.year}';
    return '$dateLabel · $time';
  }
}
