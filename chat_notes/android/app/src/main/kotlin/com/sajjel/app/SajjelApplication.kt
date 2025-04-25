package com.sajjel.app

import android.app.Application
import android.content.Context
import androidx.multidex.MultiDex
import io.flutter.app.FlutterApplication

class SajjelApplication : FlutterApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        // Enable multidex
        MultiDex.install(this)
    }

    override fun onCreate() {
        super.onCreate()
        // Initialize crash handling
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            throwable.printStackTrace()
            // Force restart the app if it crashes
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }
} 