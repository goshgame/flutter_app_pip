import 'package:flutter/material.dart';

import '../application/player_playback_session.dart';

class PlayerSurface extends StatefulWidget {
  const PlayerSurface({
    required super.key,
    required this.session,
  });

  final PlayerPlaybackSession session;

  @override
  State<PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<PlayerSurface> {
  static var _createdCount = 0;

  late final int _instanceId;

  @override
  void initState() {
    super.initState();
    _instanceId = ++_createdCount;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.session.buildPlayerView(
          key: const ValueKey('production-player-video-view'),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Player instance #$_instanceId',
                key: const ValueKey('production-player-instance'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
