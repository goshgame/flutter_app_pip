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
    if (_platforms.isEmpty) {
      _channel.setMethodCallHandler(_dispatchMethodCall);
    }
    _platforms.add(this);
  }

  static const channelName = 'flutter_app_pip/system';
  static final Set<MethodChannelFlutterAppSystemPipPlatform> _platforms = {};
  static MethodChannelFlutterAppSystemPipPlatform? _autoEnterOwner;
  static MethodChannelFlutterAppSystemPipPlatform? _startOwner;
  static MethodChannelFlutterAppSystemPipPlatform? _activePipOwner;
  static MethodChannelFlutterAppSystemPipPlatform? _restoreOwner;

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
    _startOwner = this;
    try {
      final started = await _channel.invokeMethod<bool>('start', config.toJson()) ?? false;
      if (started) {
        _activePipOwner = this;
        _restoreOwner = null;
      }
      return started;
    } finally {
      if (identical(_startOwner, this)) _startOwner = null;
    }
  }

  @override
  Future<bool> enableAutoEnter(FlutterAppSystemPipConfig config) async {
    _autoEnterOwner = this;
    try {
      final enabled = await _channel.invokeMethod<bool>('enableAutoEnter', config.toJson()) ?? false;
      if (!enabled && identical(_autoEnterOwner, this)) _autoEnterOwner = null;
      return enabled;
    } catch (_) {
      if (identical(_autoEnterOwner, this)) _autoEnterOwner = null;
      rethrow;
    }
  }

  @override
  Future<bool> completeAutoEnterPreparation() async {
    if (!identical(_autoEnterOwner, this)) return false;
    return await _channel.invokeMethod<bool>('completeAutoEnter') ?? false;
  }

  @override
  Future<bool> completeRenderedFrame() async {
    if (!identical(_autoEnterOwner, this) && !identical(_activePipOwner, this)) return false;
    return await _channel.invokeMethod<bool>('completeRenderedFrame') ?? false;
  }

  @override
  Future<bool> disableAutoEnter() async {
    // 已退出页面的异步关闭请求不能覆盖新页面启用的自动画中画。
    if ((_autoEnterOwner != null && !identical(_autoEnterOwner, this)) ||
        (_autoEnterOwner == null && _activePipOwner != null && !identical(_activePipOwner, this))) {
      return true;
    }
    _autoEnterOwner = null;
    return await _channel.invokeMethod<bool>('disableAutoEnter') ?? false;
  }

  @override
  Future<bool> updatePlaybackState(bool isPlaying) async {
    if (!identical(_autoEnterOwner, this) && !identical(_activePipOwner, this)) return true;
    return await _channel.invokeMethod<bool>(
          'updatePlaybackState',
          <String, Object?>{'isPlaying': isPlaying},
        ) ??
        false;
  }

  @override
  Future<bool> stop() async {
    if ((_activePipOwner != null && !identical(_activePipOwner, this)) ||
        (_activePipOwner == null && _autoEnterOwner != null && !identical(_autoEnterOwner, this))) {
      return true;
    }
    return await _channel.invokeMethod<bool>('stop') ?? false;
  }

  @override
  void dispose() {
    if (identical(_autoEnterOwner, this)) _autoEnterOwner = null;
    if (identical(_startOwner, this)) _startOwner = null;
    if (identical(_activePipOwner, this)) _activePipOwner = null;
    if (identical(_restoreOwner, this)) _restoreOwner = null;
    _platforms.remove(this);
    if (_platforms.isEmpty) _channel.setMethodCallHandler(null);
    _events.close();
  }

  static Future<void> _dispatchMethodCall(MethodCall call) async {
    MethodChannelFlutterAppSystemPipPlatform? owner;
    switch (call.method) {
      case 'onPrepareAutoEnter':
        owner = _autoEnterOwner;
      case 'onActiveChanged':
        final arguments = call.arguments;
        final active = arguments is Map ? arguments['active'] == true : arguments == true;
        owner = active
            ? _autoEnterOwner ?? _startOwner ?? _activePipOwner
            : _activePipOwner ?? _autoEnterOwner ?? _startOwner;
        if (active) {
          _activePipOwner = owner;
          _restoreOwner = null;
        } else {
          _restoreOwner = _activePipOwner;
          _activePipOwner = null;
        }
      case 'onAction':
        owner = _activePipOwner;
      case 'onRestoreRequested':
        owner = _activePipOwner ?? _restoreOwner;
      case 'onStartFailed':
      case 'onUnsupported':
        owner = _startOwner ?? _autoEnterOwner;
      default:
        return;
    }
    if (owner != null && _platforms.contains(owner)) owner._handleMethodCall(call);
  }

  void _handleMethodCall(MethodCall call) {
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
