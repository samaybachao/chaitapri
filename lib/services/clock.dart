/// Source of the current time. Tests replace it to travel through time.
abstract class Clock {
  /// Current wall-clock time in milliseconds since the Unix epoch.
  int nowMs();

  /// Current local time.
  DateTime nowLocal();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  int nowMs() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  @override
  DateTime nowLocal() {
    return DateTime.now();
  }
}

/// A clock you can set and move forward (tests).
class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start;

  DateTime _now;

  /// Moves the clock forward.
  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  /// Sets the clock to [time].
  void setTo(DateTime time) {
    _now = time;
  }

  @override
  int nowMs() {
    return _now.millisecondsSinceEpoch;
  }

  @override
  DateTime nowLocal() {
    return _now;
  }
}
