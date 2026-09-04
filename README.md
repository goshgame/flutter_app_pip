# flutter_app_pip

Local Flutter plugin for app-level Picture-in-Picture:

- in-app PiP with a Flutter overlay;
- Android/iOS system PiP through `MethodChannel`;
- one controller state model: `none`, `inApp`, `outOfApp`.

## Install

Use the local package from the host app:

```yaml
dependencies:
  flutter_app_pip:
    path: package/flutter_app_pip
```

## Root Setup

Install `FlutterAppPipScope` near the app root:

```dart
final pipController = FlutterAppPipController(
  systemPlatform: MethodChannelFlutterAppSystemPipPlatform(),
);

MaterialApp(
  home: FlutterAppPipScope(
    controller: pipController,
    child: const HomePage(),
  ),
);
```

## In-App PiP

```dart
pipController.showInApp(
  config: const FlutterAppPipOverlayConfig(
    aspectRatio: 9 / 16,
    initialCorner: FlutterAppPipCorner.bottomRight,
  ),
  builder: (context, controller) => YourMiniPlayer(
    onClose: controller.closeInApp,
  ),
);
```

The in-app window supports drag, pinch resize, safe-area clamping, horizontal edge snap, tap-to-restore, runtime size updates, and collision avoidance:

```dart
pipController.updateInAppConfig(
  const FlutterAppPipOverlayConfig(
    width: 220,
    height: 124,
    resizable: true,
    minSize: Size(120, 90),
    maxSize: Size(320, 320),
  ),
);

pipController.avoidCollision(
  const Rect.fromLTWH(0, 700, 400, 100),
  padding: 12,
);
```

The controller remembers the final window position after dragging or resizing, so reopening PiP does not reset it to the configured corner. Clear or replace the saved position when needed:

```dart
pipController.updateInAppPosition(null);
```

### Preserve one widget state between page and PiP

For stateful players, use one controller-owned `GlobalKey` in both hosts. Register the page host before building the page slot:

```dart
pipController.attachContentToPage();

FlutterAppPipPageSlot(
  controller: pipController,
  builder: (context, contentKey) => YourPlayer(key: contentKey),
);
```

Move the same player state into the in-app window:

```dart
await pipController.moveContentToInApp(
  config: FlutterAppPipOverlayConfig(
    aspectRatio: 16 / 9,
    transitionSourceRect: playerPageRect,
  ),
  onRestoreRequested: openPlayerPageAndRestore,
  builder: (context, contentKey) => YourPlayer(key: contentKey),
);
```

The optional restore callback can navigate to the player page when the PiP is tapped. The controller mounts an empty PiP host before moving the keyed content. Restore only after the destination page slot is mounted:

```dart
await pipController.restoreContentToPage(targetRect: playerPageRect);
```

When system PiP becomes active, the Flutter player stays mounted in the overlay host and `contentHost` changes to `outOfApp`. Native system PiP still owns the external rendering surface.

## System PiP

System PiP is platform-owned. `startSystem()` and `enableAutoEnterSystem()` request PiP, while native callbacks are the source of truth for actual active state.

```dart
await pipController.startSystem(
  const FlutterAppSystemPipConfig(
    aspectRatio: Size(9, 16),
    sourceRectHint: Rect.fromLTWH(0, 0, 90, 160),
    videoUrl: 'https://example.com/video.mp4',
    actions: <FlutterAppSystemPipAction>{
      FlutterAppSystemPipAction.seekBackward,
      FlutterAppSystemPipAction.playPause,
      FlutterAppSystemPipAction.seekForward,
    },
    isPlaying: true,
    seekInterval: Duration(seconds: 10),
  ),
);
```

Android reports PiP action taps through `systemEvents`. Apply them to the
player owned by the app, then update the native play/pause icon when playback
state changes:

```dart
pipController.systemEvents.listen((event) async {
  switch (event.action) {
    case FlutterAppSystemPipAction.seekBackward:
    case FlutterAppSystemPipAction.seekForward:
      await player.seek(player.state.position + event.seekOffset!);
      break;
    case FlutterAppSystemPipAction.playPause:
      await player.playOrPause();
      await pipController.updateSystemPlaybackState(player.state.playing);
      break;
    case null:
      break;
  }
});
```

PiP actions are rendered by Android and are available on Android O/API 26+.
The system may limit the action count or vary their layout across devices.

Auto-enter does not switch to `outOfApp` until native confirms active state:

```dart
await pipController.enableAutoEnterSystem(
  const FlutterAppSystemPipConfig(aspectRatio: Size(9, 16)),
);
```

## Android Setup

The host activity must support Picture-in-Picture:

```xml
<activity
    android:name=".MainActivity"
    android:supportsPictureInPicture="true"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|screenLayout|density|uiMode" />
```

Android PiP requires Android O/API 26+ and `PackageManager.FEATURE_PICTURE_IN_PICTURE`.

## iOS Setup

iOS system PiP uses AVKit and requires renderable native media. Arbitrary Flutter widgets cannot be shown outside the app as system PiP content.

Set the host app deployment target to iOS 13.0 or newer:

```ruby
platform :ios, '13.0'
```

For media PiP, provide one of:

- `videoUrl`
- `filePath`
- `assetName`

Apps using background media should include the required background mode:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

## Example

```bash
cd package/flutter_app_pip/example
flutter run
```

The example exposes controls for in-app PiP, system PiP support checks, explicit start, auto-enter, stop, config updates, and native event inspection.
