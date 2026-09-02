enum FlutterAppSystemPipEventType {
  activeChanged,
  startFailed,
  unsupported,
  restoreRequested,
  prepareAutoEnter,
}

class FlutterAppSystemPipEvent {
  const FlutterAppSystemPipEvent({
    required this.type,
    this.active,
    this.message,
  });

  final FlutterAppSystemPipEventType type;
  final bool? active;
  final String? message;

  static FlutterAppSystemPipEvent activeChanged(bool active) {
    return FlutterAppSystemPipEvent(
      type: FlutterAppSystemPipEventType.activeChanged,
      active: active,
    );
  }

  static FlutterAppSystemPipEvent startFailed([String? message]) {
    return FlutterAppSystemPipEvent(
      type: FlutterAppSystemPipEventType.startFailed,
      message: message,
    );
  }

  static FlutterAppSystemPipEvent unsupported([String? message]) {
    return FlutterAppSystemPipEvent(
      type: FlutterAppSystemPipEventType.unsupported,
      message: message,
    );
  }

  static const restoreRequested = FlutterAppSystemPipEvent(
    type: FlutterAppSystemPipEventType.restoreRequested,
  );

  static const prepareAutoEnter = FlutterAppSystemPipEvent(
    type: FlutterAppSystemPipEventType.prepareAutoEnter,
  );
}
