package io.github.sharedbyattmaker.bahtzay

import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val preferences by lazy { getSharedPreferences("bahtzay_notifications", MODE_PRIVATE) }
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bahtzay/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(status())
                    "disable" -> subscribe(false, result)
                    "enable" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            if (pendingPermission != null) {
                                result.error("permission_pending", null, null)
                            } else {
                                pendingPermission = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 281)
                            }
                        } else {
                            subscribe(true, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 281) return
        val result = pendingPermission ?: return
        pendingPermission = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            subscribe(true, result)
        } else {
            result.success(status() + ("error" to "ဖုန်း Settings မှာ အသိပေးချက် ခွင့်ပြုပေးပါ။"))
        }
    }

    private fun notificationsAllowed() =
        getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    private fun status() = mapOf(
        "supported" to true,
        "active" to (preferences.getBoolean("subscribed", false) && notificationsAllowed()),
        "subscribed" to preferences.getBoolean("subscribed", false)
    )

    private fun subscribe(enable: Boolean, result: MethodChannel.Result) {
        if (enable && !notificationsAllowed()) {
            result.success(status() + ("error" to "ဖုန်း Settings မှာ အသိပေးချက် ခွင့်ပြုပေးပါ။"))
            return
        }
        val messaging = FirebaseMessaging.getInstance()
        val topic = "bahtzay_android_updates"
        val task = if (enable) messaging.subscribeToTopic(topic) else messaging.unsubscribeFromTopic(topic)
        task.addOnCompleteListener {
            if (it.isSuccessful) {
                preferences.edit().putBoolean("subscribed", enable).apply()
                result.success(status())
            } else {
                result.success(status() + ("error" to "Noti ချိတ်ဆက်မှု မရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။"))
            }
        }
    }
}
