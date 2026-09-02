import 'dart:math';

import 'package:flutter/widgets.dart';

import 'flutter_app_pip_overlay_config.dart';

class FlutterAppPipGeometry {
  const FlutterAppPipGeometry({
    required this.screenSize,
    required this.rect,
  });

  final Size screenSize;
  final Rect rect;

  static FlutterAppPipGeometry defaultCompact({
    required Size screenSize,
    required FlutterAppPipOverlayConfig config,
  }) {
    final rect = config.initialRect ?? _defaultRect(screenSize, config);
    return FlutterAppPipGeometry(screenSize: screenSize, rect: rect).clampToScreen(
      safeAreaPadding: config.safeAreaPadding,
    );
  }

  FlutterAppPipGeometry moveBy(Offset delta) {
    return FlutterAppPipGeometry(
      screenSize: screenSize,
      rect: rect.shift(delta),
    );
  }

  FlutterAppPipGeometry clampToScreen({
    EdgeInsets safeAreaPadding = EdgeInsets.zero,
  }) {
    final minLeft = safeAreaPadding.left;
    final minTop = safeAreaPadding.top;
    final maxLeft = max(minLeft, screenSize.width - safeAreaPadding.right - rect.width);
    final maxTop = max(minTop, screenSize.height - safeAreaPadding.bottom - rect.height);
    final left = rect.left.clamp(minLeft, maxLeft).toDouble();
    final top = rect.top.clamp(minTop, maxTop).toDouble();
    return FlutterAppPipGeometry(
      screenSize: screenSize,
      rect: Rect.fromLTWH(left, top, rect.width, rect.height),
    );
  }

  FlutterAppPipGeometry snapToHorizontalEdge({
    EdgeInsets safeAreaPadding = EdgeInsets.zero,
  }) {
    final clamped = clampToScreen(safeAreaPadding: safeAreaPadding);
    final left = clamped.rect.center.dx > screenSize.width / 2
        ? max(safeAreaPadding.left, screenSize.width - safeAreaPadding.right - clamped.rect.width)
        : safeAreaPadding.left;
    return FlutterAppPipGeometry(
      screenSize: screenSize,
      rect: Rect.fromLTWH(left, clamped.rect.top, clamped.rect.width, clamped.rect.height),
    );
  }

  FlutterAppPipGeometry resizeByScale(
    double scale, {
    required FlutterAppPipOverlayConfig config,
  }) {
    if (scale <= 0) {
      return clampToScreen(safeAreaPadding: config.safeAreaPadding);
    }
    final width = (rect.width * scale).clamp(config.minSize.width, config.maxSize.width).toDouble();
    final height = (rect.height * scale).clamp(config.minSize.height, config.maxSize.height).toDouble();
    final center = rect.center;
    return FlutterAppPipGeometry(
      screenSize: screenSize,
      rect: Rect.fromCenter(center: center, width: width, height: height),
    ).clampToScreen(safeAreaPadding: config.safeAreaPadding);
  }

  FlutterAppPipGeometry avoidCollision(
    Rect obstacle, {
    double padding = 0,
    EdgeInsets safeAreaPadding = EdgeInsets.zero,
  }) {
    final clamped = clampToScreen(safeAreaPadding: safeAreaPadding);
    if (!clamped.rect.overlaps(obstacle)) {
      return clamped;
    }

    final aboveTop = obstacle.top - padding - clamped.rect.height;
    if (aboveTop >= 0) {
      return FlutterAppPipGeometry(
        screenSize: screenSize,
        rect: Rect.fromLTWH(clamped.rect.left, aboveTop, clamped.rect.width, clamped.rect.height),
      ).clampToScreen(safeAreaPadding: safeAreaPadding);
    }

    final belowTop = obstacle.bottom + padding;
    return FlutterAppPipGeometry(
      screenSize: screenSize,
      rect: Rect.fromLTWH(clamped.rect.left, belowTop, clamped.rect.width, clamped.rect.height),
    ).clampToScreen(safeAreaPadding: safeAreaPadding);
  }

  static Rect _defaultRect(Size screenSize, FlutterAppPipOverlayConfig config) {
    final size = _defaultSize(screenSize, config);
    final Offset offset;
    switch (config.initialCorner) {
      case FlutterAppPipCorner.topLeft:
        offset = Offset.zero;
      case FlutterAppPipCorner.topRight:
        offset = Offset(screenSize.width - size.width, 0);
      case FlutterAppPipCorner.bottomLeft:
        offset = Offset(0, screenSize.height - size.height);
      case FlutterAppPipCorner.bottomRight:
        offset = Offset(screenSize.width - size.width, screenSize.height - size.height);
    }
    return offset & size;
  }

  static Size _defaultSize(Size screenSize, FlutterAppPipOverlayConfig config) {
    if (config.width != null && config.height != null) {
      return Size(config.width!, config.height!);
    }
    if (config.width != null) {
      return Size(config.width!, config.width! / config.aspectRatio);
    }
    if (config.height != null) {
      return Size(config.height! * config.aspectRatio, config.height!);
    }
    final shortestSide = min(screenSize.width, screenSize.height);
    final contentWidth = shortestSide * 0.3;
    return Size(
      contentWidth + config.padding * 2,
      contentWidth / config.aspectRatio + config.padding * 2,
    );
  }
}
