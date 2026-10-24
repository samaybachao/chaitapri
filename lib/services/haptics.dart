import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Short vibrations for taps and rewards. Can be switched off in Settings.
class Haptics {
  Haptics({this.enabled = true});

  /// Mirrors the "Vibration" switch in Settings.
  bool enabled;

  /// A very light tick for every tap on the kettle.
  void tap() => _run(HapticFeedback.selectionClick);

  /// A bit stronger: bought something, collected coins.
  void reward() => _run(HapticFeedback.lightImpact);

  void _run(Future<void> Function() feedback) {
    if (!enabled) {
      return;
    }
    try {
      unawaited(feedback().catchError((Object error) {
        debugPrint('Haptic feedback failed: $error');
      }));
    } catch (error) {
      debugPrint('Haptic feedback failed: $error');
    }
  }
}
