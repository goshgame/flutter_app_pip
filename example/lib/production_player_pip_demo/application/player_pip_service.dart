import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';

import '../domain/player_scene.dart';
import 'player_playback_session.dart';

typedef PlayerCompactSurfaceBuilder = Widget Function(
  BuildContext context,
  GlobalKey contentKey,
  PlayerPlaybackSession session,
  VoidCallback onRestore,
  VoidCallback onClose,
);

class PlayerPipService {
  PlayerPipService({
    required PlayerPlaybackSessionFactory sessionFactory,
    required PlayerCompactSurfaceBuilder compactSurfaceBuilder,
    required VoidCallback onRestoreRequested,
    FlutterAppPipController? controller,
  })  : _sessionFactory = sessionFactory,
        _compactSurfaceBuilder = compactSurfaceBuilder,
        _onRestoreRequested = onRestoreRequested,
        controller = controller ?? FlutterAppPipController();

  final FlutterAppPipController controller;
  final PlayerPlaybackSessionFactory _sessionFactory;
  final PlayerCompactSurfaceBuilder _compactSurfaceBuilder;
  final VoidCallback _onRestoreRequested;
  final ValueNotifier<PlayerPlaybackSession?> session = ValueNotifier(null);

  var _transitioning = false;
  var _disposed = false;

  Future<bool> startScene(PlayerScene scene) async {
    if (_disposed || _transitioning) {
      return false;
    }
    _transitioning = true;
    try {
      final current = session.value;
      if (current != null && current.scene.isSameScene(scene)) {
        return controller.attachContentToPage();
      }
      await _releaseCurrentSession();
      if (_disposed) {
        return false;
      }
      final next = _sessionFactory(scene);
      session.value = next;
      try {
        await next.open();
      } catch (error) {
        if (session.value == next) {
          session.value = null;
        }
        await next.dispose();
        rethrow;
      }
      if (_disposed) {
        return false;
      }
      if (session.value != next) {
        await next.dispose();
        return false;
      }
      return controller.attachContentToPage();
    } finally {
      _transitioning = false;
    }
  }

  Future<bool> movePageToInApp({
    required FlutterAppPipOverlayConfig config,
  }) async {
    final current = session.value;
    if (_disposed || current == null) {
      return false;
    }
    return controller.moveContentToInApp(
      config: config,
      onRestoreRequested: _onRestoreRequested,
      builder: (context, contentKey) {
        return _compactSurfaceBuilder(
          context,
          contentKey,
          current,
          _onRestoreRequested,
          close,
        );
      },
    );
  }

  Future<bool> restoreToPage({Rect? targetRect}) {
    return controller.restoreContentToPage(targetRect: targetRect);
  }

  Future<void> close() async {
    if (_disposed || _transitioning) {
      return;
    }
    _transitioning = true;
    try {
      await _releaseCurrentSession();
    } finally {
      _transitioning = false;
    }
  }

  Future<void> _releaseCurrentSession() async {
    controller.closeInApp();
    final current = session.value;
    session.value = null;
    await current?.dispose();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final current = session.value;
    session.value = null;
    unawaited(current?.dispose());
    session.dispose();
    controller.dispose();
  }
}
