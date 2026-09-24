package com.apps.ispend.v1

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** A Quick Settings launcher for the shared Flutter Quick Entry flow. */
class QuickEntryTileService : TileService() {
  override fun onStartListening() {
    qsTile?.apply {
      state = Tile.STATE_ACTIVE
      label = getString(R.string.quick_settings_tile_label)
      updateTile()
    }
  }

  override fun onClick() {
    val intent = Intent(this, MainActivity::class.java).apply {
      putExtra(MainActivity.quickEntryTileExtra, true)
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      val pendingIntent = PendingIntent.getActivity(
        this,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      startActivityAndCollapse(pendingIntent)
    } else {
      @Suppress("DEPRECATION")
      startActivityAndCollapse(intent)
    }
  }
}
