import 'package:flutter/material.dart';

import '../application/player_playback_session.dart';
import 'player_surface.dart';

class PlayerPipSurface extends StatelessWidget {
  const PlayerPipSurface({
    super.key,
    required this.contentKey,
    required this.session,
    required this.onRestore,
    required this.onClose,
  });

  final GlobalKey contentKey;
  final PlayerPlaybackSession session;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('production-pip-surface'),
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlayerSurface(key: contentKey, session: session),
          const Positioned(
            left: 8,
            top: 8,
            child: _HostBadge(label: 'PIP HOST'),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Close player',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
                IconButton.filledTonal(
                  tooltip: 'Restore player page',
                  onPressed: onRestore,
                  icon: const Icon(Icons.open_in_full),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HostBadge extends StatelessWidget {
  const _HostBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
