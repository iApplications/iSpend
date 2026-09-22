package com.apps.ispend.v1

import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
  private val shortcutsChannel = "com.apps.ispend/shortcuts"
  private val quickSettingsTileChannel = "com.apps.ispend/quick_settings_tile"
  private var quickSettingsChannel: MethodChannel? = null

  companion object {
    const val quickEntryTileExtra = "com.apps.ispend.v1.QUICK_ENTRY_TILE"
  }

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
    quickSettingsChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      quickSettingsTileChannel,
    ).also { channel ->
      channel.setMethodCallHandler { call, result ->
        when (call.method) {
          "consumeInitialQuickEntryTileTap" -> {
            result.success(consumeQuickEntryTileTap())
          }
          "requestAddQuickSettingsTile" -> requestAddQuickSettingsTile(result)
          else -> result.notImplemented()
        }
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    setIntent(intent)
    super.onNewIntent(intent)
    if (intent.getBooleanExtra(quickEntryTileExtra, false)) {
      intent.removeExtra(quickEntryTileExtra)
      quickSettingsChannel?.invokeMethod("quickEntryTileTapped", null)
    }
  }

  private fun consumeQuickEntryTileTap(): Boolean {
    if (!intent.getBooleanExtra(quickEntryTileExtra, false)) return false
    intent.removeExtra(quickEntryTileExtra)
    return true
  }

  private fun requestAddQuickSettingsTile(result: MethodChannel.Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
      result.success("manual_setup")
      return
    }
    val manager = getSystemService(StatusBarManager::class.java)
    manager.requestAddTileService(
      ComponentName(this, QuickEntryTileService::class.java),
      getString(R.string.quick_settings_tile_label),
      Icon.createWithResource(this, R.drawable.ic_quick_settings_add),
      mainExecutor,
    ) { status ->
      result.success(
        when (status) {
          StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
          StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "already_added"
          else -> "not_added"
        },
      )
    }
  }
}
