import 'package:flutter/material.dart';
import 'package:flutter_app_pip_example/production_player_pip_demo/application/player_playback_session.dart';
import 'package:flutter_app_pip_example/production_player_pip_demo/domain/player_scene.dart';
import 'package:flutter_app_pip_example/production_player_pip_demo/presentation/player_pip_demo_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('moves one player state from page to pip and back', (tester) async {
    await tester.pumpWidget(
      PlayerPipDemoApp(sessionFactory: _FakePlaybackSession.new),
    );

    await tester.tap(find.text('Live room'));
    await tester.pumpAndSettle();

    final instanceText = tester.widget<Text>(
      find.byKey(const ValueKey('production-player-instance')),
    ).data;
    expect(instanceText, isNotNull);
    expect(find.text('Scene: live / gosh-live'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Production PiP Demo'), findsOneWidget);
    expect(find.text('PIP HOST'), findsOneWidget);
    expect(find.text(instanceText!), findsOneWidget);

    await tester.tap(find.byTooltip('Restore player page'));
    await tester.pumpAndSettle();

    expect(find.text('Scene: live / gosh-live'), findsOneWidget);
    expect(find.text(instanceText), findsOneWidget);
  });

  testWidgets('keeps root pip visible after replacing the player page', (tester) async {
    await tester.pumpWidget(
      PlayerPipDemoApp(sessionFactory: _FakePlaybackSession.new),
    );

    await tester.tap(find.text('Video detail'));
    await tester.pumpAndSettle();

    final instanceText = tester.widget<Text>(
      find.byKey(const ValueKey('production-player-instance')),
    ).data;
    await tester.tap(find.byTooltip('Open another page with PiP'));
    await tester.pumpAndSettle();

    expect(find.text('Another Page'), findsOneWidget);
    expect(find.text('PIP HOST'), findsOneWidget);
    expect(find.text(instanceText!), findsOneWidget);
  });
}

class _FakePlaybackSession implements PlayerPlaybackSession {
  _FakePlaybackSession(this.scene);

  @override
  final PlayerScene scene;

  @override
  Future<void> open() async {}

  @override
  Widget buildPlayerView({required Key key}) {
    return ColoredBox(
      key: key,
      color: Colors.black,
      child: const Center(child: Text('Fake player')),
    );
  }

  @override
  Future<void> dispose() async {}
}
