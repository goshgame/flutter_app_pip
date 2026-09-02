import 'flutter_app_system_pip_config.dart';
import 'flutter_app_system_pip_event.dart';

abstract interface class FlutterAppSystemPipPlatform {
  Stream<FlutterAppSystemPipEvent> get events;

  Future<bool> isSupported();

  Future<bool> isAutoEnterSupported();

  Future<bool> start(FlutterAppSystemPipConfig config);

  Future<bool> enableAutoEnter(FlutterAppSystemPipConfig config);

  Future<bool> completeAutoEnterPreparation();

  Future<bool> disableAutoEnter();

  Future<bool> stop();

  void dispose();
}

class UnsupportedFlutterAppSystemPipPlatform implements FlutterAppSystemPipPlatform {
  const UnsupportedFlutterAppSystemPipPlatform();

  @override
  Stream<FlutterAppSystemPipEvent> get events => const Stream.empty();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> isAutoEnterSupported() async => false;

  @override
  Future<bool> start(FlutterAppSystemPipConfig config) async => false;

  @override
  Future<bool> enableAutoEnter(FlutterAppSystemPipConfig config) async => false;

  @override
  Future<bool> completeAutoEnterPreparation() async => false;

  @override
  Future<bool> disableAutoEnter() async => false;

  @override
  Future<bool> stop() async => false;

  @override
  void dispose() {}
}
