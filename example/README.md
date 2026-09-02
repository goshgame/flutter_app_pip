# flutter_app_pip_example

## State-preserving player migration

The `State-preserving PiP` card demonstrates the controller-owned `GlobalKey` flow:

1. Open `State Migration Live` from the home page.
2. The page renders the video through `FlutterAppPipPageSlot`.
3. Go back to move the same stateful video widget into a PiP window above the home page.
4. Tap the PiP window or its expand button to open the live page and move the same widget state back.
5. Alternatively, select `Open another page with PiP` to replace the live route while keeping the PiP visible above the new page.

The visible `Player State #N` label stays unchanged across both hosts.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
