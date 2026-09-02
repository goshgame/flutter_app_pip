import 'package:flutter/material.dart';

typedef StateMigrationVideoBuilder = Widget Function(Key key);

class StateMigrationVideoFrame extends StatelessWidget {
  const StateMigrationVideoFrame({
    super.key,
    required this.badge,
    required this.video,
    this.actions = const [],
  });

  final String badge;
  final Widget video;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: video),
            Positioned(
              left: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    badge,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Wrap(spacing: 4, children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

class StateMigrationPlayer extends StatefulWidget {
  const StateMigrationPlayer({
    required super.key,
    required this.videoBuilder,
  });

  final StateMigrationVideoBuilder videoBuilder;

  @override
  State<StateMigrationPlayer> createState() => _StateMigrationPlayerState();
}

class _StateMigrationPlayerState extends State<StateMigrationPlayer> {
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
        widget.videoBuilder(const ValueKey('state-migration-video')),
        Positioned(
          left: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Player State #$_instanceId',
                key: const ValueKey('state-migration-instance'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
