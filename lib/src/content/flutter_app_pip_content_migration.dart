part of '../flutter_app_pip_controller.dart';

/// 管理同一个 GlobalKey 内容在页面、应用内小窗和系统小窗之间的宿主迁移。
class _FlutterAppPipContentMigration {
  _FlutterAppPipContentMigration({
    required _FlutterAppPipContentMigrationBinding binding,
    GlobalKey? contentKey,
  })  : _binding = binding,
        contentKey = contentKey ?? GlobalKey(debugLabel: 'flutter_app_pip_content');

  final _FlutterAppPipContentMigrationBinding _binding;
  final GlobalKey contentKey;
  final ValueNotifier<FlutterAppPipContentHost> contentHost =
      ValueNotifier(FlutterAppPipContentHost.none);

  var _moving = false;

  bool attachToPage() {
    final host = contentHost.value;
    if (host != FlutterAppPipContentHost.none && host != FlutterAppPipContentHost.page) {
      return false;
    }
    contentHost.value = FlutterAppPipContentHost.page;
    return true;
  }

  Future<bool> moveToInApp({
    required FlutterAppPipContentBuilder builder,
    required FlutterAppPipOverlayConfig config,
    VoidCallback? onRestoreRequested,
  }) async {
    final prepared = await prepareInApp(
      builder: builder,
      config: config,
      onRestoreRequested: onRestoreRequested,
    );
    if (!prepared) {
      return false;
    }
    return activatePreparedInApp();
  }

  Future<bool> prepareInApp({
    required FlutterAppPipContentBuilder builder,
    required FlutterAppPipOverlayConfig config,
    VoidCallback? onRestoreRequested,
  }) async {
    if (!_binding.isAttached() ||
        _moving ||
        contentHost.value != FlutterAppPipContentHost.page) {
      return false;
    }

    _moving = true;
    try {
      final entry = FlutterAppPipInAppEntry(
        builder: (context, _) {
          return ValueListenableBuilder<FlutterAppPipContentHost>(
            valueListenable: contentHost,
            builder: (context, host, child) {
              if (host == FlutterAppPipContentHost.inApp ||
                  host == FlutterAppPipContentHost.outOfApp) {
                return builder(context, contentKey);
              }
              return child!;
            },
            child: const SizedBox.shrink(),
          );
        },
        config: config,
        isPrepared: true,
        usesContentHost: true,
        onRestoreRequested: onRestoreRequested,
      );
      _binding.inAppEntry.value = entry;
      await WidgetsBinding.instance.endOfFrame;

      if (!_binding.isAttached() || _binding.inAppEntry.value != entry) {
        if (_binding.inAppEntry.value == entry) {
          _binding.inAppEntry.value = null;
        }
        return false;
      }
      return true;
    } finally {
      _moving = false;
    }
  }

  Future<bool> activatePreparedInApp() async {
    final entry = _binding.inAppEntry.value;
    if (!_binding.isAttached() ||
        _moving ||
        contentHost.value != FlutterAppPipContentHost.page ||
        entry?.isPrepared != true) {
      return false;
    }

    _moving = true;
    try {
      final targetHost = _binding.isSystemActive()
          ? FlutterAppPipContentHost.outOfApp
          : FlutterAppPipContentHost.inApp;
      contentHost.value = targetHost;
      _binding.onHostActivated(targetHost);
      _binding.inAppEntry.value = entry!.copyWith(isPrepared: false);
      await WidgetsBinding.instance.endOfFrame;
      return true;
    } finally {
      _moving = false;
    }
  }

  void cancelPreparedInApp() {
    if (contentHost.value == FlutterAppPipContentHost.page &&
        _binding.inAppEntry.value?.isPrepared == true) {
      _binding.inAppEntry.value = null;
    }
  }

  Future<bool> restoreToPage({Rect? targetRect}) async {
    final host = contentHost.value;
    final canRestore = host == FlutterAppPipContentHost.inApp ||
        host == FlutterAppPipContentHost.outOfApp;
    if (_moving || !canRestore || _binding.isSystemActive()) {
      return false;
    }

    _moving = true;
    try {
      if (targetRect != null) {
        final entry = _binding.inAppEntry.value;
        if (entry == null) {
          return false;
        }
        final transitionCompleted = Completer<void>();
        _binding.inAppEntry.value = entry.copyWith(
          restoreTargetRect: targetRect,
          onRestoreTransitionCompleted: transitionCompleted.complete,
        );
        await transitionCompleted.future.timeout(
          entry.config.transitionDuration + const Duration(milliseconds: 100),
          onTimeout: () {},
        );
        if (_binding.inAppEntry.value?.restoreTargetRect != targetRect) {
          return false;
        }
      }
      contentHost.value = FlutterAppPipContentHost.page;
      _binding.onHostRestored();
      await WidgetsBinding.instance.endOfFrame;
      _binding.inAppEntry.value = null;
      return true;
    } finally {
      _moving = false;
    }
  }

  void moveHostTo(FlutterAppPipContentHost host) {
    contentHost.value = host;
  }

  void detachHost() {
    contentHost.value = FlutterAppPipContentHost.none;
  }

  void dispose() {
    contentHost.dispose();
  }
}

class _FlutterAppPipContentMigrationBinding {
  const _FlutterAppPipContentMigrationBinding({
    required this.isAttached,
    required this.isSystemActive,
    required this.inAppEntry,
    required this.onHostActivated,
    required this.onHostRestored,
  });

  final bool Function() isAttached;
  final bool Function() isSystemActive;
  final ValueNotifier<FlutterAppPipInAppEntry?> inAppEntry;
  final ValueChanged<FlutterAppPipContentHost> onHostActivated;
  final VoidCallback onHostRestored;
}
