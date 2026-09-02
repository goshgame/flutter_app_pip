# Production Player PiP Demo

这套示例按照正式项目的生命周期拆分，可通过独立入口运行：

```bash
flutter run -t lib/production_player_pip_demo/main.dart
```

## 分层

- `domain`：直播和视频场景标识，不依赖页面。
- `application`：全局 PiP Service、播放器 Session 接口和资源生命周期。
- `infrastructure`：示例使用 MediaKit；项目接入时替换为 LivePlayer 和 CoreVideoPlayer 适配器。
- `presentation`：App 装配、页面宿主、根 Overlay 小窗和页面恢复。

## 项目替换点

1. App 模块创建并注册唯一 `PlayerPipService`。
2. App Widget 只挂载 `FlutterAppPipScope`，不持有直播或视频业务状态。
3. 直播 Session 持有 `RoomLiveManager`，页面退出小窗时使用 `leaveRoom(mini: true)`。
4. 视频 Session 持有 `CoreVideoPlayerController`，不要由 `VideoDetailPageState.dispose()` 释放浮窗中的实例。
5. 将示例的 Navigator 调用替换为项目 `RouteService` 或 `AppPathRouter`。
6. 页面只负责播放器区域 Rect；Session 创建、抢占和释放统一由 Service 处理。
