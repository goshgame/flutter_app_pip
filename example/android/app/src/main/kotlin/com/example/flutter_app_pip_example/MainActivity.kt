package com.example.flutter_app_pip_example

import android.app.PictureInPictureUiState
import android.content.res.Configuration
import android.os.Build
import com.gosh.flutter_app_pip.FlutterAppPipPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onPictureInPictureRequested(): Boolean {
        FlutterAppPipPlugin.dispatchPictureInPictureRequested()
        return super.onPictureInPictureRequested()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        FlutterAppPipPlugin.dispatchPictureInPictureModeChanged(isInPictureInPictureMode)
    }

    override fun onPictureInPictureUiStateChanged(pipState: PictureInPictureUiState) {
        super.onPictureInPictureUiStateChanged(pipState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM &&
            pipState.isTransitioningToPip
        ) {
            FlutterAppPipPlugin.dispatchPictureInPictureTransitionStarted()
        }
    }
}
