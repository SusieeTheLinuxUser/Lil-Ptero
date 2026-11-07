import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final calls = <String>[];

  Future<Object?> handler(MethodCall call) async {
    calls.add(call.method);
    if (call.method == 'read') {
      throw PlatformException(code: 'Exception encountered', message: 'read');
    }
    return null;
  }

  Future<Object?> nullHandler(MethodCall call) async {
    calls.add(call.method);
    return null;
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    calls.clear();
  });

  testWidgets('unreadable storage shows setup screen with notice and wipes storage', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
    await tester.pumpWidget(const PterodactylMobileApp());
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't be read"), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(calls.where((m) => m == 'read').length, greaterThanOrEqualTo(2)); // retried before wiping
    expect(calls, contains('deleteAll'));
  });

  testWidgets('normal empty storage shows setup screen without notice', (WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, nullHandler);
    await tester.pumpWidget(const PterodactylMobileApp());
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't be read"), findsNothing);
    expect(calls, isNot(contains('deleteAll')));
  });

  test('Credentials.reset() forwards deleteAll to the plugin', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, nullHandler);
    await Credentials.reset();
    expect(calls, contains('deleteAll'));
  });
}