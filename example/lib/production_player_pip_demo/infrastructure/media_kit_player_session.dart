import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../application/player_playback_session.dart';
import '../domain/player_scene.dart';

class MediaKitPlayerSession implements PlayerPlaybackSession {
  MediaKitPlayerSession(this.scene) : player = Player() {
    videoController = VideoController(player);
  }

  @override
  final PlayerScene scene;
  final Player player;
  late final VideoController videoController;

  var _opened = false;

  @override
  Future<void> open() async {
    if (_opened) {
      return;
    }
    _opened = true;
    await player.open(Media(scene.url), play: true);
  }

  @override
  Widget buildPlayerView({required Key key}) {
    return Video(
      key: key,
      controller: videoController,
      fit: BoxFit.cover,
      controls: NoVideoControls,
    );
  }

  @override
  Future<void> dispose() {
    return player.dispose();
  }
}
