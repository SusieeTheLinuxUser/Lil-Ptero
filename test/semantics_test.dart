import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/console_socket.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/models.dart';
import 'package:pterodactyl_mobile/screens/console_tab.dart';
import 'package:pterodactyl_mobile/screens/server_list_screen.dart';
import 'package:pterodactyl_mobile/screens/settings_screen.dart';
import 'package:pterodactyl_mobile/widgets/resource_gauge.dart';

/// A console socket with no I/O behind it: connect() succeeds immediately and
/// the test can't drive events, which is fine here — the widgets under test
/// (send button, command field) render in every connection state.
class _StubSocket extends ConsoleSocket {
  _StubSocket(super.apiClient, super.serverIdentifier);

  @override
  Future<void> connect() async {}
}

const _credentials = Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only');

PterodactylApiClient _stubApi() =>
    PterodactylApiClient(_credentials, client: MockClient((_) async => http.Response('', 500)));

Widget _consoleTab() => DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: Builder(builder: (context) {
        return Scaffold(
          body: ConsoleTab(
            credentials: _credentials,
            apiClient: _stubApi(),
            server: const PteroServer(identifier: 'abc', name: 'Test'),
            tabController: DefaultTabController.of(context),
            socketFactory: (_, _) => _StubSocket(_stubApi(), 'abc'),
          ),
        );
      }),
    );

void main() {
  testWidgets('the console send button announces what it does', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: _consoleTab()));
    await tester.pump(); // the stub connect() completes: connected console

    expect(tester.getSemantics(find.byIcon(Icons.send)).tooltip, 'Send command');
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the command field has a label, not only a hint', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: _consoleTab()));
    await tester.pump();

    // The label lands on the field's own node, joined with the hint text:
    // "Console command\nEnter command".
    expect(find.bySemanticsLabel(RegExp(r'^Console command')), findsOneWidget);
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a resource gauge reads as name and value', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ResourceGauge(label: 'CPU', value: 0.42, valueLabel: '42.0%')),
    ));

    expect(find.bySemanticsLabel('CPU 42.0%'), findsOneWidget);
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the server list settings button announces what it does', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: ServerListScreen(credentials: _credentials, apiClient: _stubApi()),
    ));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(); // the failed list call shows its error

    expect(tester.getSemantics(find.byIcon(Icons.settings)).tooltip, 'Settings');
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Passed unchanged on the first run: the accent swatches merge their text
  // label into the tap node, so this only pins the behaviour.
  testWidgets('every tappable node in settings has a label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(credentials: _credentials),
    ));

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
