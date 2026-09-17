import 'package:flutter/material.dart';

import '../credentials.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  final Credentials credentials;
  const SettingsScreen({super.key, required this.credentials});

  String get _maskedKey {
    final key = credentials.apiKey;
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
  }

  Future<void> _disconnect(BuildContext context) async {
    await Credentials.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(title: const Text('Panel URL'), subtitle: Text(credentials.panelUrl)),
          ListTile(title: const Text('API Key'), subtitle: Text(_maskedKey)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Disconnect'),
            onTap: () => _disconnect(context),
          ),
        ],
      ),
    );
  }
}
