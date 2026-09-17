import 'package:flutter/material.dart';

import 'credentials.dart';
import 'screens/server_list_screen.dart';
import 'screens/setup_screen.dart';
import 'theme_prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemePrefs.load();
  runApp(const PterodactylMobileApp());
}

class PterodactylMobileApp extends StatelessWidget {
  const PterodactylMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AccentPreset>(
      valueListenable: ThemePrefs.accent,
      builder: (context, accent, _) {
        return MaterialApp(
          title: 'Pterodactyl Mobile',
          theme: ThemeData(
            colorSchemeSeed: accent.seed,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const _StartupGate(),
        );
      },
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
