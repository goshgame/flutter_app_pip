import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';

import '../application/player_pip_service.dart';
import '../application/player_playback_session.dart';
import '../domain/player_scene.dart';
import '../infrastructure/media_kit_player_session.dart';
import 'player_home_page.dart';
import 'player_page.dart';
import 'player_pip_surface.dart';

class PlayerPipDemoApp extends StatefulWidget {
  const PlayerPipDemoApp({
    super.key,
    this.sessionFactory,
  });

  final PlayerPlaybackSessionFactory? sessionFactory;

  @override
  State<PlayerPipDemoApp> createState() => _PlayerPipDemoAppState();
}

class _PlayerPipDemoAppState extends State<PlayerPipDemoApp> {
  static const _scenes = [
    PlayerScene(
      type: PlayerSceneType.live,
      id: 'gosh-live',
      title: 'Live room',
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    ),
    PlayerScene(
      type: PlayerSceneType.video,
      id: 'sample-video',
      title: 'Video detail',
      url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ),
  ];

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final PlayerPipService _pipService;
  var _playerRouteVisible = false;
  var _restoring = false;

  @override
  void initState() {
    super.initState();
    _pipService = PlayerPipService(
      sessionFactory: widget.sessionFactory ?? MediaKitPlayerSession.new,
      compactSurfaceBuilder: (
        context,
        contentKey,
        session,
        onRestore,
        onClose,
      ) {
        return PlayerPipSurface(
          contentKey: contentKey,
          session: session,
          onRestore: onRestore,
          onClose: onClose,
        );
      },
      onRestoreRequested: _requestRestore,
    );
  }

  @override
  void dispose() {
    _pipService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
        useMaterial3: true,
      ),
      home: FlutterAppPipScope(
        controller: _pipService.controller,
        child: PlayerHomePage(
          scenes: _scenes,
          onOpenScene: (scene) => unawaited(_openScene(scene)),
        ),
      ),
    );
  }

  Future<void> _openScene(PlayerScene scene) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || _playerRouteVisible || _restoring) {
      return;
    }
    final started = await _pipService.startScene(scene);
    if (!started || !mounted) {
      return;
    }
    _playerRouteVisible = true;
    await navigator.push<void>(_playerRoute(restoring: false));
    _playerRouteVisible = false;
  }

  void _requestRestore() {
    unawaited(_restoreActiveScene());
  }

  Future<void> _restoreActiveScene() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null ||
        _pipService.session.value == null ||
        _playerRouteVisible ||
        _restoring) {
      return;
    }
    _restoring = true;
    _playerRouteVisible = true;
    await navigator.push<void>(_playerRoute(restoring: true));
    _playerRouteVisible = false;
    _restoring = false;
  }

  MaterialPageRoute<void> _playerRoute({required bool restoring}) {
    return MaterialPageRoute<void>(
      builder: (_) {
        return PlayerPage(
          service: _pipService,
          restoring: restoring,
        );
      },
    );
  }
}
