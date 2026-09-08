package com.gosh.flutter_app_pip

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import io.flutter.embedding.android.FlutterSurfaceView
import kotlin.math.max
import kotlin.math.roundToInt

/** 仅在 Android 8-11 的手动 PiP 进入流程中使用，位图始终留在原生内存。 */
internal class PipSnapshotOverlay(private val activity: Activity) {
    private val handler = Handler(Looper.getMainLooper())
    private var generation = 0
    private var overlay: ImageView? = null
    private var verificationPending = false
    private val watchdog = Runnable {
        // 超时是失败兜底，不作为正常撤罩条件，避免播放器永久停留在快照上。
        Log.println(Log.WARN, TAG, "snapshot watchdog expired; removing stale overlay")
        clear()
    }

    fun capture(source: Rect?) {
        clear()
        val host = activity.findViewById<ViewGroup>(android.R.id.content)
        val surface = findSurface(host)
        if (source == null || host == null || surface == null ||
            host.width <= 0 || host.height <= 0 || !surface.holder.surface.isValid) {
            Log.println(Log.WARN, TAG, "snapshot unavailable: missing video bounds or Flutter surface")
            return
        }
        val surfaceLocation = IntArray(2)
        surface.getLocationInWindow(surfaceLocation)
        val copyRect = Rect(source).apply { offset(-surfaceLocation[0], -surfaceLocation[1]) }
        if (!copyRect.intersect(0, 0, surface.width, surface.height)) {
            Log.println(Log.WARN, TAG, "snapshot video bounds are outside Flutter surface")
            return
        }
        val scale = minOf(1f, 1280f / max(copyRect.width(), copyRect.height()))
        val bitmap = Bitmap.createBitmap(
            max(1, (copyRect.width() * scale).roundToInt()),
            max(1, (copyRect.height() * scale).roundToInt()),
            Bitmap.Config.ARGB_8888,
        )
        val request = generation
        handler.postDelayed(watchdog, 3000)
        try {
            PixelCopy.request(surface, copyRect, bitmap, { status ->
                if (request != generation) {
                    bitmap.recycle()
                    return@request
                }
                if (status != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    Log.println(Log.WARN, TAG, "snapshot capture failed: PixelCopy=$status")
                    clear()
                    return@request
                }
                val hostLocation = IntArray(2)
                host.getLocationInWindow(hostLocation)
                val displayedRect = Rect(copyRect).apply {
                    offset(surfaceLocation[0] - hostLocation[0], surfaceLocation[1] - hostLocation[1])
                }
                val image = SnapshotView(activity, bitmap, displayedRect, host.width, host.height)
                overlay = image
                // 覆盖 Flutter 的独立 Surface，但不拦截系统小窗或页面手势。
                host.addView(image, ViewGroup.LayoutParams(-1, -1))
                // 取帧和缩窗并行，遮罩挂载后由下一次原生 traversal 提交。
                Log.println(Log.INFO, TAG, "snapshot attached")
            }, handler)
        } catch (error: IllegalArgumentException) {
            bitmap.recycle()
            Log.println(Log.WARN, TAG, "snapshot capture rejected: ${Log.getStackTraceString(error)}")
            clear()
        }
    }

    /** Dart 已确认目标布局完成栅格化，再从 Surface 取帧确认缓冲区可读。 */
    fun completeRenderedFrame() {
        Log.println(Log.INFO, TAG, "raster acknowledgement overlay=${overlay != null}")
        if (overlay == null || verificationPending) return
        val surface = findSurface(activity.findViewById(android.R.id.content)) ?: return
        if (!activity.isInPictureInPictureMode || !surface.holder.surface.isValid) return
        verificationPending = true
        val request = generation
        val probe = Bitmap.createBitmap(16, 9, Bitmap.Config.ARGB_8888)
        try {
            PixelCopy.request(surface, probe, { status ->
                probe.recycle()
                if (request != generation) return@request
                verificationPending = false
                if (status == PixelCopy.SUCCESS) {
                    Log.println(Log.INFO, TAG, "PiP raster frame readable; removing snapshot")
                    clear()
                } else {
                    Log.println(Log.WARN, TAG, "PiP frame not readable yet: PixelCopy=$status")
                    overlay?.postOnAnimation { completeRenderedFrame() }
                }
            }, handler)
        } catch (error: IllegalArgumentException) {
            probe.recycle()
            verificationPending = false
            Log.println(Log.WARN, TAG, "PiP frame verification rejected: ${Log.getStackTraceString(error)}")
            overlay?.postOnAnimation { completeRenderedFrame() }
        }
    }

    fun clear() {
        Log.println(Log.INFO, TAG, "clear overlay=${overlay != null}")
        generation++
        handler.removeCallbacks(watchdog)
        verificationPending = false
        overlay?.let { image ->
            (image.parent as? ViewGroup)?.removeView(image)
            image.setImageDrawable(null)
        }
        overlay = null
    }

    private fun findSurface(view: View?): FlutterSurfaceView? {
        if (view is FlutterSurfaceView) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findSurface(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    private class SnapshotView(
        activity: Activity,
        private val bitmap: Bitmap,
        private val source: Rect,
        private val initialWidth: Int,
        private val initialHeight: Int,
    ) : ImageView(activity) {
        init {
            scaleType = ScaleType.MATRIX
            setImageBitmap(bitmap)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            // 入场起点保持实际视频位置；Activity 缩窗后由原生层直接铺满视频区域。
            val target = if (w >= initialWidth * 0.9f && h >= initialHeight * 0.8f) {
                RectF(source)
            } else {
                RectF(0f, 0f, w.toFloat(), h.toFloat())
            }
            imageMatrix = Matrix().apply {
                setRectToRect(RectF(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat()),
                    target, Matrix.ScaleToFit.CENTER)
            }
        }
    }

    companion object {
        private const val TAG = "PipSnapshot"
    }
}
