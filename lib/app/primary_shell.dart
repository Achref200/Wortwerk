import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/glass_navigation_bar.dart';
import '../features/fritz/presentation/fritz_ai_sheet.dart';

final class WortwerkPrimaryShell extends StatelessWidget {
  const WortwerkPrimaryShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    final isGroupConversation = currentPath.startsWith('/groups/');
    return Scaffold(
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: isGroupConversation
          ? null
          : GlassNavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              onFritzPressed: () => FritzAiSheet.show(
                context,
                onStartTutor: (prompt) {
                  Navigator.of(context).pop();
                  final query = Uri(
                    queryParameters: {
                      'prompt': prompt.text,
                      'mode': prompt.mode,
                      'thread':
                          'chat_${DateTime.now().toUtc().microsecondsSinceEpoch}',
                    },
                  ).query;
                  context.push('/tutor?$query');
                },
              ),
            ),
    );
  }
}
