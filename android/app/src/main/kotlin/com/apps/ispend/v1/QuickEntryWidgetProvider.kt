package com.apps.ispend.v1

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class QuickEntryWidgetProvider : HomeWidgetProvider() {
  override fun onAppWidgetOptionsChanged(
    context: Context,
    manager: AppWidgetManager,
    id: Int,
    options: android.os.Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, manager, id, options)
    onUpdate(context, manager, intArrayOf(id), HomeWidgetPlugin.getData(context))
  }

  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: android.content.SharedPreferences) {
    ids.forEach { id ->
      val minHeight = manager.getAppWidgetOptions(id).getInt(
        AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,
        0,
      )
      val compact = minHeight < 280
      val views = RemoteViews(
        context.packageName,
        if (compact) R.layout.ispend_quick_entry_widget_compact else R.layout.ispend_quick_entry_widget,
      )
      val maxVisibleFavorites = when {
        compact -> 2
        minHeight >= 390 -> 3
        else -> 2
      }
      val pending = HomeWidgetLaunchIntent.getActivity(
        context, MainActivity::class.java, Uri.parse("ispend://quick-entry")
      )
      views.setOnClickPendingIntent(R.id.widget_add, pending)
      views.setTextViewText(R.id.widget_today_total, data.getString("widget_today_total", "RM 0.00"))
      val favorites = listOf(R.id.widget_favorite_1, R.id.widget_favorite_2, R.id.widget_favorite_3)
      var favoriteCount = 0
      favorites.forEachIndexed { index, _ ->
        if ((data.getString("quick_entry_favorite_${index + 1}", "") ?: "").isNotEmpty()) favoriteCount++
      }
      favorites.forEachIndexed { index, viewId ->
        val name = data.getString("quick_entry_favorite_${index + 1}", "") ?: ""
        val visible = name.isNotEmpty() && index < maxVisibleFavorites
        views.setViewVisibility(viewId, if (visible) android.view.View.VISIBLE else android.view.View.GONE)
        if (name.isNotEmpty()) {
          views.setTextViewText(viewId, name)
          val templateId = data.getString("quick_entry_favorite_id_${index + 1}", "") ?: ""
          val templatePending = HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java,
            Uri.parse("ispend://quick-entry?template_id=$templateId&template_name=${Uri.encode(name)}")
          )
          views.setOnClickPendingIntent(viewId, templatePending)
        }
      }
      val more = favoriteCount > maxVisibleFavorites || data.getBoolean("quick_entry_has_more_favorites", false)
      views.setViewVisibility(R.id.widget_more, if (more) android.view.View.VISIBLE else android.view.View.GONE)
      views.setOnClickPendingIntent(R.id.widget_more, HomeWidgetLaunchIntent.getActivity(
        context, MainActivity::class.java, Uri.parse("ispend://quick-entry?more=true")
      ))
      manager.updateAppWidget(id, views)
    }
  }
}
