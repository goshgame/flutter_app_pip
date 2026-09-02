import 'package:flutter/widgets.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default compact geometry keeps portrait window inside screen', () {
    final geometry = FlutterAppPipGeometry.defaultCompact(
      screenSize: const Size(400, 800),
      config: const FlutterAppPipOverlayConfig(),
    );

    expect(geometry.rect.left, 250);
    expect(geometry.rect.top, closeTo(556.67, 0.01));
    expect(geometry.rect.width, 140);
    expect(geometry.rect.height, closeTo(233.33, 0.01));
  });

  test('snapToHorizontalEdge clamps rect inside screen', () {
    const geometry = FlutterAppPipGeometry(
      screenSize: Size(400, 800),
      rect: Rect.fromLTWH(310, -20, 120, 180),
    );

    final snapped = geometry.snapToHorizontalEdge();

    expect(snapped.rect, const Rect.fromLTWH(280, 0, 120, 180));
  });

  test('avoidCollision moves window above conflicting rect when possible', () {
    const geometry = FlutterAppPipGeometry(
      screenSize: Size(400, 800),
      rect: Rect.fromLTWH(260, 600, 120, 180),
    );

    final avoided = geometry.avoidCollision(
      const Rect.fromLTWH(0, 700, 400, 100),
      padding: 10,
    );

    expect(avoided.rect.bottom <= 690, true);
  });

  test('default compact geometry respects safe area padding', () {
    final geometry = FlutterAppPipGeometry.defaultCompact(
      screenSize: const Size(400, 800),
      config: const FlutterAppPipOverlayConfig(
        safeAreaPadding: EdgeInsets.fromLTRB(24, 32, 18, 48),
      ),
    );

    expect(geometry.rect.right <= 382, true);
    expect(geometry.rect.bottom <= 752, true);
  });

  test('resizeByScale keeps center and clamps to configured min and max size', () {
    const geometry = FlutterAppPipGeometry(
      screenSize: Size(400, 800),
      rect: Rect.fromLTWH(100, 300, 120, 180),
    );
    const config = FlutterAppPipOverlayConfig(
      aspectRatio: 2 / 3,
      minSize: Size(90, 135),
      maxSize: Size(180, 270),
    );

    final expanded = geometry.resizeByScale(2, config: config);
    final shrunk = geometry.resizeByScale(0.2, config: config);

    expect(expanded.rect.size, const Size(180, 270));
    expect(expanded.rect.center, geometry.rect.center);
    expect(shrunk.rect.size, const Size(90, 135));
    expect(shrunk.rect.center, geometry.rect.center);
  });
}
