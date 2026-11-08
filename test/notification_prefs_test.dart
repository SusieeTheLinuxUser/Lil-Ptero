import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/notification_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const notifications = MethodChannel('dexterous.com/flutter/local_notifications');
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  test('turning the monitor on with notifications denied stays off and saves nothing', () async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final asked = <String>[];
    messenger.setMockMethodCallHandler(notifications, (call) async {
      asked.add(call.method);
      return call.method == 'initialize'; // permission request answers false
    });
    final writes = <String>[];
    messenger.setMockMethodCallHandler(storage, (call) async {
      writes.add(call.method);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(storage, null);
    });

    expect(await NotificationPrefs.setEnabled(true), isFalse);
    expect(asked, contains('requestNotificationsPermission'));
    expect(NotificationPrefs.enabled.value, isFalse);
    expect(writes, isEmpty);
  });
}
