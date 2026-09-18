import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'background_monitor.dart';

/// Whether the background server-status monitor (and its persistent
/// "Watching your servers" notification) is turned on. Off by default —
/// this is an opt-in, since it runs a foreground service. Persisted the
/// same way as [ThemePrefs.accent].
class NotificationPrefs {
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'notifications_enabled';

  static final ValueNotifier<bool> enabled = ValueNotifier(false);

  static Future<void> load() async {
    final saved = await _storage.read(key: _enabledKey);
    enabled.value = saved == 'true';

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await BackgroundMonitor.configure();
    if (enabled.value) await BackgroundMonitor.start();
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await _storage.write(key: _enabledKey, value: value.toString());
    if (value) {
      await BackgroundMonitor.start();
    } else {
      await BackgroundMonitor.stop();
    }
  }
}
