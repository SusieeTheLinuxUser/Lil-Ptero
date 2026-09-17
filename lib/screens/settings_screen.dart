import 'package:flutter/material.dart';

import '../credentials.dart';
import '../theme_prefs.dart';
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Accent color', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ValueListenableBuilder<AccentPreset>(
              valueListenable: ThemePrefs.accent,
              builder: (context, selected, _) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final preset in AccentPreset.values)
                      _AccentSwatch(
                        preset: preset,
                        selected: preset == selected,
                        onTap: () => ThemePrefs.setAccent(preset),
                      ),
                  ],
                );
              },
            ),
          ),
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

class _AccentSwatch extends StatelessWidget {
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _AccentSwatch({required this.preset, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: preset.seed,
            child: selected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
          const SizedBox(height: 4),
          Text(preset.label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
