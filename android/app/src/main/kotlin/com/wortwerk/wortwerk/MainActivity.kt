package com.wortwerk.wortwerk

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "learning_reminders",
                "Learning reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Wortwerk learning progress and gentle reminders"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
