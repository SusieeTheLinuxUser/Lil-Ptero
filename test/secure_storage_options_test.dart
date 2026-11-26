import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  test('storage asks the plugin for backup-protected migration and no reset on error', () async {
    Map? options;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      options = (call.arguments as Map)['options'] as Map?;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await Credentials.load();
    expect(options?['resetOnError'], 'false');
    expect(options?['migrateWithBackup'], 'true');
  });
}
