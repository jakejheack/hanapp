package com.example.hanapp

import io.flutter.app.FlutterApplication
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import android.util.Log

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()

        // Initialize Facebook SDK
        try {
            FacebookSdk.sdkInitialize(applicationContext)
            AppEventsLogger.activateApp(this)
            Log.d("FACEBOOK_SDK", "Facebook SDK initialized successfully in MainApplication")
        } catch (e: Exception) {
            Log.e("FACEBOOK_SDK", "Failed to initialize Facebook SDK in MainApplication", e)
        }
    }
}
