import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Credentials {
  final String panelUrl;
  final String apiKey;

  const Credentials({required this.panelUrl, required this.apiKey});

  static const _storage = FlutterSecureStorage();
  static const _panelUrlKey = 'panel_url';
  static const _apiKeyKey = 'api_key';

  static Future<Credentials?> load() async {
    final url = await _storage.read(key: _panelUrlKey);
    final key = await _storage.read(key: _apiKeyKey);
    if (url == null || key == null) return null;
    return Credentials(panelUrl: url, apiKey: key);
  }

  static Future<void> save(Credentials credentials) async {
    await _storage.write(key: _panelUrlKey, value: credentials.panelUrl);
    await _storage.write(key: _apiKeyKey, value: credentials.apiKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _panelUrlKey);
    await _storage.delete(key: _apiKeyKey);
  }
}
