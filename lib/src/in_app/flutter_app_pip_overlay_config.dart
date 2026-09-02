import 'package:flutter/widgets.dart';

enum FlutterAppPipCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class FlutterAppPipOverlayConfig {
  const FlutterAppPipOverlayConfig({
    this.width,
    this.height,
    this.aspectRatio = 9 / 16,
    this.padding = 10,
    this.safeAreaPadding = const EdgeInsets.all(10),
    this.initialCorner = FlutterAppPipCorner.bottomRight,
    this.initialRect,
    this.movable = true,
    this.resizable = false,
    this.snapToEdge = true,
    this.avoidKeyboard = true,
    this.minSize = const Size(120, 90),
    this.maxSize = const Size(320, 320),
    this.backgroundColor = const Color(0x00000000),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.elevation = 8,
    this.closeOnRestore = false,
    this.transitionSourceRect,
    this.transitionDuration = const Duration(milliseconds: 200),
    this.transitionCurve = Curves.easeInOutCubic,
  });

  final double? width;
  final double? height;
  final double aspectRatio;
  final double padding;
  final EdgeInsets safeAreaPadding;
  final FlutterAppPipCorner initialCorner;
  final Rect? initialRect;
  final bool movable;
  final bool resizable;
  final bool snapToEdge;
  final bool avoidKeyboard;
  final Size minSize;
  final Size maxSize;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final double elevation;
  final bool closeOnRestore;
  final Rect? transitionSourceRect;
  /// 动画最长时长；实际时长会根据起止 Rect 的距离缩短。
  final Duration transitionDuration;
  final Curve transitionCurve;

  FlutterAppPipOverlayConfig copyWith({
    double? width,
    double? height,
    double? aspectRatio,
    double? padding,
    EdgeInsets? safeAreaPadding,
    FlutterAppPipCorner? initialCorner,
    Rect? initialRect,
    bool? movable,
    bool? resizable,
    bool? snapToEdge,
    bool? avoidKeyboard,
    Size? minSize,
    Size? maxSize,
    Color? backgroundColor,
    BorderRadius? borderRadius,
    double? elevation,
    bool? closeOnRestore,
    Rect? transitionSourceRect,
    Duration? transitionDuration,
    Curve? transitionCurve,
  }) {
    return FlutterAppPipOverlayConfig(
      width: width ?? this.width,
      height: height ?? this.height,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      padding: padding ?? this.padding,
      safeAreaPadding: safeAreaPadding ?? this.safeAreaPadding,
      initialCorner: initialCorner ?? this.initialCorner,
      initialRect: initialRect ?? this.initialRect,
      movable: movable ?? this.movable,
      resizable: resizable ?? this.resizable,
      snapToEdge: snapToEdge ?? this.snapToEdge,
      avoidKeyboard: avoidKeyboard ?? this.avoidKeyboard,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      closeOnRestore: closeOnRestore ?? this.closeOnRestore,
      transitionSourceRect: transitionSourceRect ?? this.transitionSourceRect,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      transitionCurve: transitionCurve ?? this.transitionCurve,
    );
  }
}
