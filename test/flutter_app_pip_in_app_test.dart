import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scope renders pip above a child overlay', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    var overlayTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) {
          return FlutterAppPipScope(
            controller: controller,
            navigatorKey: navigatorKey,
            child: Overlay(
              initialEntries: [
                OverlayEntry(builder: (_) => child!),
                OverlayEntry(
                  builder: (_) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => overlayTaps += 1,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
        home: const Scaffold(body: Text('home')),
      ),
    );

    controller.showInApp(
      builder: (_, __) => ColoredBox(
        key: const ValueKey('root-pip-surface'),
        color: Colors.black,
        child: const Tooltip(
          message: 'root pip tooltip',
          child: Text('root pip'),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('root pip'), findsOneWidget);
    expect(find.byTooltip('root pip tooltip'), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('root-pip-surface'))),
    );
    await tester.pump();

    expect(overlayTaps, 0);
    expect(controller.mode.value, FlutterAppPipMode.none);
  });

  testWidgets('showInApp inserts overlay and tap restores fullscreen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    final shown = controller.showInApp(
      builder: (_, __) => const ColoredBox(
        key: ValueKey('pip-surface'),
        color: Colors.black,
        child: SizedBox.expand(child: Text('pip')),
      ),
    );
    await tester.pump();

    expect(shown, true);
    expect(controller.mode.value, FlutterAppPipMode.inApp);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('pip'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('pip-surface'))).width, 140);

    await tester.tap(find.text('pip'));
    await tester.pump();

    expect(controller.mode.value, FlutterAppPipMode.none);
  });

  testWidgets('updateInAppConfig changes compact window size', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    controller.showInApp(
      builder: (_, __) => const SizedBox.expand(key: ValueKey('pip-surface')),
    );
    await tester.pump();

    controller.updateInAppConfig(
      const FlutterAppPipOverlayConfig(width: 200, height: 120),
    );
    await tester.pump();

    expect(tester.getSize(find.byKey(const ValueKey('pip-surface'))), const Size(200, 120));
  });

  testWidgets('avoidCollision moves compact window above obstacle', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    controller.showInApp(
      config: const FlutterAppPipOverlayConfig(width: 120, height: 180),
      builder: (_, __) => const SizedBox.expand(key: ValueKey('pip-surface')),
    );
    await tester.pump();

    controller.avoidCollision(const Rect.fromLTWH(0, 700, 400, 100), padding: 10);
    await tester.pump();

    final topLeft = tester.getTopLeft(find.byKey(const ValueKey('pip-surface')));
    final size = tester.getSize(find.byKey(const ValueKey('pip-surface')));
    expect(topLeft.dy + size.height <= 690, true);
  });

  testWidgets('resizable overlay scales with a two finger gesture', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    controller.showInApp(
      config: const FlutterAppPipOverlayConfig(
        width: 120,
        height: 180,
        aspectRatio: 2 / 3,
        resizable: true,
        minSize: Size(90, 135),
        maxSize: Size(220, 330),
      ),
      builder: (_, __) => const SizedBox.expand(key: ValueKey('pip-surface')),
    );
    await tester.pump();

    final surface = find.byKey(const ValueKey('pip-surface'));
    final initialSize = tester.getSize(surface);
    final center = tester.getCenter(surface);
    final firstFinger = await tester.createGesture(pointer: 1);
    final secondFinger = await tester.createGesture(pointer: 2);
    addTearDown(firstFinger.removePointer);
    addTearDown(secondFinger.removePointer);

    await firstFinger.down(center + const Offset(-20, 0));
    await secondFinger.down(center + const Offset(20, 0));
    await tester.pump();
    await firstFinger.moveBy(const Offset(-30, 0));
    await secondFinger.moveBy(const Offset(30, 0));
    await tester.pump();
    await firstFinger.up();
    await secondFinger.up();
    await tester.pump();

    final resized = tester.getSize(surface);
    expect(resized.width > initialSize.width, true);
    expect(resized.height > initialSize.height, true);
  });

  testWidgets('reopening in-app pip restores its last position', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);
    final positions = <Offset?>[];
    controller.inAppPositionListenable.addListener(() {
      positions.add(controller.inAppPosition);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    const config = FlutterAppPipOverlayConfig(width: 120, height: 180);
    controller.showInApp(
      config: config,
      builder: (_, __) => const SizedBox.expand(key: ValueKey('pip-surface')),
    );
    await tester.pump();

    final surface = find.byKey(const ValueKey('pip-surface'));
    final initialPosition = tester.getTopLeft(surface);
    final gesture = await tester.startGesture(tester.getCenter(surface));
    await gesture.moveBy(const Offset(0, -180));
    await gesture.up();
    await tester.pump();

    final movedPosition = tester.getTopLeft(surface);
    expect(movedPosition.dy, lessThan(initialPosition.dy));
    expect(controller.inAppPosition, movedPosition);
    expect(positions, [movedPosition]);

    controller.closeInApp();
    await tester.pump();
    controller.showInApp(
      config: config,
      builder: (_, __) => const SizedBox.expand(key: ValueKey('pip-surface')),
    );
    await tester.pump();

    expect(tester.getTopLeft(surface), movedPosition);
  });

  testWidgets('drag keeps compact window inside safe area before release', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final controller = FlutterAppPipController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterAppPipScope(
          controller: controller,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    controller.showInApp(
      config: const FlutterAppPipOverlayConfig(
        width: 120,
        height: 180,
        safeAreaPadding: EdgeInsets.fromLTRB(12, 24, 16, 20),
        snapToEdge: false,
      ),
      builder: (_, __) => const SizedBox.expand(
        key: ValueKey('pip-surface'),
      ),
    );
    await tester.pump();

    final surface = find.byKey(const ValueKey('pip-surface'));
    final gesture = await tester.startGesture(tester.getCenter(surface));
    await gesture.moveBy(const Offset(-500, -900));
    await tester.pump();
    expect(tester.getRect(surface).topLeft, const Offset(12, 24));

    await gesture.moveBy(const Offset(20, 20));
    await tester.pump();
    expect(tester.getRect(surface).topLeft, const Offset(32, 44));

    await gesture.moveBy(const Offset(1000, 1600));
    await tester.pump();
    final bottomRightRect = tester.getRect(surface);
    expect(bottomRightRect.right, 384);
    expect(bottomRightRect.bottom, 780);

    await gesture.up();
  });
}
