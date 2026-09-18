import 'dart:async';
import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'credentials.dart';
import 'models.dart';

/// True when [current] is a fresh transition into offline — i.e. we had a
/// previously-seen state for this server and it wasn't already offline.
/// `previous == null` means this is the first poll after (re)start, so
/// there's nothing to compare against yet.
bool shouldNotifyOffline(String? previous, ServerState current) {
  return previous != null && previous != current.name && current == ServerState.offline;
}

/// Polls every server's status on a timer from an Android foreground
/// service, so a stop/crash is caught even while the app isn't open —
/// same idea as a fitness tracker keeping a live connection to a watch.
/// ponytail: fixed 30s poll via REST rather than N persistent websockets;
/// revisit if per-server push-style status ever becomes available.
class BackgroundMonitor {
  static const _pollInterval = Duration(seconds: 30);
  static const _storage = FlutterSecureStorage();
  static const _lastStatesKey = 'background_monitor_last_states';
  static const _channel = AndroidNotificationDetails(
    'server_status',
    'Server status',
    channelDescription: 'Server stop/crash alerts',
    importance: Importance.high,
  );

  static Future<void> configure() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
        autoStartOnBoot: false,
        notificationChannelId: 'background_monitor',
        initialNotificationTitle: 'Pterodactyl Mobile',
        initialNotificationContent: 'Watching your servers',
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) service.invoke('stopService');
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    final notifications = FlutterLocalNotificationsPlugin();
    notifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    service.on('stopService').listen((_) => service.stopSelf());

    Timer.periodic(_pollInterval, (timer) async {
      if (service is AndroidServiceInstance && !await service.isForegroundService()) return;
      await _pollOnce(notifications);
    });
  }

  static Future<void> _pollOnce(FlutterLocalNotificationsPlugin notifications) async {
    final credentials = await Credentials.load();
    if (credentials == null) return;

    final lastStatesRaw = await _storage.read(key: _lastStatesKey);
    final lastStates = lastStatesRaw == null
        ? <String, String>{}
        : (jsonDecode(lastStatesRaw) as Map).cast<String, String>();

    final api = PterodactylApiClient(credentials);
    try {
      final servers = await api.listServers();
      final currentStates = <String, String>{};
      for (final server in servers) {
        final ServerState state;
        try {
          state = (await api.getResources(server.identifier)).currentState;
        } catch (_) {
          continue;
        }
        currentStates[server.identifier] = state.name;

        if (shouldNotifyOffline(lastStates[server.identifier], state)) {
          await notifications.show(
            server.name.hashCode,
            server.name,
            'Server stopped',
            const NotificationDetails(android: _channel),
          );
        }
      }
      await _storage.write(key: _lastStatesKey, value: jsonEncode(currentStates));
    } catch (_) {
      // Transient network/API error — try again next tick.
    } finally {
      api.close();
    }
  }
}
