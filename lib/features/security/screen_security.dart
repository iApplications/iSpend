import 'package:flutter/services.dart';

/// Hides iSpend from screenshots and the Android Recents thumbnail while app
/// lock is on. It does nothing on platforms without the native handler.
class ScreenSecurity {
  const ScreenSecurity._();

  static const _channel = MethodChannel('com.apps.ispend/screen_security');

  static Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // Not running on Android (or in a widget test).
    } on PlatformException {
      // Failing to change the window flag must never block the app.
    }
  }
}
