import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/credentials.dart';

void main() {
  const credentials = Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only');

  PterodactylApiClient clientFor(http.Response response) {
    final api = PterodactylApiClient(credentials, client: MockClient((_) async => response));
    addTearDown(api.close);
    return api;
  }

  test('sends authenticated requests and accepts an empty power response', () async {
    final requests = <http.Request>[];
    final api = PterodactylApiClient(credentials, client: MockClient((request) async {
      requests.add(request);
      return request.method == 'POST'
          ? http.Response('', 204)
          : http.Response('{"data":[{"attributes":{"identifier":"abc","name":"Survival"}}]}', 200);
    }));
    addTearDown(api.close);

    expect((await api.listServers()).single.name, 'Survival');
    await api.sendPower('abc', 'start');
    expect(requests.first.url.path, '/api/client');
    expect(requests.first.headers['Authorization'], 'Bearer ${credentials.apiKey}');
    expect(requests.last.url.path, '/api/client/servers/abc/power');
    expect(jsonDecode(requests.last.body), {'signal': 'start'});
  });

  String page(int number, int totalPages) => jsonEncode({
        'data': [
          {
            'attributes': {'identifier': 's$number', 'name': 'Server $number'}
          }
        ],
        'meta': {
          'pagination': {'current_page': number, 'total_pages': totalPages}
        },
      });

  test('follows meta.pagination until every page is loaded', () async {
    final pages = <String?>[];
    final api = PterodactylApiClient(credentials, client: MockClient((request) async {
      pages.add(request.url.queryParameters['page']);
      return http.Response(page(int.parse(request.url.queryParameters['page']!), 3), 200);
    }));
    addTearDown(api.close);

    expect((await api.listServers()).map((s) => s.name), ['Server 1', 'Server 2', 'Server 3']);
    expect(pages, ['1', '2', '3']);
  });

  test('stops at the page cap when a panel never reports a last page', () async {
    var requests = 0;
    final api = PterodactylApiClient(credentials, client: MockClient((request) async {
      requests++;
      return http.Response(page(requests, 100000), 200);
    }));
    addTearDown(api.close);

    expect(await api.listServers(), hasLength(PterodactylApiClient.maxServerPages));
    expect(requests, PterodactylApiClient.maxServerPages);
  });

  test('never sends the API key to a plain http panel', () async {
    var sent = false;
    final api = PterodactylApiClient(
      const Credentials(panelUrl: 'http://panel.example.com', apiKey: 'test-only'),
      client: MockClient((_) async {
        sent = true;
        return http.Response('{"data":[]}', 200);
      }),
    );
    addTearDown(api.close);
    await expectLater(api.listServers(), throwsA(isA<ApiException>()));
    expect(sent, isFalse);
  });

  for (final status in [302, 401, 403, 500]) {
    test('HTTP $status becomes an ApiException before parsing the body', () async {
      await expectLater(
        clientFor(http.Response('<html>Error</html>', status)).listServers(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', status)),
      );
    });
  }

  for (final body in ['<html>Login</html>', '', 'null', '[]', '{"data":[{}]}']) {
    test('invalid server list $body becomes a safe ApiException', () async {
      await expectLater(
        clientFor(http.Response(body, 200)).listServers(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid response from panel')),
      );
    });
  }

  test('all GET endpoints wrap invalid payload types', () async {
    final api = clientFor(http.Response('{"attributes":[],"data":[]}', 200));
    for (final request in [api.getServer, api.getResources, api.getWebsocketDetails]) {
      await expectLater(request('abc'), throwsA(isA<ApiException>()));
    }
  });
}
