package com.apps.ispend.v1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class QuickEntryWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: android.content.SharedPreferences) {
    ids.forEach { id ->
      val views = RemoteViews(context.packageName, R.layout.ispend_quick_entry_widget)
      val pending = HomeWidgetLaunchIntent.getActivity(
        context, MainActivity::class.java, Uri.parse("ispend://quick-entry")
      )
      views.setOnClickPendingIntent(R.id.widget_add, pending)
      val buttons = listOf(R.id.widget_favorite_1, R.id.widget_favorite_2, R.id.widget_favorite_3)
      var hasFavorites = false
      buttons.forEachIndexed { index, buttonId ->
        val name = data.getString("quick_entry_favorite_${index + 1}", "") ?: ""
        views.setViewVisibility(buttonId, if (name.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
        if (name.isNotEmpty()) {
          hasFavorites = true
          views.setTextViewText(buttonId, name)
          val templateId = data.getString("quick_entry_favorite_id_${index + 1}", "") ?: ""
          val templatePending = HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java,
            Uri.parse("ispend://quick-entry?template_id=$templateId&template_name=${Uri.encode(name)}")
          )
          views.setOnClickPendingIntent(buttonId, templatePending)
        }
      }
      views.setViewVisibility(R.id.widget_empty, if (hasFavorites) android.view.View.GONE else android.view.View.VISIBLE)
      manager.updateAppWidget(id, views)
    }
  }
}
