import 'package:flutter/widgets.dart';

import 'flutter_app_system_pip_action.dart';

class FlutterAppSystemPipConfig {
  const FlutterAppSystemPipConfig({
    this.aspectRatio,
    this.sourceRectHint,
    this.videoUrl,
    this.filePath,
    this.assetName,
    this.sourceContentView,
    this.contentView,
    this.actions = const <FlutterAppSystemPipAction>{},
    this.isPlaying = true,
    this.seekInterval = const Duration(seconds: 10),
    this.autoEnterEnabled = false,
    this.goHome = false,
    this.extra = const <String, Object?>{},
  });

  final Size? aspectRatio;
  final Rect? sourceRectHint;
  final String? videoUrl;
  final String? filePath;
  final String? assetName;
  final int? sourceContentView;
  final int? contentView;
  final Set<FlutterAppSystemPipAction> actions;
  final bool isPlaying;
  final Duration seekInterval;
  final bool autoEnterEnabled;
  final bool goHome;
  final Map<String, Object?> extra;

  FlutterAppSystemPipConfig copyWith({
    Size? aspectRatio,
    Rect? sourceRectHint,
    String? videoUrl,
    String? filePath,
    String? assetName,
    int? sourceContentView,
    int? contentView,
    Set<FlutterAppSystemPipAction>? actions,
    bool? isPlaying,
    Duration? seekInterval,
    bool? autoEnterEnabled,
    bool? goHome,
    Map<String, Object?>? extra,
  }) {
    return FlutterAppSystemPipConfig(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      sourceRectHint: sourceRectHint ?? this.sourceRectHint,
      videoUrl: videoUrl ?? this.videoUrl,
      filePath: filePath ?? this.filePath,
      assetName: assetName ?? this.assetName,
      sourceContentView: sourceContentView ?? this.sourceContentView,
      contentView: contentView ?? this.contentView,
      actions: actions ?? this.actions,
      isPlaying: isPlaying ?? this.isPlaying,
      seekInterval: seekInterval ?? this.seekInterval,
      autoEnterEnabled: autoEnterEnabled ?? this.autoEnterEnabled,
      goHome: goHome ?? this.goHome,
      extra: extra ?? this.extra,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (aspectRatio != null) 'aspectWidth': aspectRatio!.width,
      if (aspectRatio != null) 'aspectHeight': aspectRatio!.height,
      if (sourceRectHint != null) 'sourceLeft': sourceRectHint!.left,
      if (sourceRectHint != null) 'sourceTop': sourceRectHint!.top,
      if (sourceRectHint != null) 'sourceRight': sourceRectHint!.right,
      if (sourceRectHint != null) 'sourceBottom': sourceRectHint!.bottom,
      if (videoUrl?.isNotEmpty == true) 'videoUrl': videoUrl,
      if (filePath?.isNotEmpty == true) 'filePath': filePath,
      if (assetName?.isNotEmpty == true) 'assetName': assetName,
      if (sourceContentView != null) 'sourceContentView': sourceContentView,
      if (contentView != null) 'contentView': contentView,
      if (actions.isNotEmpty)
        'actions': actions.map((action) => action.name).toList(growable: false),
      if (actions.isNotEmpty) 'isPlaying': isPlaying,
      if (actions.isNotEmpty)
        'seekIntervalMilliseconds': seekInterval.inMilliseconds,
      if (autoEnterEnabled) 'autoEnterEnabled': autoEnterEnabled,
      'goHome': goHome,
      ...extra,
    };
  }
}
