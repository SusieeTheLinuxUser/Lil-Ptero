import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/models.dart';
import 'package:pterodactyl_mobile/screens/server_detail_screen.dart';

void main() {
  const credentials = Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only');

  String resourcesBody({String state = 'running'}) => jsonEncode({
        'attributes': {
          'current_state': state,
          'resources': {
            'memory_bytes': 536870912,
            'cpu_absolute': 42.0,
            'disk_bytes': 2147483648,
            'network_rx_bytes': 0,
            'network_tx_bytes': 0,
            'uptime': 61000,
          },
        },
      });

  Future<void> pumpDetail(
    WidgetTester tester, {
    required PteroServer server,
    required Future<http.Response> Function(http.Request request) onRequest,
  }) async {
    final api = PterodactylApiClient(credentials, client: MockClient(onRequest));
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
      home: ServerDetailScreen(credentials: credentials, server: server, apiClient: api),
    ));
    await tester.pump();
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('shows the server name, both tabs and the live overview gauges', (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    await pumpDetail(tester, server: server, onRequest: (_) async => http.Response(resourcesBody(), 200));
    await tester.pumpAndSettle();

    expect(find.text('Survival'), findsOneWidget); // the app bar
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Console'), findsOneWidget);
    expect(find.text('42.0%'), findsOneWidget);
    expect(find.text('512.0 MB'), findsOneWidget);
  });

  testWidgets('an offline server shows the OFFLINE chip through the detail screen', (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    await pumpDetail(
      tester,
      server: server,
      onRequest: (_) async => http.Response(resourcesBody(state: 'offline'), 200),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFLINE'), findsOneWidget);
  });

  testWidgets('a server the panel refuses (e.g. suspended) shows the error instead of hanging',
      (tester) async {
    const server = PteroServer(identifier: 'abc', name: 'Survival');
    await pumpDetail(tester, server: server, onRequest: (_) async => http.Response('', 403));
    await tester.pumpAndSettle();

    expect(find.text('You do not have permission for this action'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
