import 'dart:io';

import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';

/// Picker plugins may copy selected images into the app cache. Only remove
/// those app-owned copies; a path outside the cache may be the user's original.
Future<void> discardTemporaryOcrImage(String? path) async {
  if (path == null) return;
  try {
    final cache = await getTemporaryDirectory();
    final image = File(path);
    if (!paths.isWithin(cache.absolute.path, image.absolute.path)) return;
    if (await image.exists()) await image.delete();
  } catch (_) {
    // Cache cleanup must not affect a saved expense or an original photo.
  }
}
