import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';

import 'state_migration_video.dart';

class StateMigrationLivePage extends StatelessWidget {
  const StateMigrationLivePage({
    super.key,
    required this.controller,
    required this.videoBuilder,
    required this.videoFrameKey,
    required this.onLeaveToPip,
    required this.onOpenNextPage,
  });

  final FlutterAppPipController controller;
  final StateMigrationVideoBuilder videoBuilder;
  final GlobalKey videoFrameKey;
  final Future<void> Function(BuildContext context) onLeaveToPip;
  final Future<void> Function(BuildContext context) onOpenNextPage;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(onLeaveToPip(context));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('State Migration Live'),
          leading: BackButton(
            onPressed: () => unawaited(onLeaveToPip(context)),
          ),
          actions: [
            IconButton(
              tooltip: 'Open another page with PiP',
              onPressed: () => unawaited(onOpenNextPage(context)),
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StateMigrationVideoFrame(
              key: videoFrameKey,
              badge: 'PAGE HOST',
              video: FlutterAppPipPageSlot(
                controller: controller,
                placeholder: const ColoredBox(color: Colors.black),
                builder: (_, contentKey) {
                  return StateMigrationPlayer(
                    key: contentKey,
                    videoBuilder: videoBuilder,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Back moves this exact StatefulWidget to a PiP window above the home page.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
