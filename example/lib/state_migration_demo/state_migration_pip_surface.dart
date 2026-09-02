import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';

import 'state_migration_video.dart';

class StateMigrationPipSurface extends StatelessWidget {
  const StateMigrationPipSurface({
    super.key,
    required this.controller,
    required this.videoBuilder,
    required this.contentKey,
    required this.frameKey,
    required this.onExpand,
  });

  final FlutterAppPipController controller;
  final StateMigrationVideoBuilder videoBuilder;
  final GlobalKey contentKey;
  final GlobalKey frameKey;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: frameKey,
      child: StateMigrationVideoFrame(
        key: const ValueKey('state-migration-pip'),
        badge: 'PIP HOST',
        video: StateMigrationPlayer(
          key: contentKey,
          videoBuilder: videoBuilder,
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Close migration PiP',
            onPressed: controller.closeInApp,
            icon: const Icon(Icons.close),
          ),
          IconButton.filledTonal(
            tooltip: 'Restore migration live page',
            onPressed: onExpand,
            icon: const Icon(Icons.open_in_full),
          ),
        ],
      ),
    );
  }
}
