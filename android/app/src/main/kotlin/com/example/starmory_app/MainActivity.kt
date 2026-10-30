package com.example.starmory_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WidgetMidnightScheduler.scheduleNextMidnight(this)
    }

    // Required for singleTop launchMode: pass new widget-tap intents to Flutter
    // so HomeWidget.widgetClicked stream fires correctly when app is in background.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}