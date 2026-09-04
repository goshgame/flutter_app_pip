import 'dart:async';

import 'package:flutter/services.dart';

import 'flutter_app_system_pip_action.dart';
import 'flutter_app_system_pip_config.dart';
import 'flutter_app_system_pip_event.dart';
import 'flutter_app_system_pip_platform.dart';

class MethodChannelFlutterAppSystemPipPlatform implements FlutterAppSystemPipPlatform {
  MethodChannelFlutterAppSystemPipPlatform({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const channelName = 'flutter_app_pip/system';

  final MethodChannel _channel;
  final StreamController<FlutterAppSystemPipEvent> _events =
      StreamController<FlutterAppSystemPipEvent>.broadcast();

  @override
  Stream<FlutterAppSystemPipEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async {
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<bool> isAutoEnterSupported() async {
    return await _channel.invokeMethod<bool>('isAutoEnterSupported') ?? false;
  }

  @override
  Future<bool> start(FlutterAppSystemPipConfig config) async {
    return await _channel.invokeMethod<bool>('start', config.toJson()) ?? false;
  }

  @override
  Future<bool> enableAutoEnter(FlutterAppSystemPipConfig config) async {
    return await _channel.invokeMethod<bool>('enableAutoEnter', config.toJson()) ?? false;
  }

  @override
  Future<bool> completeAutoEnterPreparation() async {
    return await _channel.invokeMethod<bool>('completeAutoEnter') ?? false;
  }

  @override
  Future<bool> disableAutoEnter() async {
    return await _channel.invokeMethod<bool>('disableAutoEnter') ?? false;
  }

  @override
  Future<bool> updatePlaybackState(bool isPlaying) async {
    return await _channel.invokeMethod<bool>(
          'updatePlaybackState',
          <String, Object?>{'isPlaying': isPlaying},
        ) ??
        false;
  }

  @override
  Future<bool> stop() async {
    return await _channel.invokeMethod<bool>('stop') ?? false;
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _events.close();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onActiveChanged':
        final arguments = call.arguments;
        final active = arguments is Map ? arguments['active'] == true : arguments == true;
        _events.add(FlutterAppSystemPipEvent.activeChanged(active));
      case 'onStartFailed':
        final arguments = call.arguments;
        final message = arguments is Map ? arguments['message']?.toString() : arguments?.toString();
        _events.add(FlutterAppSystemPipEvent.startFailed(message));
      case 'onUnsupported':
        final arguments = call.arguments;
        final message = arguments is Map ? arguments['message']?.toString() : arguments?.toString();
        _events.add(FlutterAppSystemPipEvent.unsupported(message));
      case 'onRestoreRequested':
        _events.add(FlutterAppSystemPipEvent.restoreRequested);
      case 'onPrepareAutoEnter':
        _events.add(FlutterAppSystemPipEvent.prepareAutoEnter);
      case 'onAction':
        final arguments = call.arguments;
        if (arguments is! Map) {
          return;
        }
        final action = _parseAction(arguments['action']);
        if (action == null) {
          return;
        }
        final seekOffsetMilliseconds = arguments['seekOffsetMilliseconds'];
        _events.add(
          FlutterAppSystemPipEvent.actionTriggered(
            action,
            seekOffset: seekOffsetMilliseconds is num
                ? Duration(milliseconds: seekOffsetMilliseconds.toInt())
                : null,
          ),
        );
      default:
        return;
    }
  }

  FlutterAppSystemPipAction? _parseAction(Object? value) {
    for (final action in FlutterAppSystemPipAction.values) {
      if (action.name == value) {
        return action;
      }
    }
    return null;
  }
}
