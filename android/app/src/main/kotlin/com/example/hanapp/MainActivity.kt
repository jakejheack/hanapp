package com.example.hanapp

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import android.content.pm.PackageInfo
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.util.Log
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Facebook SDK
        try {
            FacebookSdk.sdkInitialize(applicationContext)
            AppEventsLogger.activateApp(application)
            Log.d("FACEBOOK_SDK", "Facebook SDK initialized successfully")
        } catch (e: Exception) {
            Log.e("FACEBOOK_SDK", "Failed to initialize Facebook SDK", e)
        }

        // Print Facebook Key Hash for development
        printKeyHash()
    }

    private fun printKeyHash() {
        try {
            val info: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                info.signatures
            }

            signatures?.forEach { signature ->
                val md = MessageDigest.getInstance("SHA")
                md.update(signature.toByteArray())
                val keyHash = Base64.encodeToString(md.digest(), Base64.DEFAULT)
                Log.d("FACEBOOK_KEY_HASH", "Key Hash: $keyHash")
                println("=== FACEBOOK KEY HASH ===")
                println("Package Name: $packageName")
                println("Key Hash: $keyHash")
                println("========================")
            }
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e("FACEBOOK_KEY_HASH", "Package not found", e)
        } catch (e: NoSuchAlgorithmException) {
            Log.e("FACEBOOK_KEY_HASH", "Algorithm not found", e)
        } catch (e: Exception) {
            Log.e("FACEBOOK_KEY_HASH", "Error generating key hash", e)
        }
    }
}
