import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/notification_prefs.dart';
import 'package:pterodactyl_mobile/screens/settings_screen.dart';
import 'package:pterodactyl_mobile/theme_prefs.dart';
import 'package:pterodactyl_mobile/update_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const notifications = MethodChannel('dexterous.com/flutter/local_notifications');
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const service = MethodChannel('id.flutter/background_service/android/method', JSONMethodCodec());
  const serviceEvents = EventChannel('id.flutter/background_service/android/event', JSONMethodCodec());
  const battery = MethodChannel('dev.susiee.lilptero/battery_optimization');

  final credentials = Credentials(panelUrl: 'https://panel.example.com', apiKey: 'ptlc_TESTKEY0000');

  late Map<String, String> store; // the "secure storage" contents
  late List<String> serviceCalls; // every background-service plugin call
  var serviceRunning = false; // what the service channel reports
  var notificationsGranted = true; // the answer to requestNotificationsPermission

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    FlutterBackgroundServiceAndroid.registerWith();
    store = {};
    serviceCalls = [];
    serviceRunning = false;
    notificationsGranted = true;
    ThemePrefs.accent.value = AccentPreset.green;
    NotificationPrefs.enabled.value = false;
    UpdatePrefs.enabled.value = true;
    messenger.setMockMethodCallHandler(storage, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      final key = args?['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : store[key];
        case 'write':
          final value = args?['value'] as String?;
          if (key != null && value != null) store[key] = value;
          return null;
        case 'delete':
          store.remove(key);
          return null;
        case 'deleteAll':
          store.clear();
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(service, (call) async {
      serviceCalls.add(call.method);
      switch (call.method) {
        case 'isServiceRunning':
          return serviceRunning;
        case 'start':
          serviceRunning = true;
          return true;
        case 'sendData':
          // service.invoke('stopService') travels as sendData with a payload.
          final args = (call.arguments as Map?)?.cast<String, dynamic>();
          if (args?['method'] == 'stopService') serviceRunning = false;
          return true;
        default:
          return true;
      }
    });
    messenger.setMockStreamHandler(serviceEvents, MockStreamHandler.inline(onListen: (_, _) {}));
    messenger.setMockMethodCallHandler(notifications, (call) async =>
        call.method == 'requestNotificationsPermission' ? notificationsGranted : true);
    messenger.setMockMethodCallHandler(battery, (call) async => true);
    addTearDown(() {
      for (final channel in [notifications, storage, service, battery]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
      messenger.setMockStreamHandler(serviceEvents, null);
      ThemePrefs.accent.value = AccentPreset.green;
      NotificationPrefs.enabled.value = false;
      UpdatePrefs.enabled.value = true;
    });
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(credentials: credentials)));
    await tester.pump();
  }

  testWidgets('shows the panel URL and only a masked key, never the whole key', (tester) async {
    await pumpSettings(tester);
    expect(find.text('https://panel.example.com'), findsOneWidget);
    expect(find.text('ptlc••••••••0000'), findsOneWidget);
    expect(find.text('ptlc_TESTKEY0000'), findsNothing);
  });

  testWidgets('the accent color saves and survives a restart', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Purple'));
    await tester.pump();

    expect(store['accent_preset'], 'purple');
    expect(ThemePrefs.accent.value, AccentPreset.purple);

    // Simulate an app restart: reload the prefs, then build a fresh screen.
    await ThemePrefs.load();
    await pumpSettings(tester);
    expect(ThemePrefs.accent.value, AccentPreset.purple);
    final purpleColumn = find.ancestor(of: find.text('Purple'), matching: find.byType(Column)).first;
    expect(find.descendant(of: purpleColumn, matching: find.byIcon(Icons.check)), findsOneWidget);
  });

  testWidgets('the update check switch saves and survives a restart', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Check for updates'));
    await tester.pump();

    expect(store['update_check_enabled'], 'false');
    expect(UpdatePrefs.enabled.value, isFalse);

    await UpdatePrefs.load(); // simulate an app restart
    await pumpSettings(tester);
    expect(UpdatePrefs.enabled.value, isFalse);
    final tile = find.ancestor(of: find.text('Check for updates'), matching: find.byType(SwitchListTile));
    final swtich = tester.widget<SwitchListTile>(tile);
    expect(swtich.value, isFalse);
  });

  testWidgets('turning the watcher on saves it, starts the service and shows the battery row',
      (tester) async {
    await pumpSettings(tester);
    expect(find.text('Disable battery optimization'), findsNothing);

    await tester.tap(find.text('Server status notifications'));
    await tester.pumpAndSettle();

    expect(store['notifications_enabled'], 'true');
    expect(NotificationPrefs.enabled.value, isTrue);
    expect(serviceCalls, containsAllInOrder(['configure', 'start']));
    expect(find.text('Disable battery optimization'), findsOneWidget);
  });

  testWidgets('turning the watcher off stops the service and hides the battery row', (tester) async {
    NotificationPrefs.enabled.value = true; // start from a watcher that runs
    serviceRunning = true;
    await pumpSettings(tester);

    await tester.tap(find.text('Server status notifications'));
    await tester.pumpAndSettle();

    expect(store['notifications_enabled'], 'false');
    expect(serviceCalls, contains('sendData'), reason: 'stop is invoked through sendData');
    expect(serviceRunning, isFalse);
    expect(find.text('Disable battery optimization'), findsNothing);
  });

  testWidgets('a denied notification permission keeps the watcher off with a hint', (tester) async {
    notificationsGranted = false;
    await pumpSettings(tester);

    await tester.tap(find.text('Server status notifications'));
    await tester.pumpAndSettle();

    expect(NotificationPrefs.enabled.value, isFalse);
    expect(store['notifications_enabled'], isNull);
    expect(find.text('Allow notifications for Pterodactyl Mobile in Android settings first.'),
        findsOneWidget);
    expect(find.text('Disable battery optimization'), findsNothing);
  });

  testWidgets('disconnect clears the login and lands back on setup', (tester) async {
    NotificationPrefs.enabled.value = true;
    store['panel_url'] = 'https://panel.example.com';
    store['api_key'] = 'ptlc_TESTKEY0000';
    await pumpSettings(tester);

    await tester.dragUntilVisible(find.text('Disconnect'), find.byType(ListView).first,
        const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect(store['panel_url'], isNull);
    expect(store['api_key'], isNull);
    expect(store['notifications_enabled'], 'false');
    expect(find.text('Connect to Pterodactyl'), findsOneWidget); // the setup app bar
  });
}
