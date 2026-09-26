import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/models.dart';
import 'package:pterodactyl_mobile/screens/console_tab.dart';

void main() {
  testWidgets('rapid reconnect taps do not dispose the new connection', (tester) async {
    final response = Completer<http.Response>();
    var requests = 0;
    final client = MockClient((_) async {
      if (++requests == 1) return http.Response('', 401);
      return response.future;
    });
    await tester.pumpWidget(MaterialApp(
      home: DefaultTabController(
        length: 2,
        initialIndex: 1,
        child: Builder(builder: (context) {
          return Scaffold(
            body: ConsoleTab(
              credentials: const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
              apiClient: PterodactylApiClient(
                const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
                client: client,
              ),
              server: const PteroServer(identifier: 'abc', name: 'Test'),
              tabController: DefaultTabController.of(context),
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(requests, 1);
    expect(find.text('Could not connect to console'), findsOneWidget);

    // Both taps arrive before the next frame removes the reconnect button.
    await tester.tap(find.text('Reconnect'));
    await tester.tap(find.text('Reconnect'));
    await tester.pump();
    expect(requests, 2);
    // A live attempt reports this invalid URL; a disposed attempt silently
    // returns after the lookup, leaving the UI stuck on its spinner.
    response.complete(http.Response('{"data":{"token":"test-token","socket":"invalid"}}', 200));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('Could not connect to console'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
