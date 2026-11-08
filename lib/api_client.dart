import 'dart:convert';

import 'package:http/http.dart' as http;

import 'credentials.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class PterodactylApiClient {
  final Credentials credentials;
  final http.Client _client;

  PterodactylApiClient(this.credentials, {http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('${credentials.panelUrl}$path');

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${credentials.apiKey}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<T> _get<T>(String path, T Function(Map<String, dynamic>) parse) async {
    final json = await _send(() => _client.get(_uri(path), headers: _headers));
    try {
      return parse(json as Map<String, dynamic>);
    } on TypeError {
      throw ApiException('Invalid response from panel');
    }
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) => _send(
        () => _client.post(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)),
      );

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    // Flutter on Android doesn't block plain http, so never send the API key over it.
    if (Uri.tryParse(credentials.panelUrl)?.isScheme('https') != true) {
      throw ApiException('Panel URL must start with https://');
    }
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 15));
    } on FormatException {
      throw ApiException('Invalid panel URL');
    } catch (e) {
      throw ApiException('Could not reach panel: $e');
    }
    if (response.statusCode == 401) {
      throw ApiException('Invalid API key', statusCode: 401);
    }
    if (response.statusCode == 403) {
      throw ApiException('You do not have permission for this action', statusCode: 403);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Request failed (${response.statusCode})', statusCode: response.statusCode);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ApiException('Invalid response from panel');
    }
  }

  /// Upper bound on server-list pages (50 servers each by default), so a
  /// panel that never reports a last page can't loop forever.
  static const maxServerPages = 50;

  Future<List<PteroServer>> listServers() async {
    final servers = <PteroServer>[];
    for (var page = 1; page <= maxServerPages; page++) {
      final totalPages = await _get('/api/client?page=$page', (json) {
        final data = (json['data'] as List).cast<Map<String, dynamic>>();
        servers.addAll(data.map(PteroServer.fromJson));
        final pagination = (json['meta'] as Map?)?['pagination'] as Map?;
        return (pagination?['total_pages'] as num?)?.toInt() ?? 1;
      });
      if (page >= totalPages) break;
    }
    return servers;
  }

  Future<PteroServer> getServer(String identifier) => _get('/api/client/servers/$identifier', PteroServer.fromJson);

  Future<ServerResources> getResources(String identifier) =>
      _get('/api/client/servers/$identifier/resources', ServerResources.fromJson);

  Future<void> sendPower(String identifier, String signal) async {
    await _post('/api/client/servers/$identifier/power', {'signal': signal});
  }

  Future<WebsocketDetails> getWebsocketDetails(String identifier) =>
      _get('/api/client/servers/$identifier/websocket', WebsocketDetails.fromJson);

  void close() => _client.close();
}
