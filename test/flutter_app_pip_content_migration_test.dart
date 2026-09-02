import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    _TrackedPlayerState.initCount = 0;
  });

  testWidgets('moves the same player state between page and in-app pip', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    expect(controller.attachContentToPage(), true);

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: Scaffold(
            body: FlutterAppPipPageSlot(
              controller: controller,
              builder: (_, contentKey) => _TrackedPlayer(
                key: contentKey,
                label: 'page-player',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('page-player'), findsOneWidget);
    expect(_TrackedPlayerState.initCount, 1);

    var restoreRequests = 0;
    final moveFuture = controller.moveContentToInApp(
      onRestoreRequested: () => restoreRequests += 1,
      builder: (_, contentKey) => _TrackedPlayer(
        key: contentKey,
        label: 'pip-player',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(await moveFuture, true);

    expect(controller.contentHost.value, FlutterAppPipContentHost.inApp);
    expect(find.text('page-player'), findsNothing);
    expect(find.text('pip-player'), findsOneWidget);
    expect(_TrackedPlayerState.initCount, 1);

    await tester.tap(find.text('pip-player'));
    await tester.pump();
    expect(restoreRequests, 1);
    expect(controller.contentHost.value, FlutterAppPipContentHost.inApp);

    final restoreFuture = controller.restoreContentToPage();
    await tester.pump();
    expect(await restoreFuture, true);
    await tester.pump();

    expect(controller.contentHost.value, FlutterAppPipContentHost.page);
    expect(find.text('page-player'), findsOneWidget);
    expect(find.text('pip-player'), findsNothing);
    expect(_TrackedPlayerState.initCount, 1);
  });

  testWidgets('keeps the overlay player mounted across system pip state', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    controller.attachContentToPage();

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: FlutterAppPipPageSlot(
            controller: controller,
            builder: (_, contentKey) => _TrackedPlayer(
              key: contentKey,
              label: 'page-player',
            ),
          ),
        ),
      ),
    );

    const compactConfig = FlutterAppPipOverlayConfig(
      width: 120,
      height: 180,
    );
    final moveFuture = controller.moveContentToInApp(
      config: compactConfig,
      builder: (_, contentKey) => _TrackedPlayer(
        key: contentKey,
        label: 'pip-player',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(await moveFuture, true);

    controller.prepareContentForSystemRestore(
      host: FlutterAppPipContentHost.inApp,
      inAppConfig: compactConfig,
    );
    controller.updateInAppConfig(
      const FlutterAppPipOverlayConfig(
        width: 400,
        height: 800,
        initialRect: Rect.fromLTWH(0, 0, 400, 800),
      ),
    );
    tester.view.physicalSize = const Size(320, 180);
    controller.syncSystemActive(true);
    await tester.pump();

    expect(controller.contentHost.value, FlutterAppPipContentHost.outOfApp);
    expect(controller.mode.value, FlutterAppPipMode.outOfApp);
    expect(find.text('pip-player'), findsOneWidget);
    expect(tester.getSize(find.byKey(controller.contentKey)), const Size(320, 180));
    expect(_TrackedPlayerState.initCount, 1);

    controller.syncSystemActive(false);
    await tester.pump();

    expect(controller.contentHost.value, FlutterAppPipContentHost.inApp);
    expect(controller.mode.value, FlutterAppPipMode.inApp);
    expect(find.text('pip-player'), findsOneWidget);
    expect(tester.getSize(find.byKey(controller.contentKey)), const Size(120, 180));
    expect(_TrackedPlayerState.initCount, 1);
  });

  testWidgets('keeps prepared system content on the page until activation', (
    tester,
  ) async {
    _TrackedPlayerState.initCount = 0;
    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    controller.attachContentToPage();

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: FlutterAppPipPageSlot(
            controller: controller,
            builder: (_, contentKey) => _TrackedPlayer(
              key: contentKey,
              label: 'page-player',
            ),
          ),
        ),
      ),
    );

    final prepareFuture = controller.prepareContentToInApp(
      config: const FlutterAppPipOverlayConfig(
        transitionDuration: Duration.zero,
      ),
      builder: (_, contentKey) => _TrackedPlayer(
        key: contentKey,
        label: 'system-player',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(await prepareFuture, true);

    expect(controller.contentHost.value, FlutterAppPipContentHost.page);
    expect(controller.inAppEntry.value?.isPrepared, true);
    expect(find.text('page-player'), findsOneWidget);
    expect(find.text('system-player'), findsNothing);
    expect(_TrackedPlayerState.initCount, 1);

    controller.syncSystemActive(true);
    await tester.pump();
    expect(controller.contentHost.value, FlutterAppPipContentHost.page);

    final activateFuture = controller.activatePreparedContentHost();
    await tester.pump();
    await tester.pump();
    expect(await activateFuture, true);

    expect(controller.contentHost.value, FlutterAppPipContentHost.outOfApp);
    expect(find.text('page-player'), findsNothing);
    expect(find.text('system-player'), findsOneWidget);
    expect(_TrackedPlayerState.initCount, 1);
  });

  testWidgets('restores the page host without an in-app fullscreen frame', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    controller.attachContentToPage();

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: FlutterAppPipPageSlot(
                controller: controller,
                builder: (_, contentKey) => _TrackedPlayer(
                  key: contentKey,
                  label: 'page-player',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.prepareContentForSystemRestore(
      host: FlutterAppPipContentHost.page,
    );
    final moveFuture = controller.moveContentToInApp(
      config: const FlutterAppPipOverlayConfig(
        width: 400,
        height: 800,
        initialRect: Rect.fromLTWH(0, 0, 400, 800),
        transitionDuration: Duration.zero,
      ),
      builder: (_, contentKey) => _TrackedPlayer(
        key: contentKey,
        label: 'system-player',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(await moveFuture, true);

    controller.syncSystemActive(true);
    await tester.pump();
    controller.syncSystemActive(false);
    await tester.pump();

    expect(controller.contentHost.value, FlutterAppPipContentHost.page);
    expect(controller.mode.value, FlutterAppPipMode.none);
    expect(find.text('page-player'), findsOneWidget);
    expect(find.text('system-player'), findsNothing);
    expect(tester.getSize(find.byKey(controller.contentKey)), const Size(300, 200));
    expect(_TrackedPlayerState.initCount, 1);
  });

  testWidgets('detaches page content before its owner releases resources', (
    tester,
  ) async {
    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    controller.attachContentToPage();

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: FlutterAppPipPageSlot(
            controller: controller,
            builder: (_, contentKey) => _TrackedPlayer(
              key: contentKey,
              label: 'page-player',
            ),
          ),
        ),
      ),
    );

    controller.detachContent();
    await tester.pump();

    expect(controller.contentHost.value, FlutterAppPipContentHost.none);
    expect(find.text('page-player'), findsNothing);
  });

  testWidgets('animates content between page and in-app pip rects', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    controller.attachContentToPage();

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: FlutterAppPipPageSlot(
            controller: controller,
            builder: (_, contentKey) => _TrackedPlayer(
              key: contentKey,
              label: 'page-player',
            ),
          ),
        ),
      ),
    );

    const sourceRect = Rect.fromLTWH(20, 100, 300, 200);
    const duration = Duration(milliseconds: 300);
    final moveFuture = controller.moveContentToInApp(
      config: const FlutterAppPipOverlayConfig(
        width: 120,
        height: 180,
        transitionSourceRect: sourceRect,
        transitionDuration: duration,
      ),
      builder: (_, contentKey) => _TrackedPlayer(
        key: contentKey,
        label: 'pip-player',
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(await moveFuture, true);

    final surface = find.byKey(controller.contentKey);
    expect(tester.getSize(surface), sourceRect.size);
    final moveDuration = tester
        .widget<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>),
        )
        .duration;
    expect(moveDuration, lessThan(duration));
    expect(moveDuration, greaterThanOrEqualTo(const Duration(milliseconds: 80)));
    await tester.pump(
      Duration(microseconds: moveDuration.inMicroseconds ~/ 2),
    );
    final middleSize = tester.getSize(surface);
    expect(middleSize.width, lessThan(sourceRect.width));
    expect(middleSize.width, greaterThan(120));
    await tester.pump(moveDuration);

    final targetRect = tester.getRect(surface).shift(const Offset(-20, -20));
    final restoreFuture = controller.restoreContentToPage(targetRect: targetRect);
    bool? restoreResult;
    unawaited(restoreFuture.then((value) => restoreResult = value));
    await tester.pump();
    final restoreDuration = tester
        .widget<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>),
        )
        .duration;
    expect(restoreDuration, lessThan(moveDuration));
    await tester.pump(
      Duration(microseconds: restoreDuration.inMicroseconds ~/ 2),
    );
    expect(controller.contentHost.value, FlutterAppPipContentHost.inApp);
    await tester.pump(restoreDuration);
    await tester.pump();
    await tester.pump();
    if (restoreResult == null) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
    }
    expect(restoreResult, true);

    expect(controller.contentHost.value, FlutterAppPipContentHost.page);
    expect(find.text('page-player'), findsOneWidget);
    expect(_TrackedPlayerState.initCount, 1);
  });
}

class _TrackedPlayer extends StatefulWidget {
  const _TrackedPlayer({
    required super.key,
    required this.label,
  });

  final String label;

  @override
  State<_TrackedPlayer> createState() => _TrackedPlayerState();
}

class _TrackedPlayerState extends State<_TrackedPlayer> {
  static var initCount = 0;

  @override
  void initState() {
    super.initState();
    initCount += 1;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Text(widget.label),
    );
  }
}
