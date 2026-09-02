import 'dart:math';

import 'package:flutter/material.dart';

import '../flutter_app_pip_controller.dart';
import '../flutter_app_pip_mode.dart';
import 'flutter_app_pip_geometry.dart';

class FlutterAppPipOverlayEntry extends StatefulWidget {
  const FlutterAppPipOverlayEntry({
    super.key,
    required this.controller,
    required this.entry,
  });

  final FlutterAppPipController controller;
  final FlutterAppPipInAppEntry entry;

  @override
  State<FlutterAppPipOverlayEntry> createState() => _FlutterAppPipOverlayEntryState();
}

class _FlutterAppPipOverlayEntryState extends State<FlutterAppPipOverlayEntry> {
  static const _minimumTransitionDuration = Duration(milliseconds: 80);
  static const _transitionPixelsPerMillisecond = 4.0;

  FlutterAppPipGeometry? _geometry;
  FlutterAppPipGeometry? _gestureStartGeometry;
  Offset _gesturePanOffset = Offset.zero;
  int _handledCollisionRequestId = 0;
  Rect? _transitionBegin;
  Rect? _transitionEnd;
  var _transitionVersion = 0;

  @override
  void didUpdateWidget(covariant FlutterAppPipOverlayEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.config != widget.entry.config) {
      _geometry = null;
    }
    if (oldWidget.entry.isPrepared && !widget.entry.isPrepared) {
      final sourceRect = widget.entry.config.transitionSourceRect;
      if (sourceRect != null) {
        _startTransition(sourceRect, null);
      }
    }
    if (oldWidget.entry.restoreTargetRect != widget.entry.restoreTargetRect) {
      final targetRect = widget.entry.restoreTargetRect;
      final geometry = _geometry;
      if (targetRect != null && geometry != null) {
        _startTransition(geometry.rect, targetRect);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entry.isPrepared) {
      return _buildPreparedBackdrop();
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller.mode,
        widget.controller.collisionRequest,
      ]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = constraints.biggest;
            final isCompact = widget.controller.mode.value == FlutterAppPipMode.inApp;
            var geometry = isCompact ? _ensureGeometry(screenSize) : null;
            _handleCollisionRequest(isCompact);
            geometry = isCompact ? _geometry : null;
            final rect = geometry?.rect ?? Offset.zero & screenSize;
            final transitionBegin = _transitionBegin;
            final transitionEnd = _transitionEnd ?? rect;
            final content = _buildContent(context, isCompact);

            return Stack(
              children: [
                if (transitionBegin == null)
                  Positioned.fromRect(rect: rect, child: content)
                else
                  TweenAnimationBuilder<double>(
                    key: ValueKey(_transitionVersion),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: _resolveTransitionDuration(
                      transitionBegin,
                      transitionEnd,
                    ),
                    curve: widget.entry.config.transitionCurve,
                    onEnd: _handleTransitionEnd,
                    builder: (context, value, child) {
                      return Positioned.fromRect(
                        rect: Rect.lerp(transitionBegin, transitionEnd, value)!,
                        child: child!,
                      );
                    },
                    child: content,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPreparedBackdrop() {
    final config = widget.entry.config;
    if (config.backgroundColor.a == 0) {
      return const SizedBox.shrink();
    }
    final backdrop = ColoredBox(
      key: const ValueKey('flutter-app-pip-prepared-backdrop'),
      color: config.backgroundColor,
    );
    final sourceRect = config.transitionSourceRect;
    if (sourceRect == null) {
      return SizedBox.expand(child: backdrop);
    }
    return Stack(
      children: [
        Positioned.fromRect(rect: sourceRect, child: backdrop),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isCompact) {
    return IgnorePointer(
      ignoring: _transitionBegin != null,
      child: GestureDetector(
        onTap: isCompact ? widget.controller.restoreFullScreen : null,
        onScaleStart: isCompact ? _handleScaleStart : null,
        onScaleUpdate: isCompact ? _handleScaleUpdate : null,
        onScaleEnd: isCompact ? _handleScaleEnd : null,
        child: Material(
          color: widget.entry.config.backgroundColor,
          elevation: isCompact ? widget.entry.config.elevation : 0,
          borderRadius: isCompact ? widget.entry.config.borderRadius : BorderRadius.zero,
          clipBehavior: Clip.antiAlias,
          child: widget.entry.builder(context, widget.controller),
        ),
      ),
    );
  }

  void _startTransition(Rect begin, Rect? end) {
    _transitionBegin = begin;
    _transitionEnd = end;
    _transitionVersion += 1;
  }

  Duration _resolveTransitionDuration(Rect begin, Rect end) {
    final maximumDuration = widget.entry.config.transitionDuration;
    if (maximumDuration == Duration.zero) {
      return Duration.zero;
    }
    final distance = max(
      (begin.topLeft - end.topLeft).distance,
      (begin.bottomRight - end.bottomRight).distance,
    );
    final calculatedMicroseconds =
        distance /
        _transitionPixelsPerMillisecond *
        Duration.microsecondsPerMillisecond;
    final maximumMicroseconds = maximumDuration.inMicroseconds;
    final minimumMicroseconds = min(
      _minimumTransitionDuration.inMicroseconds,
      maximumMicroseconds,
    );
    return Duration(
      microseconds: calculatedMicroseconds
          .round()
          .clamp(minimumMicroseconds, maximumMicroseconds),
    );
  }

  void _handleTransitionEnd() {
    widget.entry.onRestoreTransitionCompleted?.call();
    if (mounted) {
      setState(() {
        _transitionBegin = null;
        _transitionEnd = null;
      });
    }
  }

  FlutterAppPipGeometry _ensureGeometry(Size screenSize) {
    final current = _geometry;
    if (current != null && current.screenSize == screenSize) {
      return current;
    }
    var geometry = FlutterAppPipGeometry.defaultCompact(
      screenSize: screenSize,
      config: widget.entry.config,
    );
    final savedPosition = widget.controller.inAppPosition;
    if (savedPosition != null) {
      geometry = geometry
          .moveBy(savedPosition - geometry.rect.topLeft)
          .clampToScreen(safeAreaPadding: widget.entry.config.safeAreaPadding);
    }
    _geometry = geometry;
    return _geometry!;
  }

  void _handlePanEnd() {
    final geometry = _geometry;
    if (geometry == null) {
      return;
    }
    setState(() {
      final nextGeometry = widget.entry.config.snapToEdge
          ? geometry.snapToHorizontalEdge(safeAreaPadding: widget.entry.config.safeAreaPadding)
          : geometry.clampToScreen(safeAreaPadding: widget.entry.config.safeAreaPadding);
      _geometry = nextGeometry;
      widget.controller.updateInAppPosition(nextGeometry.rect.topLeft);
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureStartGeometry = _geometry;
    _gesturePanOffset = Offset.zero;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final startGeometry = _gestureStartGeometry;
    if (startGeometry == null) {
      return;
    }
    _gesturePanOffset += details.focalPointDelta;
    setState(() {
      var nextGeometry = startGeometry;
      if (widget.entry.config.resizable && details.scale != 1) {
        nextGeometry = nextGeometry.resizeByScale(details.scale, config: widget.entry.config);
      }
      if (widget.entry.config.movable && _gesturePanOffset != Offset.zero) {
        nextGeometry = nextGeometry.moveBy(_gesturePanOffset);
      }
      final clampedGeometry = nextGeometry.clampToScreen(
        safeAreaPadding: widget.entry.config.safeAreaPadding,
      );
      if (widget.entry.config.movable) {
        _gesturePanOffset +=
            clampedGeometry.rect.topLeft - nextGeometry.rect.topLeft;
      }
      _geometry = clampedGeometry;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _gestureStartGeometry = null;
    _gesturePanOffset = Offset.zero;
    if (widget.entry.config.movable || widget.entry.config.resizable) {
      _handlePanEnd();
    }
  }

  void _handleCollisionRequest(bool isCompact) {
    if (!isCompact) {
      return;
    }
    final request = widget.controller.collisionRequest.value;
    final geometry = _geometry;
    if (request == null || geometry == null || request.id == _handledCollisionRequestId) {
      return;
    }
    _handledCollisionRequestId = request.id;
    _geometry = geometry.avoidCollision(
      request.obstacle,
      padding: request.padding,
      safeAreaPadding: widget.entry.config.safeAreaPadding,
    );
  }
}
