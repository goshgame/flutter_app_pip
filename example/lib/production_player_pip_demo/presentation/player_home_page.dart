import 'package:flutter/material.dart';

import '../domain/player_scene.dart';

class PlayerHomePage extends StatelessWidget {
  const PlayerHomePage({
    super.key,
    required this.scenes,
    required this.onOpenScene,
  });

  final List<PlayerScene> scenes;
  final ValueChanged<PlayerScene> onOpenScene;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Production PiP Demo')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: scenes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final scene = scenes[index];
          return Card(
            child: ListTile(
              leading: Icon(
                scene.type == PlayerSceneType.live
                    ? Icons.live_tv
                    : Icons.play_circle_outline,
              ),
              title: Text(scene.title),
              subtitle: Text('${scene.type.name} / ${scene.id}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenScene(scene),
            ),
          );
        },
      ),
    );
  }
}
