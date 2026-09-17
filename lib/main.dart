import 'package:flutter/material.dart';

import 'credentials.dart';
import 'screens/server_list_screen.dart';
import 'screens/setup_screen.dart';

void main() {
  runApp(const PterodactylMobileApp());
}

class PterodactylMobileApp extends StatelessWidget {
  const PterodactylMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pterodactyl Mobile',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late final Future<Credentials?> _future;

  @override
  void initState() {
    super.initState();
    _future = Credentials.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Credentials?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final credentials = snapshot.data;
        return credentials == null ? const SetupScreen() : ServerListScreen(credentials: credentials);
      },
    );
  }
}
