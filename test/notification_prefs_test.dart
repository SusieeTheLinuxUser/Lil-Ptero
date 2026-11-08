import 'package:flutter/services.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/notification_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const notifications = MethodChannel('dexterous.com/flutter/local_notifications');
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const service = MethodChannel('id.flutter/background_service/android/method', JSONMethodCodec());
  const serviceEvents = EventChannel('id.flutter/background_service/android/event', JSONMethodCodec());

  late List<String> calls; // every plugin call, prefixed by channel
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    FlutterBackgroundServiceAndroid.registerWith();
    calls = [];
    messenger.setMockMethodCallHandler(storage, (call) async {
      calls.add('storage.${call.method}');
      return null;
    });
    messenger.setMockMethodCallHandler(service, (call) async {
      calls.add('service.${call.method}');
      return call.method == 'isServiceRunning' ? false : true;
    });
    messenger.setMockStreamHandler(serviceEvents, MockStreamHandler.inline(onListen: (_, __) {}));
    addTearDown(() {
      for (final channel in [notifications, storage, service]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
      messenger.setMockStreamHandler(serviceEvents, null);
      NotificationPrefs.enabled.value = false;
    });
  });

  void permission({required bool granted}) {
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add('notifications.${call.method}');
      return call.method == 'requestNotificationsPermission' ? granted : true;
    });
  }

  test('turning the monitor on with notifications denied stays off and saves nothing', () async {
    permission(granted: false);
    expect(await NotificationPrefs.setEnabled(true), isFalse);
    expect(calls, contains('notifications.requestNotificationsPermission'));
    expect(NotificationPrefs.enabled.value, isFalse);
    expect(calls.where((c) => !c.startsWith('notifications.')), isEmpty);
  });

  test('turning the monitor on with notifications granted saves it and starts the service', () async {
    permission(granted: true);
    expect(await NotificationPrefs.setEnabled(true), isTrue);
    expect(NotificationPrefs.enabled.value, isTrue);
    expect(calls, containsAllInOrder(['storage.write', 'service.configure', 'service.start']));
  });
}
