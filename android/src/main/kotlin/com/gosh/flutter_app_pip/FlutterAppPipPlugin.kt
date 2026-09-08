package com.gosh.flutter_app_pip

import android.app.Activity
import android.app.Application
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.graphics.drawable.Icon
import android.util.Log
import android.util.Rational
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.lang.ref.WeakReference

class FlutterAppPipPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "flutter_app_pip/system"
        private const val TAG = "FlutterAppPip"
        private const val SUPPORTS_PICTURE_IN_PICTURE_FLAG = 0x00400000
        private const val DEFAULT_ASPECT_WIDTH = 9
        private const val DEFAULT_ASPECT_HEIGHT = 16
        private const val EXTRA_PIP_ACTION = "flutter_app_pip_action"
        private const val ACTION_SEEK_BACKWARD = "seekBackward"
        private const val ACTION_PLAY_PAUSE = "playPause"
        private const val ACTION_SEEK_FORWARD = "seekForward"
        private const val PIP_CONTROL_BROADCAST = "com.gosh.flutter_app_pip.PIP_CONTROL"
        private const val DEFAULT_SEEK_INTERVAL_MILLISECONDS = 10_000L
        private var activeInstance: WeakReference<FlutterAppPipPlugin>? = null

        @JvmStatic
        fun dispatchPictureInPictureModeChanged(active: Boolean) {
            activeInstance?.get()?.notifyActiveChanged(active)
        }

    }

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var application: Application? = null
    private var autoEnterEnabled = false
    private var autoEnterArguments: Map<*, *>? = null
    private var lastKnownPipActive: Boolean? = null
    private var orientationBeforePip: Int? = null
    private var currentPipArguments: MutableMap<Any?, Any?>? = null
    private var applicationContext: Context? = null
    private var actionReceiverRegistered = false
    private var snapshotOverlay: PipSnapshotOverlay? = null

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.getStringExtra(EXTRA_PIP_ACTION) ?: return
            Log.i(TAG, "PiP action received: $action")
            notifyPipAction(action)
        }
    }

    private val userLeaveHintListener = PluginRegistry.UserLeaveHintListener {
        val hostActivity = activity ?: return@UserLeaveHintListener
        if (autoEnterEnabled && !isInPip(hostActivity)) {
            prepareActivityOrientationForPip(hostActivity)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
                autoEnterArguments?.get("snapshotOverlayEnabled") == true) {
                val snapshot = snapshotOverlay ?: PipSnapshotOverlay(hostActivity).also {
                    snapshotOverlay = it
                }
                // 在尺寸改变前发起取帧，但同步进入 PiP，避免异步等待错过 Home 动画。
                snapshot.capture(buildSourceRect(autoEnterArguments))
                notifyPrepareAutoEnter()
                if (!enterPictureInPictureIfEnabled(hostActivity)) snapshot.clear()
            } else {
                notifyPrepareAutoEnter()
            }
        }
    }

    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityPaused(pausedActivity: Activity) {
        }

        override fun onActivityResumed(resumedActivity: Activity) {
            if (resumedActivity == activity && !isInPip(resumedActivity)) {
                notifyActiveChanged(false)
            }
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
        override fun onActivityStarted(activity: Activity) {}
        override fun onActivityStopped(activity: Activity) {}
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
        override fun onActivityDestroyed(activity: Activity) {}
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        applicationContext = binding.applicationContext
        registerActionReceiver(binding.applicationContext)
        activeInstance = WeakReference(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        snapshotOverlay?.clear()
        snapshotOverlay = null
        channel.setMethodCallHandler(null)
        unregisterActionReceiver()
        applicationContext = null
        if (activeInstance?.get() === this) {
            activeInstance = null
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val hostActivity = activity
        when (call.method) {
            "isSupported" -> result.success(hostActivity?.let(::isSupported) == true)
            "isAutoEnterSupported" -> result.success(hostActivity?.let(::isSupported) == true)
            "start" -> {
                if (hostActivity == null) {
                    result.success(false)
                    return
                }
                val started = start(hostActivity, call.arguments as? Map<*, *>)
                result.success(started)
            }
            "enableAutoEnter" -> {
                if (hostActivity == null || !isSupported(hostActivity)) {
                    autoEnterEnabled = false
                    autoEnterArguments = null
                    result.success(false)
                    return
                }
                autoEnterEnabled = true
                autoEnterArguments = call.arguments as? Map<*, *>
                currentPipArguments = autoEnterArguments?.toMutableMap()
                hostActivity.setPictureInPictureParams(buildParams(hostActivity, autoEnterArguments))
                Log.i(TAG, "auto-enter enabled sdk=${Build.VERSION.SDK_INT}")
                result.success(true)
            }
            "completeAutoEnter" -> {
                if (hostActivity != null && isInPip(hostActivity)) {
                    result.success(true)
                    return
                }
                if (hostActivity == null || !autoEnterEnabled) {
                    result.success(false)
                    return
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+ 已由系统读取 setAutoEnterEnabled，回执只表示 Flutter 宿主准备完成。
                    Log.d(TAG, "Flutter host prepared; Android 12+ handles auto-enter")
                    result.success(true)
                    return
                }
                // 快照分支已在 onUserLeaveHint 同步进入；Dart 回执无需重复进入或截帧。
                val entered = enterPictureInPictureIfEnabled(hostActivity)
                Log.i(TAG, "Flutter host prepared; legacy auto-enter result=$entered")
                result.success(entered)
            }
            "completeRenderedFrame" -> {
                snapshotOverlay?.completeRenderedFrame()
                result.success(true)
            }
            "disableAutoEnter" -> {
                disableAutoEnter(hostActivity)
                result.success(true)
            }
            "updatePlaybackState" -> {
                val isPlaying = call.argument<Boolean>("isPlaying")
                if (hostActivity == null || isPlaying == null) {
                    result.success(false)
                    return
                }
                result.success(updatePlaybackState(hostActivity, isPlaying))
            }
            "stop" -> {
                if (hostActivity == null) {
                    result.success(false)
                    return
                }
                result.success(stop(hostActivity))
            }
            "dispose" -> {
                disableAutoEnter(hostActivity)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun onPictureInPictureModeChanged(active: Boolean) {
        notifyActiveChanged(active)
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        detachActivity()
        val newActivity = binding.activity
        activityPluginBinding = binding
        activity = newActivity
        application = newActivity.application
        application?.registerActivityLifecycleCallbacks(lifecycleCallbacks)
        binding.addOnUserLeaveHintListener(userLeaveHintListener)
    }

    private fun detachActivity() {
        snapshotOverlay?.clear()
        snapshotOverlay = null
        activity?.let(::restoreActivityOrientationAfterPip)
        activityPluginBinding?.removeOnUserLeaveHintListener(userLeaveHintListener)
        activityPluginBinding = null
        application?.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)
        application = null
        activity = null
    }

    private fun isSupported(hostActivity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        if (!hostActivity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
            return false
        }
        return activityDeclaredSupportsPip(hostActivity)
    }

    private fun start(hostActivity: Activity, arguments: Map<*, *>?): Boolean {
        if (!isSupported(hostActivity) || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            notifyUnsupported()
            return false
        }
        prepareActivityOrientationForPip(hostActivity)
        return try {
            currentPipArguments = arguments?.toMutableMap()
            val entered = hostActivity.enterPictureInPictureMode(buildParams(hostActivity, arguments))
            if (entered) {
                notifyActiveChanged(true)
                if (arguments?.get("goHome") == true) {
                    goHome(hostActivity)
                }
            } else {
                restoreActivityOrientationAfterPip(hostActivity)
                Log.w(TAG, "enterPictureInPictureMode returned false")
                notifyStartFailed("enterPictureInPictureMode returned false")
            }
            entered
        } catch (e: Exception) {
            restoreActivityOrientationAfterPip(hostActivity)
            Log.e(TAG, "start failed", e)
            notifyStartFailed(e.message)
            false
        }
    }

    private fun enterPictureInPictureIfEnabled(hostActivity: Activity): Boolean {
        if (!autoEnterEnabled || Build.VERSION.SDK_INT < Build.VERSION_CODES.O || isInPip(hostActivity)) {
            return false
        }
        val arguments = autoEnterArguments?.toMutableMap() ?: mutableMapOf<Any?, Any?>()
        arguments["goHome"] = false
        return start(hostActivity, arguments)
    }

    private fun disableAutoEnter(hostActivity: Activity?) {
        val wasEnabled = autoEnterEnabled
        if (hostActivity != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val arguments = autoEnterArguments?.toMutableMap()
                ?: mutableMapOf<Any?, Any?>()
            arguments["autoEnterEnabled"] = false
            hostActivity.setPictureInPictureParams(buildParams(hostActivity, arguments))
        }
        autoEnterEnabled = false
        autoEnterArguments = null
        if (lastKnownPipActive != true) {
            snapshotOverlay?.clear()
        }
        if (hostActivity == null || !isInPip(hostActivity)) {
            currentPipArguments = null
        }
        if (hostActivity != null && !isInPip(hostActivity)) {
            restoreActivityOrientationAfterPip(hostActivity)
        }
        if (wasEnabled) {
            Log.i(TAG, "auto-enter disabled")
        }
    }

    private fun stop(hostActivity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        return if (isInPip(hostActivity)) {
            hostActivity.moveTaskToBack(false)
            notifyActiveChanged(false)
            true
        } else {
            false
        }
    }

    private fun isInPip(hostActivity: Activity): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && hostActivity.isInPictureInPictureMode
    }

    private fun updatePlaybackState(hostActivity: Activity, isPlaying: Boolean): Boolean {
        val arguments = currentPipArguments ?: autoEnterArguments?.toMutableMap() ?: return false
        if (arguments["isPlaying"] == isPlaying) {
            return true
        }
        arguments["isPlaying"] = isPlaying
        currentPipArguments = arguments
        if (autoEnterEnabled) {
            autoEnterArguments = arguments.toMap()
        }
        return try {
            hostActivity.setPictureInPictureParams(buildParams(hostActivity, arguments))
            true
        } catch (e: Exception) {
            Log.e(TAG, "update playback state failed", e)
            false
        }
    }

    private fun buildParams(hostActivity: Activity, arguments: Map<*, *>?): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
        builder.setAspectRatio(buildAspectRatio(arguments))
        buildSourceRect(arguments)?.let(builder::setSourceRectHint)
        buildActions(hostActivity, arguments).takeIf { it.isNotEmpty() }?.let(builder::setActions)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ 只有把参数写回 Activity，关闭播放器后系统才不会继续自动进入 PiP。
            builder.setAutoEnterEnabled(arguments?.get("autoEnterEnabled") == true)
            // Flutter 默认使用 SurfaceView，关闭无缝缩放后由系统遮蔽窗口 resize 期间的空白帧。
            builder.setSeamlessResizeEnabled(
                arguments?.get("seamlessResizeEnabled") as? Boolean ?: true,
            )
        }
        return builder.build()
    }

    private fun buildActions(hostActivity: Activity, arguments: Map<*, *>?): List<RemoteAction> {
        val enabledActions = (arguments?.get("actions") as? List<*>)
            ?.mapNotNull { it as? String }
            ?.toSet()
            ?: return emptyList()
        val isPlaying = arguments["isPlaying"] == true
        val actionNames = listOf(ACTION_SEEK_BACKWARD, ACTION_PLAY_PAUSE, ACTION_SEEK_FORWARD)
        return actionNames
            .filter(enabledActions::contains)
            .take(hostActivity.maxNumPictureInPictureActions)
            .map { action -> buildRemoteAction(hostActivity, action, isPlaying) }
    }

    private fun buildRemoteAction(
        hostActivity: Activity,
        action: String,
        isPlaying: Boolean,
    ): RemoteAction {
        val (iconResource, labelResource, requestCode) = when (action) {
            ACTION_SEEK_BACKWARD -> Triple(
                android.R.drawable.ic_media_rew,
                R.string.flutter_app_pip_seek_backward,
                1,
            )
            ACTION_SEEK_FORWARD -> Triple(
                android.R.drawable.ic_media_ff,
                R.string.flutter_app_pip_seek_forward,
                3,
            )
            else -> Triple(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) R.string.flutter_app_pip_pause else R.string.flutter_app_pip_play,
                2,
            )
        }
        val label = hostActivity.getString(labelResource)
        val intent = Intent(PIP_CONTROL_BROADCAST).apply {
            setPackage(hostActivity.packageName)
            putExtra(EXTRA_PIP_ACTION, action)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            hostActivity,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return RemoteAction(
            Icon.createWithResource(hostActivity, iconResource),
            label,
            label,
            pendingIntent,
        )
    }

    private fun buildAspectRatio(arguments: Map<*, *>?): Rational {
        val width = (arguments?.get("aspectWidth") as? Number)?.toDouble() ?: DEFAULT_ASPECT_WIDTH.toDouble()
        val height = (arguments?.get("aspectHeight") as? Number)?.toDouble() ?: DEFAULT_ASPECT_HEIGHT.toDouble()
        if (width <= 0 || height <= 0) {
            return Rational(DEFAULT_ASPECT_WIDTH, DEFAULT_ASPECT_HEIGHT)
        }
        val ratio = width / height
        if (ratio < (1.0 / 2.39) || ratio > 2.39) {
            return Rational(DEFAULT_ASPECT_WIDTH, DEFAULT_ASPECT_HEIGHT)
        }
        return Rational((width * 1000).toInt(), (height * 1000).toInt())
    }

    private fun buildSourceRect(arguments: Map<*, *>?): Rect? {
        if (arguments == null) {
            return null
        }
        val left = (arguments["sourceLeft"] as? Number)?.toInt() ?: return null
        val top = (arguments["sourceTop"] as? Number)?.toInt() ?: return null
        val right = (arguments["sourceRight"] as? Number)?.toInt() ?: return null
        val bottom = (arguments["sourceBottom"] as? Number)?.toInt() ?: return null
        if (right <= left || bottom <= top) {
            return null
        }
        return Rect(left, top, right, bottom)
    }

    private fun activityDeclaredSupportsPip(hostActivity: Activity): Boolean {
        return try {
            val componentName: ComponentName = hostActivity.componentName
            val activityInfo: ActivityInfo = hostActivity.packageManager.getActivityInfo(componentName, 0)
            (activityInfo.flags and SUPPORTS_PICTURE_IN_PICTURE_FLAG) != 0
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e(TAG, "getActivityInfo failed", e)
            false
        }
    }

    private fun goHome(hostActivity: Activity) {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            hostActivity.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "goHome failed", e)
        }
    }

    private fun notifyActiveChanged(active: Boolean) {
        if (!active) {
            snapshotOverlay?.clear()
            activity?.let(::restoreActivityOrientationAfterPip)
        }
        if (lastKnownPipActive == active) {
            return
        }
        lastKnownPipActive = active
        if (!active) {
            currentPipArguments = autoEnterArguments?.toMutableMap()
        }
        Log.i(TAG, "system PiP active=$active")
        channel.invokeMethod("onActiveChanged", mapOf("active" to active))
    }

    private fun notifyPipAction(action: String) {
        val enabledActions = (currentPipArguments?.get("actions") as? List<*>)
            ?.mapNotNull { it as? String }
            ?.toSet()
            ?: return
        if (action !in enabledActions) {
            Log.w(TAG, "Ignoring disabled PiP action: $action")
            return
        }
        val seekInterval = (currentPipArguments?.get("seekIntervalMilliseconds") as? Number)
            ?.toLong()
            ?.takeIf { it > 0 }
            ?: DEFAULT_SEEK_INTERVAL_MILLISECONDS
        val seekOffset = when (action) {
            ACTION_SEEK_BACKWARD -> -seekInterval
            ACTION_SEEK_FORWARD -> seekInterval
            else -> null
        }
        channel.invokeMethod(
            "onAction",
            mapOf(
                "action" to action,
                "seekOffsetMilliseconds" to seekOffset,
            ),
        )
        Log.i(TAG, "PiP action dispatched to Flutter: $action offset=$seekOffset")
    }

    private fun registerActionReceiver(context: Context) {
        if (actionReceiverRegistered) {
            return
        }
        val filter = IntentFilter(PIP_CONTROL_BROADCAST)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(actionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(actionReceiver, filter)
        }
        actionReceiverRegistered = true
        Log.d(TAG, "PiP action receiver registered")
    }

    private fun unregisterActionReceiver() {
        val context = applicationContext ?: return
        if (!actionReceiverRegistered) {
            return
        }
        try {
            context.unregisterReceiver(actionReceiver)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "PiP action receiver was already unregistered", e)
        }
        actionReceiverRegistered = false
    }

    private fun prepareActivityOrientationForPip(hostActivity: Activity) {
        if (orientationBeforePip != null) {
            return
        }
        orientationBeforePip = hostActivity.requestedOrientation
        hostActivity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        Log.d(TAG, "system PiP orientation unlocked previous=$orientationBeforePip")
    }

    private fun restoreActivityOrientationAfterPip(hostActivity: Activity) {
        val previous = orientationBeforePip ?: return
        orientationBeforePip = null
        hostActivity.requestedOrientation = previous
        Log.d(TAG, "system PiP orientation restored value=$previous")
    }

    private fun notifyStartFailed(message: String?) {
        Log.w(TAG, "system PiP start failed: $message")
        channel.invokeMethod("onStartFailed", mapOf("message" to message))
    }

    private fun notifyUnsupported() {
        Log.w(TAG, "system PiP unsupported")
        channel.invokeMethod("onUnsupported", mapOf("message" to "Picture-in-Picture is unsupported"))
    }

    private fun notifyPrepareAutoEnter() {
        Log.d(TAG, "notify Flutter to prepare system PiP host")
        channel.invokeMethod("onPrepareAutoEnter", null)
    }
}
