import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'update_check.dart';

/// Lets the update banner be shown from `main` without a BuildContext.
final updateScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// "Check for updates" toggle (Settings) plus the actual check, run from
/// `main` at most once per 24h. Persisted via flutter_secure_storage like
/// the other prefs. Silent on any failure.
class UpdatePrefs {
  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'update_check_enabled';
  static const _lastCheckKey = 'update_check_last_ms';
  static const _checkInterval = Duration(hours: 24);

  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static Future<void> load() async {
    final saved = await _storage.read(key: _enabledKey);
    enabled.value = saved != 'false'; // on by default
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await _storage.write(key: _enabledKey, value: value.toString());
  }

  /// Checks for a newer version at most once per 24h and, if one is out,
  /// shows a dismissible SnackBar. Never throws: any failure is silent.
  static Future<void> maybeCheckAndNotify() async {
    if (!enabled.value) return;
    final last = int.tryParse(await _storage.read(key: _lastCheckKey) ?? '');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < _checkInterval.inMilliseconds) return;
    await _storage.write(key: _lastCheckKey, value: now.toString());
    final version = await fetchNewerVersionName();
    if (version == null) return;
    final messenger = updateScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lil-Ptero $version is out'),
            // This app deliberately has no URL-opening package, so show
            // the release page as selectable text. F-Droid builds skip
            // it: their updates come through the F-Droid client.
            if (!fdroidBuild)
              const SelectableText(githubLatestUrl, style: TextStyle(fontSize: 12)),
          ],
        ),
        action: SnackBarAction(label: 'Dismiss', onPressed: messenger.hideCurrentSnackBar),
        duration: const Duration(seconds: 10),
      ),
    );
  }
}