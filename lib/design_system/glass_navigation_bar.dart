import 'package:wortwerk/core/l10n/localized_text.dart';

import 'dart:ui';

import 'package:flutter/material.dart';

import 'fritz_avatar.dart';
import 'wortwerk_theme.dart';

enum WortwerkTab {
  start('Start', Icons.home_outlined, Icons.home_rounded),
  path('Weg', Icons.route_outlined, Icons.route_rounded),
  groups('Gruppen', Icons.chat_bubble_outline, Icons.chat_bubble_rounded),
  profile('Profil', Icons.person_outline_rounded, Icons.person_rounded);

  const WortwerkTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

final class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.onFritzPressed,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onFritzPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _FrostedSurface(
              borderRadius: WortwerkRadii.pill,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < WortwerkTab.values.length;
                      index++
                    )
                      Expanded(
                        child: _TabButton(
                          tab: WortwerkTab.values[index],
                          selected: index == selectedIndex,
                          onPressed: () => onSelected(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _FrostedSurface(
            borderRadius: WortwerkRadii.pill,
            child: Semantics(
              button: true,
              label: 'Fritz fragen',
              child: IconButton(
                onPressed: onFritzPressed,
                tooltip: 'Fritz fragen',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 64,
                  height: 64,
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: WortwerkColors.a2,
                        shape: BoxShape.circle,
                        border: Border.all(color: WortwerkColors.ink, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: const FritzAvatar(size: 53),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: const BoxDecoration(
                          color: WortwerkColors.ink,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: WortwerkColors.c2,
                          size: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onPressed,
  });

  final WortwerkTab tab;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? WortwerkColors.ink : WortwerkColors.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        child: Material(
          color: selected ? const Color(0xCFF4F1EA) : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    color: color,
                    size: 23,
                  ),
                  const SizedBox(height: 2),
                  LocalizedText(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _FrostedSurface extends StatelessWidget {
  const _FrostedSurface({required this.borderRadius, required this.child});

  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: WortwerkColors.glass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0x551E1D22), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
