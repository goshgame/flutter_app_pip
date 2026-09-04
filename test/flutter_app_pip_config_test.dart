import 'package:flutter/widgets.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system pip config serializes aspect ratio, source rect, media, and extra fields', () {
    const config = FlutterAppSystemPipConfig(
      aspectRatio: Size(9, 16),
      sourceRectHint: Rect.fromLTWH(1, 2, 30, 40),
      videoUrl: 'https://example.com/video.mp4',
      goHome: true,
      extra: {'room_id': 'room-1'},
    );

    expect(config.toJson(), {
      'aspectWidth': 9.0,
      'aspectHeight': 16.0,
      'sourceLeft': 1.0,
      'sourceTop': 2.0,
      'sourceRight': 31.0,
      'sourceBottom': 42.0,
      'videoUrl': 'https://example.com/video.mp4',
      'goHome': true,
      'room_id': 'room-1',
    });
  });

  test('overlay config keeps compact defaults generic and movable', () {
    const config = FlutterAppPipOverlayConfig();

    expect(config.aspectRatio, 9 / 16);
    expect(config.padding, 10);
    expect(config.movable, true);
    expect(config.snapToEdge, true);
    expect(config.backgroundColor, const Color(0x00000000));
    expect(config.transitionDuration, const Duration(milliseconds: 200));
  });

  test('system pip config serializes Android playback actions', () {
    const config = FlutterAppSystemPipConfig(
      actions: <FlutterAppSystemPipAction>{
        FlutterAppSystemPipAction.seekBackward,
        FlutterAppSystemPipAction.playPause,
        FlutterAppSystemPipAction.seekForward,
      },
      isPlaying: false,
      seekInterval: Duration(seconds: 15),
    );

    expect(config.toJson(), {
      'actions': ['seekBackward', 'playPause', 'seekForward'],
      'isPlaying': false,
      'seekIntervalMilliseconds': 15000,
      'goHome': false,
    });
  });
}
