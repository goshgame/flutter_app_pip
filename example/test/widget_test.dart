import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';
import 'package:flutter_app_pip_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(MethodChannelFlutterAppSystemPipPlatform.channelName),
      (_) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(MethodChannelFlutterAppSystemPipPlatform.channelName),
      null,
    );
  });

  testWidgets('example app renders debug surface', (tester) async {
    await tester.pumpWidget(FlutterAppPipExampleApp(liveSession: _FakeLiveVideoSession()));

    expect(find.text('flutter_app_pip'), findsOneWidget);
    expect(find.text('Enter live room'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('In-app'), 200);
    expect(find.text('In-app'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('System'), 200);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('migration demo moves one player state from page to home pip', (tester) async {
    await tester.pumpWidget(FlutterAppPipExampleApp(liveSession: _FakeLiveVideoSession()));

    await tester.scrollUntilVisible(find.text('Open migration demo'), 200);
    await tester.tap(find.text('Open migration demo'));
    await tester.pumpAndSettle();

    expect(find.text('State Migration Live'), findsOneWidget);
    expect(find.text('PAGE HOST'), findsOneWidget);
    final instanceText = tester.widget<Text>(
      find.byKey(const ValueKey('state-migration-instance')),
    ).data;
    expect(instanceText, isNotNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('flutter_app_pip'), findsOneWidget);
    expect(find.text('PIP HOST'), findsOneWidget);
    expect(find.text(instanceText!), findsOneWidget);
    expect(find.text('fake live video'), findsOneWidget);

    await tester.tap(find.byTooltip('Restore migration live page'));
    await tester.pumpAndSettle();

    expect(find.text('State Migration Live'), findsOneWidget);
    expect(find.text('PAGE HOST'), findsOneWidget);
    expect(find.text(instanceText), findsOneWidget);
    expect(find.text('fake live video'), findsOneWidget);
  });

  testWidgets('migration demo keeps pip visible after opening another page', (tester) async {
    await tester.pumpWidget(FlutterAppPipExampleApp(liveSession: _FakeLiveVideoSession()));

    await tester.scrollUntilVisible(find.text('Open migration demo'), 200);
    await tester.tap(find.text('Open migration demo'));
    await tester.pumpAndSettle();

    final instanceText = tester.widget<Text>(
      find.byKey(const ValueKey('state-migration-instance')),
    ).data;
    await tester.tap(find.byTooltip('Open another page with PiP'));
    await tester.pumpAndSettle();

    expect(find.text('Another Page'), findsOneWidget);
    expect(find.text('PIP HOST'), findsOneWidget);
    expect(find.text(instanceText!), findsOneWidget);
    expect(find.text('fake live video'), findsOneWidget);

    await tester.tap(find.byTooltip('Restore migration live page'));
    await tester.pumpAndSettle();

    expect(find.text('State Migration Live'), findsOneWidget);
    expect(find.text('PAGE HOST'), findsOneWidget);
    expect(find.text(instanceText), findsOneWidget);
  });

  testWidgets('live room returns into in-app pip and expands back to route', (tester) async {
    await tester.pumpWidget(FlutterAppPipExampleApp(liveSession: _FakeLiveVideoSession()));

    await tester.tap(find.text('Enter live room'));
    await tester.pumpAndSettle();

    expect(find.text('GOSH Live Room'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.byKey(const ValueKey('live-pip-flight')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-pip-flight-snapshot')), findsOneWidget);
    expect(find.text('Live PiP'), findsOneWidget);
    expect(find.text('fake live video'), findsNWidgets(1));

    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const ValueKey('live-pip-flight')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-pip-flight-snapshot')), findsOneWidget);
    expect(find.text('Live PiP'), findsOneWidget);
    expect(find.text('fake live video'), findsNWidgets(1));

    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const ValueKey('live-pip-flight')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Live PiP'), findsOneWidget);
    expect(find.text('fake live video'), findsOneWidget);
    final livePip = find.byKey(const ValueKey('live-pip-surface'));
    final livePipSize = tester.getSize(livePip);
    final livePipTopLeft = tester.getTopLeft(livePip);
    expect(livePipSize.width, greaterThan(280));
    expect(livePipSize.width / livePipSize.height, closeTo(16 / 9, 0.02));
    expect(livePipTopLeft.dx, lessThan(32));

    await tester.tap(find.byTooltip('Expand live room'));
    await tester.pump();

    expect(find.byKey(const ValueKey('live-pip-flight')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-pip-flight-snapshot')), findsOneWidget);
    expect(find.text('fake live video'), findsNWidgets(1));

    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const ValueKey('live-pip-flight')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('GOSH Live Room'), findsOneWidget);
    expect(find.text('fake live video'), findsOneWidget);
  });

  testWidgets('slow screenshot does not block live room to pip flight', (tester) async {
    final screenshot = Completer<Uint8List?>();
    await tester.pumpWidget(
      FlutterAppPipExampleApp(
        liveSession: _FakeLiveVideoSession(screenshotResult: screenshot.future),
      ),
    );

    await tester.tap(find.text('Enter live room'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.byKey(const ValueKey('live-pip-flight')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-pip-flight-snapshot')), findsOneWidget);
    expect(find.text('Live PiP'), findsOneWidget);

    screenshot.complete(Uint8List.fromList(_transparentPng));
    await tester.pumpAndSettle();
  });

  testWidgets('background system pip uses a video-only surface', (tester) async {
    await tester.pumpWidget(FlutterAppPipExampleApp(liveSession: _FakeLiveVideoSession()));

    await tester.tap(find.text('Enter live room'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byKey(const ValueKey('live-system-pip-surface')), findsOneWidget);
    expect(find.text('fake live video'), findsNWidgets(1));
  });

  testWidgets('manual system pip starts from a video-only surface', (tester) async {
    await tester.pumpWidget(FlutterAppPipExampleApp(liveSession: _FakeLiveVideoSession()));

    await tester.tap(find.text('Enter live room'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Start system PiP'));
    await tester.pump();

    expect(find.byKey(const ValueKey('live-system-pip-surface')), findsOneWidget);
    expect(find.text('fake live video'), findsNWidgets(1));
  });

  testWidgets('native prepare auto enter switches to a video-only surface', (tester) async {
    await tester.pumpWidget(FlutterAppPipExampleApp(liveSession: _FakeLiveVideoSession()));

    await tester.tap(find.text('Enter live room'));
    await tester.pumpAndSettle();

    const channel = MethodChannel(MethodChannelFlutterAppSystemPipPlatform.channelName);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      MethodChannelFlutterAppSystemPipPlatform.channelName,
      channel.codec.encodeMethodCall(const MethodCall('onPrepareAutoEnter')),
      (_) {},
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('live-system-pip-surface')), findsOneWidget);
    expect(find.text('fake live video'), findsNWidgets(1));
  });
}

class _FakeLiveVideoSession implements LiveVideoSession {
  _FakeLiveVideoSession({this.screenshotResult});

  final Future<Uint8List?>? screenshotResult;

  @override
  Future<void> open() async {}

  @override
  Widget buildVideo({Key? key}) {
    return ColoredBox(
      key: key,
      color: Colors.black,
      child: const Center(child: Text('fake live video')),
    );
  }

  @override
  Future<Uint8List?> screenshot() async {
    return screenshotResult ?? Uint8List.fromList(_transparentPng);
  }

  @override
  Future<void> dispose() async {}
}

const List<int> _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
