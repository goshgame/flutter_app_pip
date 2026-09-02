import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_app_pip/flutter_app_pip.dart';

import '../application/player_pip_service.dart';
import 'another_page.dart';
import 'player_surface.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.service,
    this.restoring = false,
  });

  final PlayerPipService service;
  final bool restoring;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final GlobalKey _playerFrameKey = GlobalKey();
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.restoring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(widget.service.restoreToPage(targetRect: _globalRect()));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.service.session.value;
    if (current == null) {
      return const SizedBox.shrink();
    }
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_leaveToPip());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(current.scene.title),
          leading: BackButton(onPressed: () => unawaited(_leaveToPip())),
          actions: [
            IconButton(
              tooltip: 'Open another page with PiP',
              onPressed: () => unawaited(_openAnotherPage()),
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              key: _playerFrameKey,
              aspectRatio: current.scene.aspectRatio,
              child: ColoredBox(
                color: Colors.black,
                child: FlutterAppPipPageSlot(
                  controller: widget.service.controller,
                  placeholder: const ColoredBox(color: Colors.black),
                  builder: (_, contentKey) {
                    return PlayerSurface(
                      key: contentKey,
                      session: current,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Scene: ${current.scene.type.name} / ${current.scene.id}'),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveToPip() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    final moved = await widget.service.movePageToInApp(config: _pipConfig());
    if (moved && mounted) {
      Navigator.of(context).pop();
      return;
    }
    _leaving = false;
  }

  Future<void> _openAnotherPage() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    final navigator = Navigator.of(context);
    final moved = await widget.service.movePageToInApp(config: _pipConfig());
    if (!moved || !mounted) {
      _leaving = false;
      return;
    }
    unawaited(
      navigator.pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: (_) => const AnotherPage()),
      ),
    );
  }

  FlutterAppPipOverlayConfig _pipConfig() {
    final screenSize = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final width = min(240.0, screenSize.width * 0.56);
    final aspectRatio =
        widget.service.session.value?.scene.aspectRatio ?? 16 / 9;
    return FlutterAppPipOverlayConfig(
      width: width,
      height: width / aspectRatio,
      aspectRatio: aspectRatio,
      transitionSourceRect: _globalRect(),
      safeAreaPadding: EdgeInsets.fromLTRB(
        12,
        padding.top + 12,
        12,
        padding.bottom + 24,
      ),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    );
  }

  Rect? _globalRect() {
    final renderObject = _playerFrameKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
}
