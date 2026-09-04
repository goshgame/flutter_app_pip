import 'flutter_app_system_pip_action.dart';

enum FlutterAppSystemPipEventType {
  activeChanged,
  startFailed,
  unsupported,
  restoreRequested,
  prepareAutoEnter,
  action,
}

class FlutterAppSystemPipEvent {
  const FlutterAppSystemPipEvent({
    required this.type,
    this.active,
    this.message,
    this.action,
    this.seekOffset,
  });

  final FlutterAppSystemPipEventType type;
  final bool? active;
  final String? message;
  final FlutterAppSystemPipAction? action;
  final Duration? seekOffset;

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

  static FlutterAppSystemPipEvent actionTriggered(
    FlutterAppSystemPipAction action, {
    Duration? seekOffset,
  }) {
    return FlutterAppSystemPipEvent(
      type: FlutterAppSystemPipEventType.action,
      action: action,
      seekOffset: seekOffset,
    );
  }
}
