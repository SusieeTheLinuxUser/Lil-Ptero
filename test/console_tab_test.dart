import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/console_socket.dart';
import 'package:pterodactyl_mobile/models.dart';
import 'package:pterodactyl_mobile/screens/console_tab.dart';

/// A console socket with no I/O behind it: the test drives its [events]
/// directly, so widget tests never touch a real socket.
class _StubSocket extends ConsoleSocket {
  _StubSocket(super.apiClient, super.serverIdentifier);

  final _events = StreamController<ConsoleEvent>.broadcast();

  void emit(ConsoleEvent event) => _events.add(event);

  @override
  Stream<ConsoleEvent> get events => _events.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    await _events.close();
  }

  @override
  void sendCommand(String command) {}
}

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

  testWidgets('the reconnect banner counts down once per second', (tester) async {
    final api = PterodactylApiClient(
      const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
      client: MockClient((_) async => http.Response('', 500)), // never called by the stub
    );
    final socket = _StubSocket(api, 'abc');
    await tester.pumpWidget(MaterialApp(
      home: DefaultTabController(
        length: 2,
        initialIndex: 1,
        child: Builder(builder: (context) {
          return Scaffold(
            body: ConsoleTab(
              credentials: const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
              apiClient: api,
              server: const PteroServer(identifier: 'abc', name: 'Test'),
              tabController: DefaultTabController.of(context),
              socketFactory: (_, _) => socket,
            ),
          );
        }),
      ),
    ));
    await tester.pump(); // the stub connect() completes: connecting, spinner shown
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    socket.emit(const AuthSuccess());
    await tester.pump(); // delivers the event, schedules the frame
    await tester.pump(); // renders the connected console
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // The panel drops the connection: the banner appears and ticks down.
    socket.emit(const SocketClosed());
    socket.emit(const Reconnecting(Duration(seconds: 4)));
    await tester.pump(); // delivers the events, schedules the frame
    await tester.pump(); // renders the banner
    expect(find.textContaining('Reconnecting in 4s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Reconnecting in 3s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Reconnecting in 2s'), findsOneWidget);

    // The retry lands: the banner goes away and no stale tick brings it back.
    socket.emit(const AuthSuccess());
    await tester.pump(); // delivers the event, schedules the frame
    await tester.pump(); // renders without the banner
    expect(find.byType(MaterialBanner), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(MaterialBanner), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no disconnected banner before the first connect attempt', (tester) async {
    // A swipe builds the Console page while the tab index is still 0.
    await tester.pumpWidget(MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Builder(builder: (context) {
          return Scaffold(
            body: ConsoleTab(
              credentials: const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
              apiClient: PterodactylApiClient(
                const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
                client: MockClient((_) async => http.Response('', 500)),
              ),
              server: const PteroServer(identifier: 'abc', name: 'Test'),
              tabController: DefaultTabController.of(context),
            ),
          );
        }),
      ),
    ));
    expect(find.text('Console disconnected'), findsNothing);
    expect(find.text('Reconnect'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
