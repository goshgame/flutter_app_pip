import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';

import 'state_migration_live_page.dart';
import 'state_migration_next_page.dart';
import 'state_migration_pip_surface.dart';
import 'state_migration_video.dart';

class StateMigrationDemoCoordinator {
  StateMigrationDemoCoordinator({
    required this.navigatorKey,
    required this.pipController,
    required this.videoBuilder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final FlutterAppPipController pipController;
  final StateMigrationVideoBuilder videoBuilder;

  final GlobalKey _routeVideoKey = GlobalKey();
  final GlobalKey _pipVideoKey = GlobalKey();
  var _routeVisible = false;
  var _transitioning = false;
  var _disposed = false;

  Future<void> open(BuildContext context) async {
    if (_disposed || _routeVisible || _transitioning) {
      return;
    }
    pipController.closeInApp();
    if (!pipController.attachContentToPage()) {
      return;
    }
    _routeVisible = true;
    await Navigator.of(context).push<void>(_roomRoute());
    _routeVisible = false;
  }

  MaterialPageRoute<void> _roomRoute() {
    return MaterialPageRoute<void>(
      builder: (_) {
        return StateMigrationLivePage(
          controller: pipController,
          videoBuilder: videoBuilder,
          videoFrameKey: _routeVideoKey,
          onLeaveToPip: _leaveRoomToPip,
          onOpenNextPage: _openNextPageWithPip,
        );
      },
    );
  }

  Future<void> _leaveRoomToPip(BuildContext context) async {
    if (_disposed || _transitioning) {
      return;
    }
    _transitioning = true;
    try {
      final moved = await _moveContentToPip(context);
      if (moved && context.mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _transitioning = false;
    }
  }

  Future<void> _openNextPageWithPip(BuildContext context) async {
    if (_disposed || _transitioning) {
      return;
    }
    _transitioning = true;
    try {
      final moved = await _moveContentToPip(context);
      if (moved && context.mounted) {
        unawaited(
          Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute<void>(builder: (_) => const StateMigrationNextPage()),
          ),
        );
      }
    } finally {
      _transitioning = false;
    }
  }

  Future<bool> _moveContentToPip(BuildContext context) {
    return pipController.moveContentToInApp(
      config: _pipConfig(context),
      onRestoreRequested: _requestRestoreRoom,
      builder: (_, contentKey) {
        return StateMigrationPipSurface(
          controller: pipController,
          videoBuilder: videoBuilder,
          contentKey: contentKey,
          frameKey: _pipVideoKey,
          onExpand: _requestRestoreRoom,
        );
      },
    );
  }

  void _requestRestoreRoom() {
    unawaited(_restoreRoomFromPip());
  }

  Future<void> _restoreRoomFromPip() async {
    final navigator = navigatorKey.currentState;
    if (_disposed || navigator == null || _routeVisible || _transitioning) {
      return;
    }
    _transitioning = true;
    _routeVisible = true;
    final route = navigator.push<void>(_roomRoute());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        unawaited(_restoreContentToPage());
      }
    });
    await route;
    _routeVisible = false;
  }

  Future<void> _restoreContentToPage() async {
    await pipController.restoreContentToPage(
      targetRect: _globalRect(_routeVideoKey),
    );
    _transitioning = false;
  }

  FlutterAppPipOverlayConfig _pipConfig(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final width = min(240.0, screenSize.width * 0.56);
    final height = width * 9 / 16;
    return FlutterAppPipOverlayConfig(
      width: width,
      height: height,
      aspectRatio: 16 / 9,
      initialCorner: FlutterAppPipCorner.bottomRight,
      transitionSourceRect: _globalRect(_routeVideoKey),
      safeAreaPadding: EdgeInsets.fromLTRB(12, padding.top + 12, 12, padding.bottom + 24),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    );
  }

  Rect? _globalRect(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void dispose() {
    _disposed = true;
  }
}
