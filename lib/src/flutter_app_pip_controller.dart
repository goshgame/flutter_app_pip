import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'flutter_app_pip_content_host.dart';
import 'flutter_app_pip_mode.dart';
import 'in_app/flutter_app_pip_overlay_config.dart';
import 'system/flutter_app_system_pip_config.dart';
import 'system/flutter_app_system_pip_event.dart';
import 'system/flutter_app_system_pip_platform.dart';
import 'system/method_channel_flutter_app_system_pip_platform.dart';

part 'content/flutter_app_pip_content_migration.dart';

typedef FlutterAppPipWidgetBuilder = Widget Function(
  BuildContext context,
  FlutterAppPipController controller,
);

typedef FlutterAppPipContentBuilder = Widget Function(
  BuildContext context,
  GlobalKey contentKey,
);

class FlutterAppPipInAppEntry {
  const FlutterAppPipInAppEntry({
    required this.builder,
    required this.config,
    this.isPrepared = false,
    this.usesContentHost = false,
    this.onRestoreRequested,
    this.restoreTargetRect,
    this.onRestoreTransitionCompleted,
  });

  final FlutterAppPipWidgetBuilder builder;
  final FlutterAppPipOverlayConfig config;
  final bool isPrepared;
  final bool usesContentHost;
  final VoidCallback? onRestoreRequested;
  final Rect? restoreTargetRect;
  final VoidCallback? onRestoreTransitionCompleted;

  FlutterAppPipInAppEntry copyWith({
    FlutterAppPipWidgetBuilder? builder,
    FlutterAppPipOverlayConfig? config,
    bool? isPrepared,
    bool? usesContentHost,
    VoidCallback? onRestoreRequested,
    Rect? restoreTargetRect,
    VoidCallback? onRestoreTransitionCompleted,
  }) {
    return FlutterAppPipInAppEntry(
      builder: builder ?? this.builder,
      config: config ?? this.config,
      isPrepared: isPrepared ?? this.isPrepared,
      usesContentHost: usesContentHost ?? this.usesContentHost,
      onRestoreRequested: onRestoreRequested ?? this.onRestoreRequested,
      restoreTargetRect: restoreTargetRect ?? this.restoreTargetRect,
      onRestoreTransitionCompleted:
          onRestoreTransitionCompleted ?? this.onRestoreTransitionCompleted,
    );
  }
}

class FlutterAppPipController {
  FlutterAppPipController({
    FlutterAppSystemPipPlatform? systemPlatform,
    GlobalKey? contentKey,
  }) : _systemPlatform = systemPlatform ?? MethodChannelFlutterAppSystemPipPlatform() {
    _contentMigration = _FlutterAppPipContentMigration(
      contentKey: contentKey,
      binding: _FlutterAppPipContentMigrationBinding(
        isAttached: () => _attached,
        isSystemActive: () => isSystemActive.value,
        inAppEntry: inAppEntry,
        onHostActivated: _handleContentHostActivated,
        onHostRestored: _handleContentHostRestored,
      ),
    );
    _systemEventsSubscription = _systemPlatform.events.listen(_handleSystemEvent);
  }

  final ValueNotifier<FlutterAppPipMode> mode = ValueNotifier(FlutterAppPipMode.none);
  final ValueNotifier<bool> isInAppActive = ValueNotifier(false);
  final ValueNotifier<bool> isSystemActive = ValueNotifier(false);
  final ValueNotifier<bool> isSystemSupported = ValueNotifier(false);
  final ValueNotifier<bool> isAutoEnterEnabled = ValueNotifier(false);
  final ValueNotifier<FlutterAppPipInAppEntry?> inAppEntry = ValueNotifier(null);
  final ValueNotifier<FlutterAppPipCollisionRequest?> collisionRequest = ValueNotifier(null);
  final ValueNotifier<Offset?> _inAppPositionNotifier = ValueNotifier(null);
  final StreamController<FlutterAppSystemPipEvent> _systemEvents =
      StreamController<FlutterAppSystemPipEvent>.broadcast();

  final FlutterAppSystemPipPlatform _systemPlatform;
  late final _FlutterAppPipContentMigration _contentMigration;
  late final StreamSubscription<FlutterAppSystemPipEvent> _systemEventsSubscription;
  var _attached = false;
  var _collisionRequestId = 0;
  // 系统 PiP 激活后使用顶层 Overlay 承载播放器；这里保留进入前宿主供退出时原位恢复。
  FlutterAppPipContentHost? _systemRestoreHost;
  FlutterAppPipOverlayConfig? _systemRestoreConfig;

  bool get isAttached => _attached;

  GlobalKey get contentKey => _contentMigration.contentKey;

  ValueNotifier<FlutterAppPipContentHost> get contentHost =>
      _contentMigration.contentHost;

  Offset? get inAppPosition => _inAppPositionNotifier.value;

  ValueListenable<Offset?> get inAppPositionListenable =>
      _inAppPositionNotifier;

  Stream<FlutterAppSystemPipEvent> get systemEvents => _systemEvents.stream;

  void attach() {
    _attached = true;
  }

  void detach() {
    _attached = false;
  }

  void updateInAppPosition(Offset? position) {
    _inAppPositionNotifier.value = position;
  }

  bool attachContentToPage() => _contentMigration.attachToPage();

  Future<bool> moveContentToInApp({
    required FlutterAppPipContentBuilder builder,
    FlutterAppPipOverlayConfig config = const FlutterAppPipOverlayConfig(),
    VoidCallback? onRestoreRequested,
  }) =>
      _contentMigration.moveToInApp(
        builder: builder,
        config: config,
        onRestoreRequested: onRestoreRequested,
      );

  Future<bool> prepareContentToInApp({
    required FlutterAppPipContentBuilder builder,
    FlutterAppPipOverlayConfig config = const FlutterAppPipOverlayConfig(),
    VoidCallback? onRestoreRequested,
  }) =>
      _contentMigration.prepareInApp(
        builder: builder,
        config: config,
        onRestoreRequested: onRestoreRequested,
      );

  Future<bool> activatePreparedContentHost() =>
      _contentMigration.activatePreparedInApp();

  void cancelPreparedContentHost() {
    _contentMigration.cancelPreparedInApp();
  }

  Future<bool> restoreContentToPage({Rect? targetRect}) =>
      _contentMigration.restoreToPage(targetRect: targetRect);

  void detachContent() {
    _clearSystemRestoreTarget();
    _contentMigration.detachHost();
    inAppEntry.value = null;
    isInAppActive.value = false;
    if (!isSystemActive.value) {
      mode.value = FlutterAppPipMode.none;
    }
  }

  bool showInApp({
    required FlutterAppPipWidgetBuilder builder,
    FlutterAppPipOverlayConfig config = const FlutterAppPipOverlayConfig(),
  }) {
    if (!_attached) {
      return false;
    }
    inAppEntry.value = FlutterAppPipInAppEntry(builder: builder, config: config);
    isInAppActive.value = true;
    mode.value = FlutterAppPipMode.inApp;
    return true;
  }

  void enterInApp() {
    if (inAppEntry.value == null) {
      return;
    }
    isInAppActive.value = true;
    mode.value = FlutterAppPipMode.inApp;
    if (inAppEntry.value?.usesContentHost == true) {
      _contentMigration.moveHostTo(FlutterAppPipContentHost.inApp);
    }
  }

  void updateInAppConfig(FlutterAppPipOverlayConfig config) {
    final entry = inAppEntry.value;
    if (entry == null) {
      return;
    }
    inAppEntry.value = entry.copyWith(config: config);
  }

  void avoidCollision(Rect obstacle, {double padding = 0}) {
    collisionRequest.value = FlutterAppPipCollisionRequest(
      id: ++_collisionRequestId,
      obstacle: obstacle,
      padding: padding,
    );
  }

  void restoreFullScreen() {
    final entry = inAppEntry.value;
    if (entry != null && entry.usesContentHost) {
      final onRestoreRequested = entry.onRestoreRequested;
      if (onRestoreRequested != null) {
        onRestoreRequested();
      } else {
        unawaited(restoreContentToPage());
      }
      return;
    }
    isInAppActive.value = false;
    if (!isSystemActive.value) {
      mode.value = FlutterAppPipMode.none;
    }
    if (inAppEntry.value?.config.closeOnRestore == true) {
      closeInApp();
    }
  }

  void closeInApp() {
    if (inAppEntry.value?.usesContentHost == true) {
      detachContent();
      return;
    }
    inAppEntry.value = null;
    isInAppActive.value = false;
    if (!isSystemActive.value) {
      mode.value = FlutterAppPipMode.none;
    }
  }

  Future<bool> checkSystemSupported() async {
    final supported = await _systemPlatform.isSupported();
    isSystemSupported.value = supported;
    return supported;
  }

  Future<bool> isAutoEnterSystemSupported() {
    return _systemPlatform.isAutoEnterSupported();
  }

  Future<bool> startSystem(FlutterAppSystemPipConfig config) async {
    final supported = await checkSystemSupported();
    if (!supported) {
      return false;
    }
    final started = await _systemPlatform.start(config);
    if (started) {
      syncSystemActive(true);
    }
    return started;
  }

  Future<bool> enableAutoEnterSystem(FlutterAppSystemPipConfig config) async {
    final supported = await checkSystemSupported();
    if (!supported) {
      isAutoEnterEnabled.value = false;
      return false;
    }
    final enabled = await _systemPlatform.enableAutoEnter(config.copyWith(autoEnterEnabled: true));
    isAutoEnterEnabled.value = enabled;
    return enabled;
  }

  Future<bool> completeAutoEnterSystemPreparation() {
    return _systemPlatform.completeAutoEnterPreparation();
  }

  void prepareContentForSystemRestore({
    required FlutterAppPipContentHost host,
    FlutterAppPipOverlayConfig? inAppConfig,
  }) {
    // 必须在系统宿主激活前保存，否则退出时无法判断应恢复到页面还是应用内小窗。
    _systemRestoreHost = host;
    _systemRestoreConfig = inAppConfig;
  }

  Future<bool> disableAutoEnterSystem() async {
    final disabled = await _systemPlatform.disableAutoEnter();
    if (disabled) {
      isAutoEnterEnabled.value = false;
    }
    return disabled;
  }

  Future<bool> stopSystem() async {
    final stopped = await _systemPlatform.stop();
    if (stopped) {
      syncSystemActive(false);
    }
    return stopped;
  }

  void syncSystemActive(bool active) {
    final entry = inAppEntry.value;
    final usesContentHost = entry?.usesContentHost == true;
    final isContentHostPrepared = entry?.isPrepared == true;
    isSystemActive.value = active;
    if (active) {
      // 主动 startSystem 未预先登记恢复目标时，以当前宿主作为兜底快照。
      final currentHost = contentHost.value;
      if (_systemRestoreHost == null &&
          (currentHost == FlutterAppPipContentHost.page ||
              currentHost == FlutterAppPipContentHost.inApp)) {
        _systemRestoreHost = currentHost;
        if (currentHost == FlutterAppPipContentHost.inApp) {
          _systemRestoreConfig = inAppEntry.value?.config;
        }
      }
      isInAppActive.value = false;
      if (usesContentHost && !isContentHostPrepared) {
        _contentMigration.moveHostTo(FlutterAppPipContentHost.outOfApp);
      }
      mode.value = FlutterAppPipMode.outOfApp;
      return;
    }
    if (mode.value == FlutterAppPipMode.outOfApp) {
      if (usesContentHost) {
        _restoreContentFromSystemPip();
      } else {
        _clearSystemRestoreTarget();
        mode.value = FlutterAppPipMode.none;
      }
    }
  }

  void _restoreContentFromSystemPip() {
    final restoreHost = _systemRestoreHost ?? FlutterAppPipContentHost.inApp;
    final restoreConfig = _systemRestoreConfig;
    _clearSystemRestoreTarget();
    if (restoreHost == FlutterAppPipContentHost.page) {
      _contentMigration.moveHostTo(FlutterAppPipContentHost.page);
      isInAppActive.value = false;
      mode.value = FlutterAppPipMode.none;
      // 先切换 contentHost 让 GlobalKey 回到页面，下一帧再移除 Overlay，避免同一帧重复挂载。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isSystemActive.value &&
            contentHost.value == FlutterAppPipContentHost.page) {
          inAppEntry.value = null;
        }
      });
      return;
    }
    if (restoreConfig != null) {
      updateInAppConfig(restoreConfig);
    }
    _contentMigration.moveHostTo(FlutterAppPipContentHost.inApp);
    isInAppActive.value = true;
    mode.value = FlutterAppPipMode.inApp;
  }

  void _clearSystemRestoreTarget() {
    _systemRestoreHost = null;
    _systemRestoreConfig = null;
  }

  void dispose() {
    _systemEventsSubscription.cancel();
    _systemEvents.close();
    _systemPlatform.dispose();
    mode.dispose();
    _contentMigration.dispose();
    isInAppActive.dispose();
    isSystemActive.dispose();
    isSystemSupported.dispose();
    isAutoEnterEnabled.dispose();
    inAppEntry.dispose();
    collisionRequest.dispose();
    _inAppPositionNotifier.dispose();
  }

  void _handleSystemEvent(FlutterAppSystemPipEvent event) {
    switch (event.type) {
      case FlutterAppSystemPipEventType.activeChanged:
        syncSystemActive(event.active == true);
      case FlutterAppSystemPipEventType.startFailed:
      case FlutterAppSystemPipEventType.unsupported:
        syncSystemActive(false);
      case FlutterAppSystemPipEventType.restoreRequested:
        syncSystemActive(false);
      case FlutterAppSystemPipEventType.prepareAutoEnter:
        break;
    }
    _systemEvents.add(event);
  }

  void _handleContentHostActivated(FlutterAppPipContentHost host) {
    final isInApp = host == FlutterAppPipContentHost.inApp;
    isInAppActive.value = isInApp;
    mode.value = isInApp ? FlutterAppPipMode.inApp : FlutterAppPipMode.outOfApp;
  }

  void _handleContentHostRestored() {
    isInAppActive.value = false;
    mode.value = FlutterAppPipMode.none;
  }
}

class FlutterAppPipCollisionRequest {
  const FlutterAppPipCollisionRequest({
    required this.id,
    required this.obstacle,
    required this.padding,
  });

  final int id;
  final Rect obstacle;
  final double padding;
}
