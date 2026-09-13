import 'dart:math' as math;

import 'package:flutter/material.dart';

// Applies the user-selected gamma correction. Values below 1.0 brighten dark
// game LED output while preserving the channel relationships.
Color? gameLedColor(int red, int green, int blue, {required double gamma}) {
  if (red == 0 && green == 0 && blue == 0) return null;

  int correctChannel(int value) {
    final clamped = value.clamp(0, 255);
    if (clamped == 0) return 0;
    final normalized = clamped / 255.0;
    return (math.pow(normalized, gamma) * 255).round().clamp(0, 255);
  }

  return Color.fromARGB(
    255,
    correctChannel(red),
    correctChannel(green),
    correctChannel(blue),
  );
}
