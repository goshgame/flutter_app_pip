import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android plugin wires system pip channel and activity lifecycle', () {
    final file = File(
      'android/src/main/kotlin/com/gosh/flutter_app_pip/FlutterAppPipPlugin.kt',
    );

    expect(file.existsSync(), true);
    final source = file.readAsStringSync();
    expect(source, contains('flutter_app_pip/system'));
    expect(source, contains('ActivityAware'));
    expect(source, contains('enterPictureInPictureMode'));
    expect(source, contains('onPictureInPictureModeChanged'));
    expect(source, contains('enableAutoEnter'));
    expect(source, contains('completeAutoEnter'));
    expect(source, contains('addOnUserLeaveHintListener'));
    expect(source, contains('onPrepareAutoEnter'));
    expect(source, contains('setAutoEnterEnabled'));
    expect(source, contains('dispatchPictureInPictureModeChanged'));
    expect(source, contains('lastKnownPipActive'));
    expect(source, contains('SCREEN_ORIENTATION_UNSPECIFIED'));
    expect(source, contains('restoreActivityOrientationAfterPip'));
    expect(source, contains('builder::setActions'));
    expect(source, contains('RemoteAction'));
    expect(source, contains('registerActionReceiver'));
    expect(source, contains('Context.RECEIVER_NOT_EXPORTED'));
    expect(source, contains('PiP action dispatched to Flutter'));
    expect(source, contains('onAction'));
    expect(source, contains('updatePlaybackState'));
    expect(source, isNot(contains('AUTO_ENTER_DELAY_MS')));

  });

  test('iOS plugin wires system pip channel and AVKit PiP', () {
    final file = File('ios/Classes/FlutterAppPipPlugin.swift');

    expect(file.existsSync(), true);
    final source = file.readAsStringSync();
    expect(source, contains('flutter_app_pip/system'));
    expect(source, contains('AVPictureInPictureController'));
    expect(source, contains('isSupported'));
    expect(source, contains('enableAutoEnter'));
    expect(source, contains('onActiveChanged'));
    expect(source, contains('UIApplication.willResignActiveNotification'));
    expect(source, contains('autoEnterArguments'));
    expect(source, contains('completeAutoEnter'));
    expect(source, contains('addSublayer'));
    expect(source, contains('onPrepareAutoEnter'));
    expect(source, contains('case "updatePlaybackState"'));
  });
}
