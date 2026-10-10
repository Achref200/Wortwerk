import 'package:wortwerk/core/l10n/localized_text.dart';
import 'package:flutter/material.dart';

import '../../design_system/wortwerk_theme.dart';
import 'network_status_controller.dart';

final class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({
    required this.controller,
    required this.child,
    super.key,
  });

  final NetworkStatusController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final reduceMotion = MediaQuery.of(context).disableAnimations;
        return Column(
          children: [
            AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: controller.isOffline
                  ? SafeArea(
                      bottom: false,
                      child: Semantics(
                        liveRegion: true,
                        label: 'Keine Netzwerkverbindung erkannt',
                        child: Container(
                          key: const ValueKey('network-offline-banner'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: WortwerkColors.c2,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                size: 20,
                                color: WortwerkColors.ink,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: LocalizedText(
                                  'Keine Verbindung erkannt. Laden und '
                                  'Speichern sind möglicherweise eingeschränkt.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Verbindung erneut prüfen',
                                onPressed: controller.refresh,
                                icon: const Icon(Icons.refresh_rounded),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
