import 'package:flutter/foundation.dart';

/// Where game events go.
///
/// Version 1.0 collects nothing: the events are only printed in debug builds. A later
/// version can forward them to an analytics service (and the Play "Data safety" form
/// must then be updated) without touching the game code.
abstract class Analytics {
  void log(String event, [Map<String, Object?> parameters = const <String, Object?>{}]);
}

/// Prints events in debug builds only.
class DebugAnalytics implements Analytics {
  const DebugAnalytics();

  @override
  void log(String event, [Map<String, Object?> parameters = const <String, Object?>{}]) {
    if (kDebugMode) {
      debugPrint('[analytics] $event $parameters');
    }
  }
}
