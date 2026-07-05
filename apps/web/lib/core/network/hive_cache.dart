import 'package:hive_flutter/hive_flutter.dart';

/// Local offline storage caching manager for WealthAI API responses.
class HiveCacheManager {
  static const String boxName = 'wealthai_offline_cache';

  /// Initialize and open the default caching box.
  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  /// Get cached response dynamic payload by key.
  static dynamic get(String key) {
    try {
      final box = Hive.box(boxName);
      return box.get(key);
    } catch (_) {
      return null;
    }
  }

  /// Write response payload to cache box.
  static Future<void> set(String key, dynamic value) async {
    try {
      final box = Hive.box(boxName);
      await box.put(key, value);
    } catch (_) {}
  }

  /// Flush all offline caches.
  static Future<void> clearAll() async {
    try {
      final box = Hive.box(boxName);
      await box.clear();
    } catch (_) {}
  }
}
