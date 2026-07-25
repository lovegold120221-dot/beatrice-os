package com.eburon.beatrice.mobileuse

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.eburon.beatrice.MainActivity

class MobileUseRuntimeService : Service() {
    companion object {
        const val ACTION_START = "com.eburon.beatrice.mobileuse.START"
        const val ACTION_STOP = "com.eburon.beatrice.mobileuse.STOP"
        const val ACTION_UPDATE = "com.eburon.beatrice.mobileuse.UPDATE"
        const val EXTRA_STATE = "state"
        const val EXTRA_DETAIL = "detail"
        const val CHANNEL_ID = "beatrice_mobile_use"
        const val NOTIFICATION_ID = 4102

        @Volatile
        var isRunning: Boolean = false
            private set

    }

    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Beatrice mobile tasks",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Visible while a user-started Mobile Use session is active"
            },
        )
        persistState("ready", "No task is running")
        startForeground(
            NOTIFICATION_ID,
            buildNotification("ready", "No task is running"),
        )
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            isRunning = false
            persistState("stopped", "Stopped by the user")
            MobileUseChannel.notifyRuntimeStopped("Stopped from the Beatrice notification")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_UPDATE) {
            val state = intent.getStringExtra(EXTRA_STATE) ?: "active"
            val detail = intent.getStringExtra(EXTRA_DETAIL) ?: "Task in progress"
            persistState(state, detail)
            getSystemService(NotificationManager::class.java).notify(
                NOTIFICATION_ID,
                buildNotification(state, detail),
            )
            if (state in setOf("completed", "failed", "interrupted")) {
                isRunning = false
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf()
                return START_NOT_STICKY
            }
        }
        isRunning = true
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun persistState(state: String, detail: String) {
        getSharedPreferences("mobile_use_runtime", MODE_PRIVATE).edit()
            .putString("state", state)
            .putString("detail", detail.take(160))
            .apply()
    }

    private fun buildNotification(state: String, detail: String): android.app.Notification {
        val terminal = state in setOf("completed", "failed", "interrupted")
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentTitle(
                when (state) {
                    "starting" -> "Beatrice accepted your task"
                    "active" -> "Beatrice task in progress"
                    "waiting_confirmation" -> "Beatrice needs your approval"
                    "failed" -> "Beatrice task stopped"
                    "interrupted" -> "Beatrice task was interrupted"
                    "completed" -> "Beatrice task completed"
                    else -> "Beatrice mobile service is ready"
                },
            )
            .setContentText(detail)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setOngoing(!terminal)
            .setAutoCancel(terminal)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )

        if (!terminal) {
            builder.addAction(
                0,
                "Stop",
                PendingIntent.getService(
                    this,
                    1,
                    Intent(this, MobileUseRuntimeService::class.java).apply {
                        action = ACTION_STOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        return builder.build()
    }
}
