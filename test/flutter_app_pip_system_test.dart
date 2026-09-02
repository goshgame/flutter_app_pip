import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startSystem enters outOfApp when platform start succeeds', () async {
    final platform = _FakeSystemPipPlatform(supported: true, startResult: true);
    final controller = FlutterAppPipController(systemPlatform: platform);
    addTearDown(controller.dispose);

    final started = await controller.startSystem(
      const FlutterAppSystemPipConfig(aspectRatio: Size(9, 16)),
    );

    expect(started, true);
    expect(platform.startCalls, 1);
    expect(controller.mode.value, FlutterAppPipMode.outOfApp);
    expect(controller.isSystemActive.value, true);
  });

  test('unsupported start leaves mode unchanged', () async {
    final controller = FlutterAppPipController(
      systemPlatform: _FakeSystemPipPlatform(supported: false, startResult: true),
    );
    addTearDown(controller.dispose);

    final started = await controller.startSystem(const FlutterAppSystemPipConfig());

    expect(started, false);
    expect(controller.mode.value, FlutterAppPipMode.none);
    expect(controller.isSystemActive.value, false);
  });

  test('enableAutoEnterSystem does not switch mode before native active callback', () async {
    final platform = _FakeSystemPipPlatform(supported: true, startResult: true);
    final controller = FlutterAppPipController(systemPlatform: platform);
    addTearDown(controller.dispose);

    final enabled = await controller.enableAutoEnterSystem(const FlutterAppSystemPipConfig());

    expect(enabled, true);
    expect(controller.isAutoEnterEnabled.value, true);
    expect(controller.mode.value, FlutterAppPipMode.none);

    controller.syncSystemActive(true);
    expect(controller.mode.value, FlutterAppPipMode.outOfApp);
    expect(controller.isSystemActive.value, true);

    controller.syncSystemActive(false);
    expect(controller.mode.value, FlutterAppPipMode.none);
    expect(controller.isSystemActive.value, false);
  });

  test('controller forwards native system events after syncing state', () async {
    final platform = _FakeSystemPipPlatform(supported: true, startResult: true);
    final controller = FlutterAppPipController(systemPlatform: platform);
    addTearDown(controller.dispose);
    final events = <FlutterAppSystemPipEvent>[];
    final subscription = controller.systemEvents.listen(events.add);
    addTearDown(subscription.cancel);

    platform.emit(FlutterAppSystemPipEvent.activeChanged(true));
    await Future<void>.delayed(Duration.zero);

    expect(controller.isSystemActive.value, true);
    expect(events.single.type, FlutterAppSystemPipEventType.activeChanged);
    expect(events.single.active, true);
  });

  testWidgets('method channel platform serializes native pip config', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(MethodChannelFlutterAppSystemPipPlatform.channelName),
      (call) async {
        calls.add(call);
        return true;
      },
    );

    final platform = MethodChannelFlutterAppSystemPipPlatform();

    final started = await platform.start(
      const FlutterAppSystemPipConfig(
        aspectRatio: Size(9, 16),
        sourceRectHint: Rect.fromLTWH(1, 2, 3, 4),
        videoUrl: 'https://example.com/video.mp4',
        goHome: true,
      ),
    );

    expect(started, true);
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, containsPair('aspectWidth', 9.0));
    expect(calls.single.arguments, containsPair('aspectHeight', 16.0));
    expect(calls.single.arguments, containsPair('sourceLeft', 1.0));
    expect(calls.single.arguments, containsPair('sourceBottom', 6.0));
    expect(calls.single.arguments, containsPair('videoUrl', 'https://example.com/video.mp4'));
    expect(calls.single.arguments, containsPair('goHome', true));
  });

  testWidgets('default controller uses method channel system platform', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(MethodChannelFlutterAppSystemPipPlatform.channelName),
      (call) async {
        calls.add(call);
        return true;
      },
    );

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);

    final supported = await controller.checkSystemSupported();

    expect(supported, true);
    expect(calls.single.method, 'isSupported');
  });

  testWidgets('method channel platform forwards native active callback', (tester) async {
    final channel = const MethodChannel(MethodChannelFlutterAppSystemPipPlatform.channelName);
    final events = <FlutterAppSystemPipEvent>[];
    final platform = MethodChannelFlutterAppSystemPipPlatform(channel: channel);
    final subscription = platform.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(platform.dispose);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      MethodChannelFlutterAppSystemPipPlatform.channelName,
      channel.codec.encodeMethodCall(
        const MethodCall('onActiveChanged', {'active': true}),
      ),
      (_) {},
    );

    expect(events.single.type, FlutterAppSystemPipEventType.activeChanged);
    expect(events.single.active, true);
  });

  testWidgets('method channel platform forwards native prepare auto enter callback', (tester) async {
    final channel = const MethodChannel(MethodChannelFlutterAppSystemPipPlatform.channelName);
    final events = <FlutterAppSystemPipEvent>[];
    final platform = MethodChannelFlutterAppSystemPipPlatform(channel: channel);
    final subscription = platform.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(platform.dispose);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      MethodChannelFlutterAppSystemPipPlatform.channelName,
      channel.codec.encodeMethodCall(const MethodCall('onPrepareAutoEnter')),
      (_) {},
    );

    expect(events.single.type, FlutterAppSystemPipEventType.prepareAutoEnter);
  });
}

class _FakeSystemPipPlatform implements FlutterAppSystemPipPlatform {
  _FakeSystemPipPlatform({required this.supported, required this.startResult});

  final bool supported;
  final bool startResult;
  final StreamController<FlutterAppSystemPipEvent> _events =
      StreamController<FlutterAppSystemPipEvent>.broadcast();
  int startCalls = 0;

  @override
  Stream<FlutterAppSystemPipEvent> get events => _events.stream;

  void emit(FlutterAppSystemPipEvent event) {
    _events.add(event);
  }

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> isAutoEnterSupported() async => supported;

  @override
  Future<bool> start(FlutterAppSystemPipConfig config) async {
    startCalls += 1;
    return startResult;
  }

  @override
  Future<bool> enableAutoEnter(FlutterAppSystemPipConfig config) async => supported;

  @override
  Future<bool> completeAutoEnterPreparation() async => true;

  @override
  Future<bool> disableAutoEnter() async => true;

  @override
  Future<bool> stop() async => true;

  @override
  void dispose() {
    _events.close();
  }
}
