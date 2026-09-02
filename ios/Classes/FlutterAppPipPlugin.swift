import AVKit
import Flutter
import UIKit

public class FlutterAppPipPlugin: NSObject, FlutterPlugin {
    private static let channelName = "flutter_app_pip/system"

    private var channel: FlutterMethodChannel?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?
    private var autoEnterEnabled = false
    private var autoEnterArguments: [String: Any]?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterAppPipPlugin()
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(AVPictureInPictureController.isPictureInPictureSupported())

        case "isAutoEnterSupported":
            result(AVPictureInPictureController.isPictureInPictureSupported())

        case "start":
            guard AVPictureInPictureController.isPictureInPictureSupported() else {
                notifyUnsupported()
                result(false)
                return
            }
            guard let arguments = call.arguments as? [String: Any] else {
                notifyStartFailed("Missing PiP arguments")
                result(false)
                return
            }
            result(start(arguments))

        case "enableAutoEnter":
            guard
                AVPictureInPictureController.isPictureInPictureSupported(),
                let arguments = call.arguments as? [String: Any],
                prepare(arguments)
            else {
                autoEnterEnabled = false
                autoEnterArguments = nil
                result(false)
                return
            }
            autoEnterEnabled = true
            autoEnterArguments = arguments
            if #available(iOS 14.2, *) {
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            }
            log("auto-enter enabled")
            result(autoEnterEnabled)

        case "completeAutoEnter":
            guard autoEnterEnabled else {
                result(false)
                return
            }
            let started = startPreparedPlayer()
            log("Flutter host prepared; start result=\(started)")
            result(started)

        case "disableAutoEnter":
            autoEnterEnabled = false
            autoEnterArguments = nil
            stopAndCleanUp()
            log("auto-enter disabled")
            result(true)

        case "stop":
            pipController?.stopPictureInPicture()
            notifyActiveChanged(false)
            result(true)

        case "dispose":
            autoEnterEnabled = false
            autoEnterArguments = nil
            stopAndCleanUp()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @objc private func applicationWillResignActive() {
        guard
            autoEnterEnabled,
            pipController?.isPictureInPictureActive != true,
            autoEnterArguments != nil
        else {
            return
        }
        // 后台切换时不再临时创建播放器，先让 Flutter 准备宿主，再启动前台已预热的 PiP Controller。
        log("application will resign active; request Flutter host preparation")
        notifyPrepareAutoEnter()
    }

    private func start(_ arguments: [String: Any]) -> Bool {
        guard prepare(arguments) else {
            return false
        }
        return startPreparedPlayer()
    }

    private func prepare(_ arguments: [String: Any]) -> Bool {
        guard let url = resolveMediaURL(arguments) else {
            notifyStartFailed("iOS system PiP requires videoUrl, filePath, or assetName")
            return false
        }
        stopAndCleanUp()

        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        playerLayer.opacity = 0.01
        guard let hostLayer = UIApplication.shared.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController?
            .view.layer
        else {
            notifyStartFailed("Unable to find the active iOS window for system PiP")
            return false
        }
        hostLayer.addSublayer(playerLayer)
        self.player = player
        self.playerLayer = playerLayer

        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
            notifyStartFailed("Unable to create AVPictureInPictureController")
            return false
        }
        controller.delegate = self
        if #available(iOS 14.2, *) {
            controller.canStartPictureInPictureAutomaticallyFromInline = autoEnterEnabled
        }
        pipController = controller
        // preroll 只预热媒体，不在前台重复播放业务播放器的音频。
        player.preroll(atRate: 1.0) { _ in }
        log("system PiP player prepared")
        return true
    }

    private func startPreparedPlayer() -> Bool {
        guard
            let player = player,
            let controller = pipController,
            !controller.isPictureInPictureActive
        else {
            notifyStartFailed("System PiP player was not prepared")
            return false
        }
        player.isMuted = false
        player.play()
        controller.startPictureInPicture()
        log("requested system PiP start")
        return true
    }

    private func resolveMediaURL(_ arguments: [String: Any]) -> URL? {
        if let videoUrl = arguments["videoUrl"] as? String, !videoUrl.isEmpty {
            return URL(string: videoUrl)
        }
        if let filePath = arguments["filePath"] as? String, !filePath.isEmpty {
            return URL(fileURLWithPath: filePath)
        }
        if let assetName = arguments["assetName"] as? String, !assetName.isEmpty {
            if let path = Bundle.main.path(forResource: assetName, ofType: nil) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func stopAndCleanUp() {
        let hadResources = pipController != nil || player != nil || playerLayer != nil
        pipController?.stopPictureInPicture()
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        pipController = nil
        playerLayer = nil
        player = nil
        if hadResources {
            log("system PiP player cleaned up")
        }
    }

    private func notifyActiveChanged(_ active: Bool) {
        log("system PiP active=\(active)")
        channel?.invokeMethod("onActiveChanged", arguments: ["active": active])
    }

    private func notifyStartFailed(_ message: String) {
        log("system PiP start failed: \(message)")
        channel?.invokeMethod("onStartFailed", arguments: ["message": message])
    }

    private func notifyUnsupported() {
        log("system PiP unsupported")
        channel?.invokeMethod("onUnsupported", arguments: ["message": "Picture-in-Picture is unsupported"])
    }

    private func notifyPrepareAutoEnter() {
        log("notify Flutter to prepare system PiP host")
        channel?.invokeMethod("onPrepareAutoEnter", arguments: nil)
    }

    private func log(_ message: String) {
        NSLog("[FlutterAppPip] %@", message)
    }
}

extension FlutterAppPipPlugin: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        notifyActiveChanged(true)
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        notifyStartFailed(error.localizedDescription)
    }

    public func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        notifyActiveChanged(false)
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        channel?.invokeMethod("onRestoreRequested", arguments: nil)
        completionHandler(true)
    }
}
