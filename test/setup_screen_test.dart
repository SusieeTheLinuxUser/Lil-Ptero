import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/screens/setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> store; // the "secure storage" contents
  late List<String> requests; // every URL the mock client was asked for

  setUp(() {
    store = {};
    requests = [];
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
        case 'deleteAll':
          store.remove(key);
          return null;
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(storage, null));
  });

  PterodactylApiClient api(Future<http.Response> Function(http.Request request) handler) =>
      PterodactylApiClient(
        const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
        client: MockClient(handler),
      );

  PterodactylApiClient listingClient() => api((request) async {
        requests.add(request.url.toString());
        return http.Response(
          jsonEncode({
            'data': [
              {'attributes': {'identifier': 'abc', 'name': 'Survival'}},
            ],
          }),
          200,
        );
      });

  Future<void> pumpSetup(WidgetTester tester, {PterodactylApiClient? client}) async {
    await tester.pumpWidget(MaterialApp(home: SetupScreen(apiClient: client)));
    await tester.pump();
  }

  Future<void> fillForm(WidgetTester tester, {String? url, String? key}) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Panel URL'), url ?? '');
    await tester.enterText(find.widgetWithText(TextFormField, 'Client API Key'), key ?? '');
  }

  testWidgets('an empty panel URL shows the error and saves nothing', (tester) async {
    final client = listingClient();
    addTearDown(client.close);
    await pumpSetup(tester, client: client);
    await fillForm(tester, key: 'ptlc_TESTKEY0000');

    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(find.text('Enter your panel URL'), findsOneWidget);
    expect(store, isEmpty);
    expect(requests, isEmpty);
    expect(find.text('Connect'), findsOneWidget); // still on setup
  });

  testWidgets('a panel URL without a host shows the error and saves nothing', (tester) async {
    final client = listingClient();
    addTearDown(client.close);
    await pumpSetup(tester, client: client);
    await fillForm(tester, url: 'https://', key: 'ptlc_TESTKEY0000');

    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(find.text('Enter a valid panel address, e.g. panel.example.com'), findsOneWidget);
    expect(store, isEmpty);
    expect(requests, isEmpty);
  });

  testWidgets('an empty key shows the error and saves nothing', (tester) async {
    final client = listingClient();
    addTearDown(client.close);
    await pumpSetup(tester, client: client);
    await fillForm(tester, url: 'panel.example.com');

    await tester.tap(find.text('Connect'));
    await tester.pump();

    expect(find.text('Enter your API key'), findsOneWidget);
    expect(store, isEmpty);
    expect(requests, isEmpty);
  });

  testWidgets('a plain-http panel is refused before anything is sent', (tester) async {
    // No injected client: the production client's scheme check fires before
    // any request, so nothing can reach the network.
    await pumpSetup(tester);
    await fillForm(tester, url: 'http://panel.example.com', key: 'ptlc_TESTKEY0000');

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Panel URL must start with https://'), findsOneWidget);
    expect(store, isEmpty);
    expect(find.text('Connect'), findsOneWidget); // still on setup
  });

  testWidgets('a rejected key shows the panel error and saves nothing', (tester) async {
    var calls = 0;
    final client = PterodactylApiClient(
      const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
      client: MockClient((_) async {
        calls++;
        return http.Response('', 401);
      }),
    );
    addTearDown(client.close);
    await pumpSetup(tester, client: client);
    await fillForm(tester, url: 'panel.example.com', key: 'ptlc_TESTKEY0000');

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid API key'), findsOneWidget);
    expect(calls, 1);
    expect(store, isEmpty);
  });

  testWidgets('a valid setup saves the login and opens the server list', (tester) async {
    final client = listingClient();
    addTearDown(client.close);
    await pumpSetup(tester, client: client);
    await fillForm(tester, url: 'panel.example.com', key: 'ptlc_TESTKEY0000');

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(store['panel_url'], 'https://panel.example.com');
    expect(store['api_key'], 'ptlc_TESTKEY0000');
    expect(find.text('Servers'), findsOneWidget); // the server list app bar
    expect(find.text('Survival'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
  });
}
