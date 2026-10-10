import 'package:flutter/material.dart';

/// Wraps [child] in a [MaterialApp] and optionally forces reduced motion.
///
/// Mirrors how the real app reads `MediaQuery.disableAnimations`, so every
/// primitive can be exercised on both the motion and no-motion paths.
Widget animationHost(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}
