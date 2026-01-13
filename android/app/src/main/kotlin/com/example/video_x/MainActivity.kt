package com.example.video_x

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// IMPORTANT: Extend AudioServiceActivity instead of FlutterActivity for audio_service to work!
class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.example.video_x/pip"
    private val ACTION_PLAY_PAUSE = "com.example.video_x.play_pause"
    
    // Receiver to handle PiP action clicks
    private val pipReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: android.content.Intent?) {
            if (intent == null || intent.action == null) return
            if (intent.action == ACTION_PLAY_PAUSE) {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { MethodChannel(it, CHANNEL).invokeMethod("playPause", null) }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register receiver
        val filter = android.content.IntentFilter()
        filter.addAction(ACTION_PLAY_PAUSE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(pipReceiver, filter, android.content.Context.RECEIVER_EXPORTED)
        } else {
             registerReceiver(pipReceiver, filter)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enterPictureInPicture") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val builder = PictureInPictureParams.Builder()
                    builder.setAspectRatio(Rational(16, 9))
                    updatePipParams(builder, true)
                    enterPictureInPictureMode(builder.build())
                    result.success(null)
                } else {
                    result.error("UNAVAILABLE", "PiP not supported on this Android version", null)
                }
            } else if (call.method == "updatePipState") {
                 if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val isPlaying = call.argument<Boolean>("playing") ?: false
                    val builder = PictureInPictureParams.Builder()
                    builder.setAspectRatio(Rational(16, 9))
                    updatePipParams(builder, isPlaying)
                    setPictureInPictureParams(builder.build())
                    result.success(null)
                 } else {
                     result.success(null)
                 }
            } else {
                result.notImplemented()
            }
        }

        // New Channel for Hard-Clearing Notifications
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.video_x/native_utils").setMethodCallHandler { call, result ->
            if (call.method == "clearNotifications") {
                try {
                    android.util.Log.d("VideoX", "Native: clearNotifications called")
                    val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    notificationManager.cancelAll()
                    android.util.Log.d("VideoX", "Native: Notifications Cancelled")

                    // FORCE STOP the Foreground Service
                    val intent = android.content.Intent(this, com.ryanheise.audioservice.AudioService::class.java)
                    val stopped = stopService(intent)
                    android.util.Log.d("VideoX", "Native: stopService called. Result: $stopped")
                    
                    // Toast for debugging (temporary)
                    // android.widget.Toast.makeText(this, "Service Stopped: $stopped", android.widget.Toast.LENGTH_SHORT).show()

                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e("VideoX", "Native: Fail: ${e.message}")
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun updatePipParams(builder: android.app.PictureInPictureParams.Builder, isPlaying: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val actions = java.util.ArrayList<android.app.RemoteAction>()
            
            val iconId = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
            val title = if (isPlaying) "Pause" else "Play"
            
            val icon = android.graphics.drawable.Icon.createWithResource(this, iconId)
            val intent = android.content.Intent(ACTION_PLAY_PAUSE)
            val pendingIntent = android.app.PendingIntent.getBroadcast(this, 10, intent, android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT)
            
            actions.add(android.app.RemoteAction(icon, title, title, pendingIntent))
            builder.setActions(actions)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(pipReceiver)
    }
}
