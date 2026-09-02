import 'package:flutter/widgets.dart';

import 'flutter_app_pip_controller.dart';
import 'in_app/flutter_app_pip_overlay_entry.dart';

class FlutterAppPipScope extends StatefulWidget {
  const FlutterAppPipScope({
    super.key,
    required this.controller,
    required this.child,
    this.navigatorKey,
  });

  final FlutterAppPipController controller;
  final Widget child;
  /// 兼容已有调用方；PiP 不再插入 Navigator Overlay。
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<FlutterAppPipScope> createState() => _FlutterAppPipScopeState();
}

class _FlutterAppPipScopeState extends State<FlutterAppPipScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.attach();
  }

  @override
  void didUpdateWidget(covariant FlutterAppPipScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach();
      widget.controller.attach();
    }
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FlutterAppPipInAppEntry?>(
      valueListenable: widget.controller.inAppEntry,
      child: widget.child,
      builder: (_, entry, child) {
        // child 可能包含 SmartDialog 根 Overlay，PiP 必须作为后置兄弟节点保持在其上方。
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            if (entry != null)
              Positioned.fill(
                // PiP 内容包含 Tooltip 等依赖 Overlay 的组件，需要独立宿主承接。
                child: Overlay.wrap(
                  child: FlutterAppPipOverlayEntry(
                    key: const ValueKey('flutter-app-pip-overlay-entry'),
                    controller: widget.controller,
                    entry: entry,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
