import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AccentPreset {
  green(Colors.green, 'Green'),
  purple(Colors.deepPurple, 'Purple'),
  pink(Colors.pink, 'Pink'),
  blue(Colors.blue, 'Blue'),
  red(Colors.red, 'Red');

  final Color seed;
  final String label;
  const AccentPreset(this.seed, this.label);
}

/// App is always dark — no light mode. Only the accent color is user-selectable.
class ThemePrefs {
  static const _storage = FlutterSecureStorage();
  static const _accentKey = 'accent_preset';

  static final ValueNotifier<AccentPreset> accent = ValueNotifier(AccentPreset.green);

  static Future<void> load() async {
    final saved = await _storage.read(key: _accentKey);
    for (final preset in AccentPreset.values) {
      if (preset.name == saved) {
        accent.value = preset;
        return;
      }
    }
  }

  static Future<void> setAccent(AccentPreset preset) async {
    accent.value = preset;
    await _storage.write(key: _accentKey, value: preset.name);
  }
}
