package com.apps.ispend.v1

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
  private val shortcutsChannel = "com.apps.ispend/shortcuts"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shortcutsChannel)
      .setMethodCallHandler { call, result ->
        if (call.method == "getMaxShortcutCount") {
          val maximum = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            getSystemService(Context.SHORTCUT_SERVICE) as ShortcutManager
          } else {
            null
          }
          result.success(maximum?.maxShortcutCountPerActivity ?: 0)
        } else {
          result.notImplemented()
        }
      }
  }

  override fun onNewIntent(intent: Intent) {
    setIntent(intent)
    super.onNewIntent(intent)
  }
}
