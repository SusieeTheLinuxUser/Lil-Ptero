import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/models.dart';
import 'package:pterodactyl_mobile/screens/overview_tab.dart';

void main() {
  const credentials = Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only');

  String resourcesBody({String state = 'running'}) => jsonEncode({
        'attributes': {
          'current_state': state,
          'resources': {
            'memory_bytes': 536870912, // 512 MB
            'cpu_absolute': 42.0,
            'disk_bytes': 2147483648, // 2 GB
            'network_rx_bytes': 0,
            'network_tx_bytes': 0,
            'uptime': 61000,
          },
        },
      });

  /// Pumps the tab with a mock client. `onRequest` decides every response;
  /// ends the widget before the test finishes so the 4 s poll timer dies.
  Future<void> pumpOverview(
    WidgetTester tester, {
    required PteroServer server,
    required Future<http.Response> Function(http.Request request) onRequest,
  }) async {
    final api = PterodactylApiClient(credentials, client: MockClient(onRequest));
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OverviewTab(credentials: credentials, server: server, apiClient: api)),
    ));
    await tester.pump();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('unlimited (0) limits show plain usage and a calm bar', (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival'); // all limits 0
    await pumpOverview(tester, server: server, onRequest: (_) async => http.Response(resourcesBody(), 200));
    await tester.pumpAndSettle();

    expect(find.text('42.0%'), findsOneWidget, reason: 'no limit suffix when the limit is 0');
    expect(find.text('512.0 MB'), findsOneWidget);
    expect(find.text('2.0 GB'), findsOneWidget);
    expect(find.text('Uptime: 1m 1s'), findsOneWidget);

    final bars = tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).toList();
    expect(bars, hasLength(3));
    expect(bars[0].value, 0.42, reason: 'CPU falls back to a 100% baseline when unlimited');
    expect(bars[1].value, 0.0, reason: 'an unlimited memory limit shows no fraction');
    expect(bars[2].value, 0.0, reason: 'an unlimited disk limit shows no fraction');
  });

  testWidgets('an offline server shows the OFFLINE chip', (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    await pumpOverview(
      tester,
      server: server,
      onRequest: (_) async => http.Response(resourcesBody(state: 'offline'), 200),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a suspended server reads as UNKNOWN without crashing', (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    await pumpOverview(
      tester,
      server: server,
      onRequest: (_) async => http.Response(resourcesBody(state: 'suspended'), 200),
    );
    await tester.pumpAndSettle();

    expect(find.text('UNKNOWN'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget); // the controls still render
  });

  testWidgets('power buttons are disabled while a power action runs', (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    final powerGate = Completer<http.Response>();
    var powerRequests = 0;
    await pumpOverview(tester, server: server, onRequest: (request) async {
      if (request.method == 'POST') {
        powerRequests++;
        return powerGate.future;
      }
      return http.Response(resourcesBody(), 200);
    });
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump();

    expect(powerRequests, 1);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start')).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Restart')).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Stop')).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Kill')).onPressed, isNull);

    powerGate.complete(http.Response('', 204));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start')).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Restart')).onPressed, isNotNull);
  });

  testWidgets('stopping asks for confirmation and cancel sends nothing', (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    var powerRequests = 0;
    await pumpOverview(tester, server: server, onRequest: (request) async {
      if (request.method == 'POST') {
        powerRequests++;
        return http.Response('', 204);
      }
      return http.Response(resourcesBody(), 200);
    });
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Stop server?'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(powerRequests, 0);
    expect(find.text('Stop server?'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Stop')));
    await tester.pumpAndSettle();
    expect(powerRequests, 1);
  });

  testWidgets('a failed power action shows the panel error and re-enables the buttons',
      (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    await pumpOverview(tester, server: server, onRequest: (request) async {
      if (request.method == 'POST') return http.Response('busy', 409);
      return http.Response(resourcesBody(), 200);
    });
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();

    expect(find.text('Request failed (409)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start')).onPressed, isNotNull,
        reason: 'a failed action must not leave the buttons stuck');
  });
}
