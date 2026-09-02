import 'package:flutter/widgets.dart';

import '../domain/player_scene.dart';

abstract interface class PlayerPlaybackSession {
  PlayerScene get scene;

  Future<void> open();

  Widget buildPlayerView({required Key key});

  Future<void> dispose();
}

typedef PlayerPlaybackSessionFactory = PlayerPlaybackSession Function(
  PlayerScene scene,
);
