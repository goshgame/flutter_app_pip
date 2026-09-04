import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'state_migration_demo/state_migration_demo.dart';

const liveStreamUrl = 'https://pull.gosh.com/live/15516834-6243885000134.flv?txSecret=8c93743bb69f1e395c358f3a24633681\u0026txTime=6a5a0cfc';

void main() {
  MediaKit.ensureInitialized();
  runApp(const FlutterAppPipExampleApp());
}

abstract class LiveVideoSession {
  bool get isPlaying;

  Stream<bool> get playing;

  Future<void> open();

  Widget buildVideo({Key? key});

  Future<Uint8List?> screenshot();

  Future<void> togglePlayback();

  Future<void> seekBy(Duration offset);

  Future<void> dispose();
}

enum _LiveVideoHostMode { live, pip, system }

class MediaKitLiveVideoSession implements LiveVideoSession {
  MediaKitLiveVideoSession(this.url) : player = Player() {
    controller = VideoController(player);
  }

  final String url;
  final Player player;
  late final VideoController controller;
  var _opened = false;

  @override
  bool get isPlaying => player.state.playing;

  @override
  Stream<bool> get playing => player.stream.playing;

  @override
  Future<void> open() async {
    if (_opened) {
      return;
    }
    _opened = true;
    await player.open(Media(url), play: true);
  }

  @override
  Widget buildVideo({Key? key}) {
    return Video(
      key: key,
      controller: controller,
      fit: BoxFit.cover,
      controls: NoVideoControls,
    );
  }

  @override
  Future<Uint8List?> screenshot() {
    return player.screenshot(format: 'image/jpeg');
  }

  @override
  Future<void> togglePlayback() {
    return isPlaying ? player.pause() : player.play();
  }

  @override
  Future<void> seekBy(Duration offset) {
    final position = player.state.position;
    final duration = player.state.duration;
    var target = position + offset;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (duration > Duration.zero && target > duration) {
      target = duration;
    }
    return player.seek(target);
  }

  @override
  Future<void> dispose() {
    return player.dispose();
  }
}

class FlutterAppPipExampleApp extends StatefulWidget {
  const FlutterAppPipExampleApp({
    super.key,
    this.liveSession,
  });

  final LiveVideoSession? liveSession;

  @override
  State<FlutterAppPipExampleApp> createState() => _FlutterAppPipExampleAppState();
}

class _FlutterAppPipExampleAppState extends State<FlutterAppPipExampleApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey _liveRouteVideoKey = GlobalKey();
  final GlobalKey _livePipVideoKey = GlobalKey();
  final GlobalKey _liveVideoSurfaceKey = GlobalKey();
  final ValueNotifier<_LiveVideoHostMode> _liveVideoHostMode = ValueNotifier(_LiveVideoHostMode.live);
  late final MethodChannelFlutterAppSystemPipPlatform _systemPlatform;
  late final FlutterAppPipController _controller;
  late final LiveVideoSession _liveSession;
  late final StateMigrationDemoCoordinator _stateMigrationDemo;
  StreamSubscription<FlutterAppSystemPipEvent>? _eventSubscription;
  StreamSubscription<bool>? _playingSubscription;
  final List<String> _events = <String>[];
  OverlayEntry? _flightEntry;
  Future<void>? _liveSnapshotRefresh;
  Uint8List? _liveSnapshotBytes;
  var _liveRouteVisible = false;
  var _livePipPrepared = false;
  var _livePipTransitioning = false;
  var _showSystemPipVideoLayer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _systemPlatform = MethodChannelFlutterAppSystemPipPlatform();
    _controller = FlutterAppPipController(systemPlatform: _systemPlatform);
    _liveSession = widget.liveSession ?? MediaKitLiveVideoSession(liveStreamUrl);
    _stateMigrationDemo = StateMigrationDemoCoordinator(
      navigatorKey: _navigatorKey,
      pipController: _controller,
      videoBuilder: (key) => _liveSession.buildVideo(key: key),
    );
    _eventSubscription = _systemPlatform.events.listen(_handleSystemEvent);
    _playingSubscription = _liveSession.playing.distinct().listen((isPlaying) {
      if (_controller.isSystemActive.value || _controller.isAutoEnterEnabled.value) {
        unawaited(_controller.updateSystemPlaybackState(isPlaying));
      }
    });
    unawaited(_openLiveSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _playingSubscription?.cancel();
    _flightEntry?.remove();
    _liveVideoHostMode.dispose();
    _stateMigrationDemo.dispose();
    unawaited(_liveSession.dispose());
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_liveRouteVisible || _livePipPrepared) {
        _prepareSystemPipVideoLayer();
      }
      return;
    }
    if (state == AppLifecycleState.resumed && !_controller.isSystemActive.value) {
      _clearSystemPipVideoLayer();
    }
  }

  Future<void> _openLiveSession() async {
    await _liveSession.open();
    if (!mounted) {
      return;
    }
    unawaited(_refreshLiveSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            if (_showSystemPipVideoLayer)
              _LiveSystemPipSurface(
                session: _liveSession,
                videoSurfaceKey: _liveVideoSurfaceKey,
              ),
          ],
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
        useMaterial3: true,
      ),
      home: FlutterAppPipScope(
        controller: _controller,
        child: Builder(
          builder: (context) {
            return _HomePage(
              controller: _controller,
              events: _events,
              onEnterLiveRoom: () => _openLiveRoom(context),
              stateMigrationDemo: StateMigrationDemoEntry(
                onEnterLiveRoom: () => _stateMigrationDemo.open(context),
              ),
              onShowDemoPip: _showDemoInApp,
              onCheckSupport: _checkSupport,
              onStartSystem: _startSystem,
              onEnableAutoEnter: _enableAutoEnter,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openLiveRoom(BuildContext context) async {
    if (_liveRouteVisible) {
      return;
    }
    _liveRouteVisible = true;
    _controller.closeInApp();
    _liveVideoHostMode.value = _LiveVideoHostMode.live;
    await _enableLiveAutoEnter();
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return _LiveRoomPage(
            session: _liveSession,
            videoKey: _liveRouteVideoKey,
            videoSurfaceKey: _liveVideoSurfaceKey,
            videoHostMode: _liveVideoHostMode,
            onLeaveToPip: _leaveLiveRoomToPip,
            onStartSystemPip: _startSystem,
          );
        },
      ),
    );
    _liveRouteVisible = false;
  }

  Future<void> _openLiveRoomFromPip() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || _liveRouteVisible || _livePipTransitioning) {
      return;
    }
    _livePipTransitioning = true;
    _liveRouteVisible = true;
    await _enableLiveAutoEnter();
    final snapshotBytes = _snapshotForTransition();
    if (!mounted) {
      _liveRouteVisible = false;
      _livePipTransitioning = false;
      return;
    }
    final route = navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          return _LiveRoomPage(
            session: _liveSession,
            videoKey: _liveRouteVideoKey,
            videoSurfaceKey: _liveVideoSurfaceKey,
            videoHostMode: _liveVideoHostMode,
            onLeaveToPip: _leaveLiveRoomToPip,
            onStartSystemPip: _startSystem,
          );
        },
      ),
    );
    final sourceRect = _globalRectFor(_livePipVideoKey) ?? _fallbackPipSourceRect();
    final targetRect = _liveRouteTargetRect();
    _startPipFlight(
      begin: sourceRect,
      end: targetRect,
      snapshotBytes: snapshotBytes,
      onCompleted: () => _livePipTransitioning = false,
    );
    // 等目标路由首帧挂载后再迁移真实 Video，flight 截图负责遮住 texture 迁移。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.closeInApp();
      _liveVideoHostMode.value = _LiveVideoHostMode.live;
    });
    await route;
    _liveRouteVisible = false;
  }

  void _leaveLiveRoomToPip(BuildContext context) {
    if (_livePipTransitioning) {
      return;
    }
    _livePipTransitioning = true;
    final config = _kickStyleLivePipConfig(context);
    final sourceRect = _globalRectFor(_liveRouteVideoKey) ?? _liveRouteTargetRect();
    final targetRect = config.initialRect!;
    final snapshotBytes = _snapshotForTransition();
    if (!mounted || !context.mounted) {
      _livePipTransitioning = false;
      return;
    }
    _showLiveInAppPip(config);
    _startPipFlight(
      begin: sourceRect,
      end: targetRect,
      snapshotBytes: snapshotBytes,
      onCompleted: () => _livePipTransitioning = false,
    );
    _liveVideoHostMode.value = _LiveVideoHostMode.pip;
    Navigator.of(context).pop();
  }

  Uint8List? _snapshotForTransition() {
    unawaited(_refreshLiveSnapshot());
    return _liveSnapshotBytes;
  }

  Future<void> _refreshLiveSnapshot() {
    final currentRefresh = _liveSnapshotRefresh;
    if (currentRefresh != null) {
      return currentRefresh;
    }
    late final Future<void> trackedRefresh;
    trackedRefresh = _captureLiveSnapshot().then((snapshotBytes) {
      if (snapshotBytes == null || !mounted) {
        return;
      }
      _liveSnapshotBytes = snapshotBytes;
    }).whenComplete(() {
      if (_liveSnapshotRefresh == trackedRefresh) {
        _liveSnapshotRefresh = null;
      }
    });
    _liveSnapshotRefresh = trackedRefresh;
    return trackedRefresh;
  }

  Future<Uint8List?> _captureLiveSnapshot() async {
    try {
      return await _liveSession.screenshot();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'flutter_app_pip example',
          context: ErrorDescription('capturing live PiP transition snapshot'),
        ),
      );
      return null;
    }
  }

  void _showLiveInAppPip(FlutterAppPipOverlayConfig config) {
    _livePipPrepared = true;
    _controller.showInApp(
      config: config,
      builder: (_, controller) {
        return _LivePipSurface(
          session: _liveSession,
          controller: controller,
          frameKey: _livePipVideoKey,
          videoSurfaceKey: _liveVideoSurfaceKey,
          videoHostMode: _liveVideoHostMode,
          onExpand: _openLiveRoomFromPip,
        );
      },
    );
  }

  FlutterAppPipOverlayConfig _kickStyleLivePipConfig(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final width = min(screenSize.width * 0.74, screenSize.width - 24);
    final height = width * 9 / 16;
    final top = max(padding.top + 220, screenSize.height * 0.34);
    return FlutterAppPipOverlayConfig(
      aspectRatio: 16 / 9,
      initialRect: Rect.fromLTWH(12, top, width, height),
      width: width,
      height: height,
      safeAreaPadding: EdgeInsets.fromLTRB(8, padding.top + 8, 8, padding.bottom + 88),
      resizable: true,
      snapToEdge: false,
      minSize: const Size(220, 124),
      maxSize: Size(screenSize.width - 24, (screenSize.width - 24) * 9 / 16),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      elevation: 16,
    );
  }

  Rect? _globalRectFor(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Rect _liveRouteTargetRect() {
    final mediaQuery = MediaQueryData.fromView(View.of(context));
    final width = mediaQuery.size.width - 32;
    final top = mediaQuery.padding.top + kToolbarHeight + 16;
    return Rect.fromLTWH(16, top, width, width * 9 / 16);
  }

  Rect _fallbackPipSourceRect() {
    final mediaQuery = MediaQueryData.fromView(View.of(context));
    final config = _kickStyleLivePipConfig(context);
    return config.initialRect ?? Rect.fromLTWH(12, mediaQuery.size.height * 0.34, 300, 169);
  }

  void _startPipFlight({
    required Rect begin,
    required Rect end,
    required Uint8List? snapshotBytes,
    required VoidCallback onCompleted,
  }) {
    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) {
      onCompleted();
      return;
    }
    _flightEntry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return _LivePipFlight(
          snapshotBytes: snapshotBytes,
          state: _LivePipFlightState(
            begin: begin,
            end: end,
            onCompleted: () {
              if (entry.mounted) {
                entry.remove();
              }
              if (_flightEntry == entry) {
                _flightEntry = null;
              }
              onCompleted();
            },
          ),
        );
      },
    );
    _flightEntry = entry;
    overlay.insert(entry);
  }

  void _showDemoInApp() {
    _controller.showInApp(
      config: const FlutterAppPipOverlayConfig(resizable: true),
      builder: (_, controller) => _MiniSurface(controller: controller),
    );
  }

  Future<void> _checkSupport() async {
    final supported = await _controller.checkSystemSupported();
    setState(() {
      _events.insert(0, 'support=$supported');
    });
  }

  Future<void> _startSystem() async {
    _prepareSystemPipVideoLayer();
    final started = await _controller.startSystem(_systemConfig(goHome: false));
    if (!started) {
      _clearSystemPipVideoLayer();
    }
  }

  Future<void> _enableAutoEnter() {
    return _controller.enableAutoEnterSystem(_systemConfig());
  }

  Future<void> _enableLiveAutoEnter() {
    return _controller.enableAutoEnterSystem(_systemConfig());
  }

  FlutterAppSystemPipConfig _systemConfig({bool goHome = false}) {
    return FlutterAppSystemPipConfig(
      aspectRatio: const Size(16, 9),
      videoUrl: liveStreamUrl,
      actions: const <FlutterAppSystemPipAction>{
        FlutterAppSystemPipAction.seekBackward,
        FlutterAppSystemPipAction.playPause,
        FlutterAppSystemPipAction.seekForward,
      },
      isPlaying: _liveSession.isPlaying,
      seekInterval: const Duration(seconds: 10),
      goHome: goHome,
    );
  }

  void _handleSystemEvent(FlutterAppSystemPipEvent event) {
    if (!mounted) {
      return;
    }
    setState(() {
      _events.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}  ${event.type.name}'
          '${event.active == null ? '' : '=${event.active}'}'
          '${event.action == null ? '' : '=${event.action!.name}'}'
          '${event.message == null ? '' : '  ${event.message}'}');
      if (_events.length > 6) {
        _events.removeLast();
      }
    });
    if (event.type == FlutterAppSystemPipEventType.activeChanged &&
        event.active == false &&
        _livePipPrepared &&
        !_liveRouteVisible) {
      _clearSystemPipVideoLayer();
      unawaited(_openLiveRoomFromPip());
    }
    if (event.type == FlutterAppSystemPipEventType.restoreRequested) {
      _clearSystemPipVideoLayer();
      unawaited(_openLiveRoomFromPip());
    }
    if (event.type == FlutterAppSystemPipEventType.prepareAutoEnter) {
      _prepareSystemPipVideoLayer();
    }
    if (event.type == FlutterAppSystemPipEventType.action) {
      unawaited(_handleSystemPipAction(event));
    }
  }

  Future<void> _handleSystemPipAction(FlutterAppSystemPipEvent event) async {
    switch (event.action) {
      case FlutterAppSystemPipAction.seekBackward:
      case FlutterAppSystemPipAction.seekForward:
        await _liveSession.seekBy(event.seekOffset ?? Duration.zero);
        return;
      case FlutterAppSystemPipAction.playPause:
        await _liveSession.togglePlayback();
        await _controller.updateSystemPlaybackState(_liveSession.isPlaying);
        return;
      case null:
        return;
    }
  }

  void _prepareSystemPipVideoLayer() {
    _liveVideoHostMode.value = _LiveVideoHostMode.system;
    if (_showSystemPipVideoLayer) {
      return;
    }
    setState(() {
      _showSystemPipVideoLayer = true;
    });
  }

  void _clearSystemPipVideoLayer() {
    if (_liveRouteVisible) {
      _liveVideoHostMode.value = _LiveVideoHostMode.live;
    } else if (_livePipPrepared) {
      _liveVideoHostMode.value = _LiveVideoHostMode.pip;
    }
    if (!_showSystemPipVideoLayer) {
      return;
    }
    setState(() {
      _showSystemPipVideoLayer = false;
    });
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.controller,
    required this.events,
    required this.onEnterLiveRoom,
    required this.stateMigrationDemo,
    required this.onShowDemoPip,
    required this.onCheckSupport,
    required this.onStartSystem,
    required this.onEnableAutoEnter,
  });

  final FlutterAppPipController controller;
  final List<String> events;
  final VoidCallback onEnterLiveRoom;
  final Widget stateMigrationDemo;
  final VoidCallback onShowDemoPip;
  final VoidCallback onCheckSupport;
  final VoidCallback onStartSystem;
  final VoidCallback onEnableAutoEnter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_app_pip')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LiveEntryCard(onEnterLiveRoom: onEnterLiveRoom),
          const SizedBox(height: 16),
          stateMigrationDemo,
          const SizedBox(height: 16),
          _DemoSurface(controller: controller),
          const SizedBox(height: 16),
          _StatePanel(controller: controller, events: events),
          const SizedBox(height: 16),
          _ControlPanel(
            title: 'In-app',
            children: [
              FilledButton(
                onPressed: onShowDemoPip,
                child: const Text('Start'),
              ),
              OutlinedButton(
                onPressed: controller.restoreFullScreen,
                child: const Text('Restore'),
              ),
              OutlinedButton(
                onPressed: controller.closeInApp,
                child: const Text('Close'),
              ),
              OutlinedButton(
                onPressed: () {
                  controller.updateInAppConfig(
                    const FlutterAppPipOverlayConfig(width: 220, height: 124),
                  );
                },
                child: const Text('Resize'),
              ),
              OutlinedButton(
                onPressed: () {
                  final height = MediaQuery.sizeOf(context).height;
                  controller.avoidCollision(
                    Rect.fromLTWH(0, height - 128, MediaQuery.sizeOf(context).width, 128),
                    padding: 12,
                  );
                },
                child: const Text('Avoid'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ControlPanel(
            title: 'System',
            children: [
              FilledButton(
                onPressed: onCheckSupport,
                child: const Text('Check'),
              ),
              FilledButton(
                onPressed: onStartSystem,
                child: const Text('Start'),
              ),
              OutlinedButton(
                onPressed: onEnableAutoEnter,
                child: const Text('Auto on'),
              ),
              OutlinedButton(
                onPressed: controller.disableAutoEnterSystem,
                child: const Text('Auto off'),
              ),
              OutlinedButton(
                onPressed: controller.stopSystem,
                child: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LivePipFlightState {
  const _LivePipFlightState({
    required this.begin,
    required this.end,
    required this.onCompleted,
  });

  final Rect begin;
  final Rect end;
  final VoidCallback onCompleted;
}

class _LivePipFlight extends StatefulWidget {
  const _LivePipFlight({
    required this.snapshotBytes,
    required this.state,
  });

  final Uint8List? snapshotBytes;
  final _LivePipFlightState state;

  @override
  State<_LivePipFlight> createState() => _LivePipFlightWidgetState();
}

class _LivePipFlightWidgetState extends State<_LivePipFlight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Rect?> _rectAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _rectAnimation = RectTween(
      begin: widget.state.begin,
      end: widget.state.end,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.state.onCompleted();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rectAnimation,
      builder: (context, child) {
        final rect = _rectAnimation.value ?? widget.state.end;
        return Positioned.fromRect(rect: rect, child: child!);
      },
      child: IgnorePointer(
        child: Material(
          key: const ValueKey('live-pip-flight'),
          color: Colors.transparent,
          elevation: 18,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: _LiveSnapshotFrame(
            snapshotBytes: widget.snapshotBytes,
            badge: 'LIVE',
            showCenterPause: true,
          ),
        ),
      ),
    );
  }
}

class _LiveSnapshotFrame extends StatelessWidget {
  const _LiveSnapshotFrame({
    required this.snapshotBytes,
    required this.badge,
    this.showCenterPause = false,
  });

  final Uint8List? snapshotBytes;
  final String badge;
  final bool showCenterPause;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: snapshotBytes == null
                  ? const ColoredBox(
                      key: ValueKey('live-pip-flight-snapshot'),
                      color: Colors.black,
                    )
                  : Image.memory(
                      snapshotBytes!,
                      key: const ValueKey('live-pip-flight-snapshot'),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    badge,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            if (showCenterPause)
              const Center(
                child: Icon(
                  Icons.pause,
                  color: Colors.white,
                  size: 38,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveEntryCard extends StatelessWidget {
  const _LiveEntryCard({required this.onEnterLiveRoom});

  final VoidCallback onEnterLiveRoom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live stream example', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Shared media_kit player, in-app PiP on back, system PiP on background.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onEnterLiveRoom,
              icon: const Icon(Icons.live_tv),
              label: const Text('Enter live room'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRoomPage extends StatelessWidget {
  const _LiveRoomPage({
    required this.session,
    required this.videoKey,
    required this.videoSurfaceKey,
    required this.videoHostMode,
    required this.onLeaveToPip,
    required this.onStartSystemPip,
  });

  final LiveVideoSession session;
  final GlobalKey videoKey;
  final GlobalKey videoSurfaceKey;
  final ValueListenable<_LiveVideoHostMode> videoHostMode;
  final void Function(BuildContext context) onLeaveToPip;
  final VoidCallback onStartSystemPip;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onLeaveToPip(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('GOSH Live Room'),
          leading: BackButton(onPressed: () => onLeaveToPip(context)),
          actions: [
            IconButton(
              tooltip: 'Start system PiP',
              onPressed: onStartSystemPip,
              icon: const Icon(Icons.picture_in_picture_alt),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LiveVideoFrame(
              key: videoKey,
              session: session,
              videoSurfaceKey: videoSurfaceKey,
              videoHostMode: videoHostMode,
              videoHost: _LiveVideoHostMode.live,
              badge: 'LIVE',
              actions: const [],
            ),
            const SizedBox(height: 16),
            Text(
              'Returning from this page keeps the same media_kit Player alive and moves the video into in-app PiP.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePipSurface extends StatelessWidget {
  const _LivePipSurface({
    required this.session,
    required this.controller,
    required this.frameKey,
    required this.videoSurfaceKey,
    required this.videoHostMode,
    required this.onExpand,
  });

  final LiveVideoSession session;
  final FlutterAppPipController controller;
  final GlobalKey frameKey;
  final GlobalKey videoSurfaceKey;
  final ValueListenable<_LiveVideoHostMode> videoHostMode;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: frameKey,
      child: _LiveVideoFrame(
        key: const ValueKey('live-pip-surface'),
        session: session,
        videoSurfaceKey: videoSurfaceKey,
        videoHostMode: videoHostMode,
        videoHost: _LiveVideoHostMode.pip,
        badge: 'Live PiP',
        actions: [
          IconButton.filledTonal(
            tooltip: 'Close live PiP',
            onPressed: controller.closeInApp,
            icon: const Icon(Icons.close),
          ),
          IconButton.filledTonal(
            tooltip: 'Expand live room',
            onPressed: onExpand,
            icon: const Icon(Icons.open_in_full),
          ),
        ],
        showCenterPause: true,
      ),
    );
  }
}

class _LiveSystemPipSurface extends StatelessWidget {
  const _LiveSystemPipSurface({
    required this.session,
    required this.videoSurfaceKey,
  });

  final LiveVideoSession session;
  final GlobalKey videoSurfaceKey;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('live-system-pip-surface'),
      color: Colors.black,
      child: _LiveVideoSurface(
        key: videoSurfaceKey,
        session: session,
      ),
    );
  }
}

class _LiveVideoSurface extends StatelessWidget {
  const _LiveVideoSurface({
    super.key,
    required this.session,
  });

  final LiveVideoSession session;

  @override
  Widget build(BuildContext context) {
    return session.buildVideo(key: const ValueKey('live-video'));
  }
}

class _LiveVideoPlaceholder extends StatelessWidget {
  const _LiveVideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}

class _LiveVideoFrame extends StatelessWidget {
  const _LiveVideoFrame({
    super.key,
    required this.session,
    required this.videoSurfaceKey,
    required this.videoHostMode,
    required this.videoHost,
    required this.badge,
    required this.actions,
    this.showCenterPause = false,
  });

  final LiveVideoSession session;
  final GlobalKey videoSurfaceKey;
  final ValueListenable<_LiveVideoHostMode> videoHostMode;
  final _LiveVideoHostMode videoHost;
  final String badge;
  final List<Widget> actions;
  final bool showCenterPause;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<_LiveVideoHostMode>(
                valueListenable: videoHostMode,
                builder: (context, currentHost, _) {
                  if (currentHost != videoHost) {
                    return const _LiveVideoPlaceholder();
                  }
                  return _LiveVideoSurface(
                    key: videoSurfaceKey,
                    session: session,
                  );
                },
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    badge,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Wrap(spacing: 4, children: actions),
            ),
            if (showCenterPause)
              const Center(
                child: Icon(
                  Icons.pause,
                  color: Colors.white,
                  size: 38,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DemoSurface extends StatelessWidget {
  const _DemoSurface({required this.controller});

  final FlutterAppPipController controller;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF101820),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _AnimatedStripes()),
            Positioned(
              left: 16,
              bottom: 16,
              child: FilledButton.icon(
                onPressed: () {
                  controller.showInApp(
                    config: const FlutterAppPipOverlayConfig(resizable: true),
                    builder: (_, currentController) => _MiniSurface(controller: currentController),
                  );
                },
                icon: const Icon(Icons.picture_in_picture_alt),
                label: const Text('PiP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSurface extends StatelessWidget {
  const _MiniSurface({required this.controller});

  final FlutterAppPipController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF101820),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _AnimatedStripes(),
          Align(
            alignment: Alignment.topRight,
            child: IconButton.filledTonal(
              onPressed: controller.closeInApp,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStripes extends StatelessWidget {
  const _AnimatedStripes();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StripePainter());
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF101820);
    canvas.drawRect(Offset.zero & size, background);
    final colors = [
      const Color(0xFF0E7C66),
      const Color(0xFFE8C547),
      const Color(0xFFD64550),
    ];
    for (var i = 0; i < 9; i++) {
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: 0.72);
      final left = size.width * i / 8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left - 40, 0, 28, size.height),
          const Radius.circular(14),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.controller, required this.events});

  final FlutterAppPipController controller;
  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.mode,
        controller.isSystemSupported,
        controller.isAutoEnterEnabled,
        controller.isSystemActive,
      ]),
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('mode ${controller.mode.value.name}')),
                    Chip(label: Text('supported ${controller.isSystemSupported.value}')),
                    Chip(label: Text('active ${controller.isSystemActive.value}')),
                    Chip(label: Text('auto ${controller.isAutoEnterEnabled.value}')),
                  ],
                ),
                if (events.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final event in events) Text(event),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}
