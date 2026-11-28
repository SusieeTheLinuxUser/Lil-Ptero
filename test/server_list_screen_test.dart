import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/screens/server_list_screen.dart';

void main() {
  const credentials = Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only');

  String oneServer(String name) => jsonEncode({
        'data': [
          {'attributes': {'identifier': 'abc', 'name': name}},
        ],
      });

  Future<void> pumpList(WidgetTester tester, PterodactylApiClient api) async {
    await tester.pumpWidget(
      MaterialApp(home: ServerListScreen(credentials: credentials, apiClient: api)),
    );
  }

  testWidgets('a spinner while the panel has not answered yet, then the servers', (tester) async {
    final firstPage = Completer<http.Response>();
    var requests = 0;
    final api = PterodactylApiClient(
      credentials,
      client: MockClient((_) async {
        requests++;
        if (requests == 1) return firstPage.future;
        return http.Response(oneServer('Survival'), 200);
      }),
    );
    addTearDown(api.close);
    await pumpList(tester, api);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No servers found'), findsNothing);

    firstPage.complete(http.Response(oneServer('Survival'), 200));
    await tester.pumpAndSettle();
    expect(find.text('Survival'), findsOneWidget);
  });

  testWidgets('an empty panel shows the no-servers message', (tester) async {
    final api = PterodactylApiClient(
      credentials,
      client: MockClient((_) async => http.Response('{"data":[]}', 200)),
    );
    addTearDown(api.close);
    await pumpList(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('No servers found'), findsOneWidget);
  });

  testWidgets('a failed load shows the panel error and a retry that works', (tester) async {
    var healthy = false;
    final api = PterodactylApiClient(
      credentials,
      client: MockClient((_) async {
        if (healthy) return http.Response(oneServer('Survival'), 200);
        return http.Response('bad gateway', 502);
      }),
    );
    addTearDown(api.close);
    await pumpList(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('Request failed (502)'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    healthy = true; // the mock answers synchronously inside the tap
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Survival'), findsOneWidget);
    expect(find.text('Request failed (502)'), findsNothing);
  });

  testWidgets('pull to refresh reloads the list', (tester) async {
    var requests = 0;
    final api = PterodactylApiClient(
      credentials,
      client: MockClient((_) async {
        requests++;
        return http.Response(oneServer(requests == 1 ? 'Survival' : 'Renamed'), 200);
      }),
    );
    addTearDown(api.close);
    await pumpList(tester, api);
    await tester.pumpAndSettle();
    expect(find.text('Survival'), findsOneWidget);

    await tester.drag(find.text('Survival'), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(requests, 2, reason: 'the pull must have triggered a reload');
    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets('pull to refresh also works on the error state', (tester) async {
    var healthy = false;
    final api = PterodactylApiClient(
      credentials,
      client: MockClient((_) async {
        if (healthy) return http.Response(oneServer('Survival'), 200);
        return http.Response('bad gateway', 502);
      }),
    );
    addTearDown(api.close);
    await pumpList(tester, api);
    await tester.pumpAndSettle();
    expect(find.text('Request failed (502)'), findsOneWidget);

    healthy = true; // the mock answers synchronously inside the drag
    await tester.drag(find.text('Request failed (502)'), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('Survival'), findsOneWidget);
    expect(find.text('Request failed (502)'), findsNothing);
  });
}
