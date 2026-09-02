import 'package:flutter/material.dart';

class StateMigrationDemoEntry extends StatelessWidget {
  const StateMigrationDemoEntry({
    super.key,
    required this.onEnterLiveRoom,
  });

  final VoidCallback onEnterLiveRoom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('State-preserving PiP', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Move one stateful video widget from a live page to the home PiP window.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onEnterLiveRoom,
              icon: const Icon(Icons.switch_video),
              label: const Text('Open migration demo'),
            ),
          ],
        ),
      ),
    );
  }
}
