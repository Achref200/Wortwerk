import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wortwerk_strings.dart';
import '../../../design_system/components.dart';
import '../../../design_system/wortwerk_theme.dart';
import '../domain/community_repository.dart';

final class CommunityPage extends StatefulWidget {
  const CommunityPage({required this.repository, super.key});

  final CommunityRepository repository;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

final class _CommunityPageState extends State<CommunityPage> {
  String _filter = 'Alle';
  int _reload = 0;
  final Set<String> _workingGroups = {};

  Future<void> _join(LearningGroup group) async {
    final accepted = await _showJoinAgreement(context);
    if (accepted != true || !mounted) return;
    setState(() => _workingGroups.add(group.id));
    try {
      await widget.repository.joinGroup(group.id);
      if (mounted) _message(WText.communityJoined);
    } catch (_) {
      if (mounted) _message(WText.communityJoinFailed, error: true);
    } finally {
      if (mounted) setState(() => _workingGroups.remove(group.id));
    }
  }

  void _message(WText key, {bool error = false}) {
    final strings = WortwerkLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(strings(key)),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final strings = WortwerkLocalizations.of(context);
    return ScreenContent(
      children: [
        Text(
          strings(WText.communityTitle),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          strings(WText.communitySubtitle),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            _filterChip(WText.communityFilterAll, 'Alle'),
            _filterChip(WText.communityFilterJoined, 'Dabei'),
            for (final level in ['A1', 'A2', 'B1'])
              ChoiceChip(
                label: Text(level),
                selected: _filter == level,
                onSelected: (_) => setState(() => _filter = level),
              ),
          ],
        ),
        const SizedBox(height: 18),
        StreamBuilder<Set<String>>(
          stream: widget.repository.watchJoinedGroupIds(),
          builder: (context, joinedSnapshot) {
            if (joinedSnapshot.hasError) {
              return _CommunityError(onRetry: () => setState(() => _reload++));
            }
            final joinedIds = joinedSnapshot.data ?? const <String>{};
            return StreamBuilder<List<LearningGroup>>(
              key: ValueKey(_reload),
              stream: widget.repository.watchGroups(),
              builder: (context, groupsSnapshot) {
                if (groupsSnapshot.hasError) {
                  return _CommunityError(
                    onRetry: () => setState(() => _reload++),
                  );
                }
                if (!groupsSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final groups = groupsSnapshot.data!
                    .where(
                      (group) => switch (_filter) {
                        'Dabei' => joinedIds.contains(group.id),
                        'A1' || 'A2' || 'B1' => group.level == _filter,
                        _ => true,
                      },
                    )
                    .toList();
                if (groups.isEmpty) {
                  return FlatCard(
                    color: WortwerkColors.b2,
                    child: Text(strings(WText.communityNoGroups)),
                  );
                }
                return Column(
                  children: [
                    for (final group in groups)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GroupCard(
                          group: group,
                          joined: joinedIds.contains(group.id),
                          isWorking: _workingGroups.contains(group.id),
                          onJoin: () => _join(group),
                          onOpen: () => context.go('/groups/${group.id}'),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        const Eyebrow('Miteinander'),
        const SizedBox(height: 8),
        Text(WortwerkLocalizations.of(context)(WText.communityRules)),
      ],
    );
  }

  Widget _filterChip(WText label, String value) => ChoiceChip(
    label: Text(WortwerkLocalizations.of(context)(label)),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );
}

Future<bool?> _showJoinAgreement(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) {
    var confirmsAge = false;
    var acceptsRules = false;
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final strings = WortwerkLocalizations.of(context);
        return AlertDialog(
          scrollable: true,
          title: Text(strings(WText.communityJoinConsentTitle)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings(WText.communityJoinConsentBody)),
              const SizedBox(height: 10),
              Text(strings(WText.communityRules)),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmsAge,
                title: Text(strings(WText.communityAgeAttest)),
                onChanged: (value) =>
                    setDialogState(() => confirmsAge = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: acceptsRules,
                title: Text(strings(WText.communityAcceptRules)),
                onChanged: (value) =>
                    setDialogState(() => acceptsRules = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings(WText.retry)),
            ),
            FilledButton(
              onPressed: confirmsAge && acceptsRules
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(strings(WText.communityJoin)),
            ),
          ],
        );
      },
    );
  },
);

final class _CommunityError extends StatelessWidget {
  const _CommunityError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = WortwerkLocalizations.of(context);
    return FlatCard(
      child: Column(
        children: [
          Text(strings(WText.communityLoadError)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text(strings(WText.retry))),
        ],
      ),
    );
  }
}

final class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.joined,
    required this.isWorking,
    required this.onJoin,
    required this.onOpen,
  });

  final LearningGroup group;
  final bool joined;
  final bool isWorking;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = WortwerkLocalizations.of(context);
    return FlatCard(
      color: WortwerkColors.b2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFC),
                  border: Border.all(color: WortwerkColors.line),
                  borderRadius: BorderRadius.circular(WortwerkRadii.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    group.level,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(group.topic),
          const SizedBox(height: 4),
          Text(
            strings.communityMemberCount(group.memberCount),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (group.lastMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              group.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: joined
                ? FilledButton.tonal(
                    onPressed: onOpen,
                    child: Text(strings(WText.communityOpen)),
                  )
                : FilledButton(
                    onPressed: isWorking ? null : onJoin,
                    child: isWorking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(strings(WText.communityJoin)),
                  ),
          ),
        ],
      ),
    );
  }
}

final class CommunityGroupPage extends StatefulWidget {
  const CommunityGroupPage({
    required this.repository,
    required this.groupId,
    super.key,
  });

  final CommunityRepository repository;
  final String groupId;

  @override
  State<CommunityGroupPage> createState() => _CommunityGroupPageState();
}

final class _CommunityGroupPageState extends State<CommunityGroupPage> {
  final _messageController = TextEditingController();
  bool _sending = false;
  String? _pendingBody;
  String? _pendingRequestId;
  String? _sendFailure;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _sending) return;
    final requestId = _pendingRequestId ??= newCommunityRequestId();
    setState(() {
      _sending = true;
      _pendingBody = body;
      _sendFailure = null;
    });
    try {
      await widget.repository.sendMessage(
        groupId: widget.groupId,
        clientRequestId: requestId,
        body: body,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _pendingRequestId = null;
        _pendingBody = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _sendFailure = WortwerkLocalizations.of(context)(
            WText.communitySendError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leave() async {
    try {
      await widget.repository.leaveGroup(widget.groupId);
      if (mounted) context.go('/groups');
    } catch (_) {
      if (mounted) _toast(WText.communitySendError, error: true);
    }
  }

  Future<void> _report(CommunityMessage message) async {
    final strings = WortwerkLocalizations.of(context);
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in <(String, WText)>[
              ('harassment', WText.communityReasonHarassment),
              ('spam', WText.communityReasonSpam),
              ('unsafe', WText.communityReasonUnsafe),
              ('other', WText.communityReasonOther),
            ])
              ListTile(
                title: Text(strings(entry.$2)),
                onTap: () => Navigator.pop(context, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await widget.repository.reportMessage(
        groupId: widget.groupId,
        messageId: message.id,
        reason: reason,
      );
      if (mounted) _toast(WText.communityReportSent);
    } catch (_) {
      if (mounted) _toast(WText.communitySendError, error: true);
    }
  }

  Future<void> _block(CommunityMessage message) async {
    try {
      await widget.repository.blockMember(message.uid);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _toast(WText.communitySendError, error: true);
    }
  }

  void _toast(WText key, {bool error = false}) {
    final strings = WortwerkLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings(key)),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LearningGroup?>(
    stream: widget.repository.watchGroup(widget.groupId),
    builder: (context, groupSnapshot) {
      if (groupSnapshot.hasError) return _communityPageError(context);
      final group = groupSnapshot.data;
      if (groupSnapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (group == null) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Text(
              WortwerkLocalizations.of(context)(WText.communityNoGroups),
            ),
          ),
        );
      }
      return StreamBuilder<bool>(
        stream: widget.repository.watchMembership(widget.groupId),
        builder: (context, membershipSnapshot) {
          if (membershipSnapshot.hasError) return _communityPageError(context);
          if (membershipSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (membershipSnapshot.data != true) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      WortwerkLocalizations.of(context)(
                        WText.communityNotMember,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.go('/groups'),
                      child: Text(
                        WortwerkLocalizations.of(context)(
                          WText.communityDiscover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return _chatScaffold(context, group);
        },
      );
    },
  );

  Widget _chatScaffold(BuildContext context, LearningGroup group) {
    final strings = WortwerkLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings(WText.communityBack),
          onPressed: () => context.go('/groups'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(group.level, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: strings(WText.communityLeave),
            onSelected: (value) {
              if (value == 'leave') _leave();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'leave',
                child: Text(strings(WText.communityLeave)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<Set<String>>(
                stream: widget.repository.watchBlockedUids(),
                builder: (context, blockedSnapshot) {
                  if (blockedSnapshot.hasError) {
                    return _communityPageError(context);
                  }
                  if (!blockedSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return StreamBuilder<List<CommunityMessage>>(
                    stream: widget.repository.watchMessages(widget.groupId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _communityPageError(context);
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final blocked = blockedSnapshot.data!;
                      final messages = snapshot.data!
                          .where(
                            (message) =>
                                message.uid == widget.repository.currentUid ||
                                !blocked.contains(message.uid),
                          )
                          .toList();
                      if (messages.isEmpty && _pendingBody == null) {
                        return Center(
                          child: Text(strings(WText.communityNoMessages)),
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                        itemCount:
                            messages.length + (_pendingBody == null ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index == 0 && _pendingBody != null) {
                            return _MessageBubble(
                              displayName: strings(WText.communityYou),
                              body: _pendingBody!,
                              mine: true,
                              pending: _sending,
                            );
                          }
                          final message = messages.reversed.elementAt(
                            index - (_pendingBody == null ? 0 : 1),
                          );
                          final mine =
                              message.uid == widget.repository.currentUid;
                          return _MessageBubble(
                            displayName: mine
                                ? strings(WText.communityYou)
                                : message.displayName,
                            body: message.body,
                            mine: mine,
                            onMenu: mine ? null : () => _messageMenu(message),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_sendFailure != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _sendFailure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: strings(WText.communityMessageHint),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        counterText: '',
                      ),
                      onChanged: (_) {
                        if (_pendingBody != null) {
                          setState(() {
                            _pendingBody = null;
                            _pendingRequestId = null;
                          });
                        }
                      },
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: strings(WText.communitySend),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _messageMenu(CommunityMessage message) async {
    final strings = WortwerkLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(strings(WText.communityReport)),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            ListTile(
              title: Text(strings(WText.communityBlock)),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );
    if (action == 'report') {
      await _report(message);
    }
    if (action == 'block') {
      await _block(message);
    }
  }
}

Widget _communityPageError(BuildContext context) {
  final strings = WortwerkLocalizations.of(context);
  return Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(strings(WText.communityLoadError)),
      ),
    ),
  );
}

final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.displayName,
    required this.body,
    required this.mine,
    this.pending = false,
    this.onMenu,
  });

  final String displayName;
  final String body;
  final bool mine;
  final bool pending;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final bubble = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: FlatCard(
          color: mine ? WortwerkColors.a1 : WortwerkColors.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) ...[
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
              ],
              Text(body),
              if (pending)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (onMenu == null) return bubble;
    return GestureDetector(onLongPress: onMenu, child: bubble);
  }
}
