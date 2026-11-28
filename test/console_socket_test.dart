import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/api_client.dart';
import 'package:pterodactyl_mobile/console_socket.dart';
import 'package:pterodactyl_mobile/credentials.dart';
import 'package:pterodactyl_mobile/models.dart';

void main() {
  test('uppercase WSS stays on HTTPS for the websocket handshake', () {
    expect(websocketHandshakeUri(Uri.parse('WSS://node.example.com:8080')).scheme, 'https');
  });

  test('plain WS downgrades to HTTP for the websocket handshake', () {
    expect(websocketHandshakeUri(Uri.parse('ws://node.example.com:8080')).scheme, 'http');
  });

  test('reconnect delays scale with the base and cap at 30 times it', () {
    expect(
      [for (var i = 0; i < 7; i++) reconnectDelay(i, base: const Duration(milliseconds: 500)).inMilliseconds],
      [500, 1000, 2000, 4000, 8000, 15000, 15000],
    );
  });

  late HttpServer server;
  late ConsoleSocket console;
  late Future<WebSocket> peerFuture;
  late StreamController<WebSocket> upgraded; // every accepted socket, in order
  late Completer<http.Response> refresh;
  late int requests;
  late int connections;
  var redirectHandshake = false;
  late Completer<void> refreshStarted;
  late Completer<void> handshakeStarted;
  Completer<void>? allowHandshake;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upgraded = StreamController<WebSocket>.broadcast();
    connections = 0;
    redirectHandshake = false;
    handshakeStarted = Completer<void>();
    allowHandshake = null;
    server.listen((request) async {
      connections++;
      if (redirectHandshake) {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, 'ws://127.0.0.1:${server.port}/redirect-target');
        await request.response.close();
        return;
      }
      if (!handshakeStarted.isCompleted) handshakeStarted.complete();
      if (allowHandshake != null) await allowHandshake!.future;
      upgraded.add(await WebSocketTransformer.upgrade(request));
    });
    peerFuture = upgraded.stream.first;
    refresh = Completer<http.Response>();
    refreshStarted = Completer<void>();
    requests = 0;
    final api = PterodactylApiClient(
      const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
      client: MockClient((_) async {
        if (++requests > 1) {
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          return refresh.future;
        }
        return http.Response(
            jsonEncode({
              'data': {'token': 'test-token', 'socket': 'ws://127.0.0.1:${server.port}'},
            }),
            200);
      }),
    );
    console = ConsoleSocket(api, 'abc');
    addTearDown(() async {
      await console.dispose();
      api.close();
      await server.close(force: true);
    });
  });

  Future<(WebSocket, StreamIterator<dynamic>)> authenticate([ConsoleSocket? socket]) async {
    final target = socket ?? console;
    await target.connect();
    final peer = await peerFuture;
    final frames = StreamIterator(peer);
    addTearDown(frames.cancel);
    expect(await frames.moveNext(), isTrue);
    expect(jsonDecode(frames.current as String)['event'], 'auth');
    final authenticated = target.events.firstWhere((event) => event is AuthSuccess);
    peer.add('{"event":"auth success"}');
    await authenticated;
    return (peer, frames);
  }

  test('rejects a cleartext console URL from a remote node', () async {
    final api = PterodactylApiClient(
      const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
      client: MockClient((_) async => http.Response(
            jsonEncode({'data': {'token': 'test-token', 'socket': 'ws://node.example.com:8080'}}),
            200,
          )),
    );
    final insecure = ConsoleSocket(api, 'abc');
    addTearDown(() async {
      await insecure.dispose();
      api.close();
    });

    await expectLater(insecure.connect(), throwsA(isA<ApiException>()));
    expect(insecure.state, ConsoleConnectionState.connecting);
  });

  test('does not follow websocket handshake redirects', () async {
    redirectHandshake = true;
    await expectLater(console.connect(), throwsA(isA<WebSocketException>()));
    expect(connections, 1);
  });

  test('an auth that is never answered closes the socket instead of spinning forever', () async {
    final quick = ConsoleSocket(console.apiClient, 'abc', timeout: const Duration(milliseconds: 200));
    addTearDown(quick.dispose);
    final closed = quick.events.firstWhere((event) => event is SocketClosed);
    await quick.connect();
    await peerFuture; // the panel accepts the socket, then never answers auth
    await closed.timeout(const Duration(seconds: 5));
    expect(quick.state, ConsoleConnectionState.disconnected);
  });

  test('a handshake that stalls fails the connect', () async {
    allowHandshake = Completer<void>(); // never completed: the upgrade hangs
    final quick = ConsoleSocket(console.apiClient, 'abc', timeout: const Duration(milliseconds: 200));
    addTearDown(quick.dispose);
    await expectLater(quick.connect(), throwsA(isA<TimeoutException>()));
  });

  test('failed token refresh disconnects once without an unhandled error', () async {
    final (peer, _) = await authenticate();
    final events = <ConsoleEvent>[];
    final subscription = console.events.listen(events.add);
    addTearDown(subscription.cancel);
    final expiring = console.events.firstWhere((event) => event is TokenExpiring);
    peer.add('{"event":"token expiring"}');
    await expiring;
    final closed = console.events.firstWhere((event) => event is SocketClosed);
    refresh.complete(http.Response('', 401));
    await closed;
    await console.dispose();
    expect(console.state, ConsoleConnectionState.disconnected);
    expect(events.whereType<SocketClosed>(), hasLength(1));
  });

  test('duplicate expiry frames make one refresh and late results cannot revive a closed socket', () async {
    final (peer, frames) = await authenticate();
    final expiring = console.events.where((event) => event is TokenExpiring).take(2).toList();
    peer.add('{"event":"token expiring"}');
    peer.add('{"event":"token expiring"}');
    await expiring;
    await refreshStarted.future;
    expect(requests, 2);
    final closed = console.events.firstWhere((event) => event is SocketClosed);
    peer.add('{"event":"token expired"}');
    await closed;
    refresh.complete(http.Response('{"data":{"token":"late","socket":"unused"}}', 200));
    expect(await frames.moveNext(), isFalse);
    expect(console.state, ConsoleConnectionState.disconnected);
  });

  for (final frame in ['not json', '[]', '{"event":"console output","args":[1]}']) {
    test('malformed frame $frame disconnects safely', () async {
      final (peer, _) = await authenticate();
      final closed = console.events.firstWhere((event) => event is SocketClosed);
      peer.add(frame);
      await closed;
      expect(console.state, ConsoleConnectionState.disconnected);
    });
  }

  test('disposing during token lookup prevents a connection', () async {
    // The first lookup is consumed so this connection waits on the completer.
    requests = 1;
    final connecting = console.connect();
    await console.dispose();
    refresh.complete(http.Response(
        jsonEncode({
          'data': {'token': 'test-token', 'socket': 'ws://127.0.0.1:${server.port}'},
        }),
        200));
    await connecting;
    expect(console.state, ConsoleConnectionState.disconnected);
    expect(connections, 0);
    await console.dispose();
  });

  test('disposing during the WebSocket handshake closes the late socket without authenticating', () async {
    allowHandshake = Completer<void>();
    final connecting = console.connect();
    await handshakeStarted.future;
    await console.dispose();
    allowHandshake!.complete();
    final peer = await peerFuture;
    expect(await peer.toList(), isEmpty);
    await connecting;
    expect(console.state, ConsoleConnectionState.disconnected);
  });

  for (final status in [200, 401]) {
    test('refresh response $status after disposal cannot emit events or authenticate', () async {
      final (peer, frames) = await authenticate();
      final events = <ConsoleEvent>[];
      final subscription = console.events.listen(events.add);
      addTearDown(subscription.cancel);
      peer.add('{"event":"token expiring"}');
      await refreshStarted.future;
      await console.dispose();
      final eventCount = events.length;
      refresh.complete(http.Response('{"data":{"token":"late","socket":"unused"}}', status));
      expect(await frames.moveNext(), isFalse);
      // Drain the pending mock HTTP response before checking the final state.
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(eventCount));
      expect(console.state, ConsoleConnectionState.disconnected);
    });
  }

  test('refresh authenticates again on the same connection', () async {
    final (peer, frames) = await authenticate();
    peer.add('{"event":"token expiring"}');
    await refreshStarted.future;
    expect(console.state, ConsoleConnectionState.refreshingToken);
    refresh.complete(http.Response('{"data":{"token":"refreshed","socket":"unused"}}', 200));
    expect(await frames.moveNext(), isTrue);
    expect(jsonDecode(frames.current as String), {
      'event': 'auth',
      'args': ['refreshed'],
    });
    final authenticated = console.events.firstWhere((event) => event is AuthSuccess);
    peer.add('{"event":"auth success"}');
    await authenticated;
    expect(console.state, ConsoleConnectionState.authenticated);
    expect(connections, 1);
  });

  test('commands are sent only after authentication', () async {
    await console.connect();
    final peer = await peerFuture;
    final frames = StreamIterator(peer);
    addTearDown(frames.cancel);
    expect(await frames.moveNext(), isTrue); // Initial auth frame.
    console.sendCommand('before-auth');
    final authenticated = console.events.firstWhere((event) => event is AuthSuccess);
    peer.add('{"event":"auth success"}');
    await authenticated;
    console.sendCommand('after-auth');
    expect(await frames.moveNext(), isTrue);
    expect(jsonDecode(frames.current as String), {
      'event': 'send command',
      'args': ['after-auth'],
    });
  });

  test('reconnect waits double from 1 s and stop growing at 30 s', () {
    expect([for (var i = 0; i < 8; i++) reconnectDelay(i).inSeconds], [1, 2, 4, 8, 16, 30, 30, 30]);
  });

  group('auto-reconnect', () {
    const fast = Duration(milliseconds: 10);
    String details(String token) => jsonEncode({
          'data': {'token': token, 'socket': 'ws://127.0.0.1:${server.port}'},
        });

    late ConsoleSocket quick;
    late List<ConsoleEvent> events;
    setUp(() {
      quick = ConsoleSocket(console.apiClient, 'abc', retryBase: fast);
      addTearDown(quick.dispose);
      events = [];
      final subscription = quick.events.listen(events.add);
      addTearDown(subscription.cancel);
    });

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 100));

    test('an unexpected drop reconnects with a fresh token', () async {
      final (peer, _) = await authenticate(quick);
      final second = upgraded.stream.first;
      refresh.complete(http.Response(details('fresh-token'), 200));
      final reauthenticated = quick.events.firstWhere((event) => event is AuthSuccess);
      await peer.close(); // the panel drops the connection

      final peer2 = await second;
      final frames = StreamIterator(peer2);
      addTearDown(frames.cancel);
      expect(await frames.moveNext(), isTrue);
      expect(jsonDecode(frames.current as String), {
        'event': 'auth',
        'args': ['fresh-token'],
      });
      peer2.add('{"event":"auth success"}');
      await reauthenticated;
      expect(quick.state, ConsoleConnectionState.authenticated);
      expect(events.whereType<SocketClosed>(), hasLength(1));
      expect(events.whereType<Reconnecting>().single.delay, fast);
      expect(connections, 2);
    });

    test('a failed attempt backs off and tries again', () async {
      final (peer, _) = await authenticate(quick);
      refresh.complete(http.Response('', 502)); // every lookup after the first fails
      await peer.close();
      await quick.events.where((event) => event is Reconnecting).take(3).drain<void>();
      expect(events.whereType<Reconnecting>().map((e) => e.delay).take(3), [fast, fast * 2, fast * 4]);
      expect(connections, 1);
    });

    test('a rejected token stops retrying', () async {
      final (peer, _) = await authenticate(quick);
      final closed = quick.events.firstWhere((event) => event is SocketClosed);
      peer.add('{"event":"jwt error","args":["denied"]}');
      await closed;
      await settle();
      expect(events.whereType<Reconnecting>(), isEmpty);
      expect(requests, 1);
      expect(quick.state, ConsoleConnectionState.disconnected);
    });

    test('an auth error while reconnecting gives up', () async {
      final (peer, _) = await authenticate(quick);
      refresh.complete(http.Response('', 401));
      final closedTwice = quick.events.where((event) => event is SocketClosed).take(2).drain<void>();
      await peer.close();
      await closedTwice;
      await settle();
      expect(events.whereType<Reconnecting>(), hasLength(1));
      expect(requests, 2);
    });

    test('a server last seen offline is not reconnected', () async {
      final (peer, _) = await authenticate(quick);
      final status = quick.events.firstWhere((event) => event is StatusChanged);
      peer.add('{"event":"status","args":["offline"]}');
      await status;
      final closed = quick.events.firstWhere((event) => event is SocketClosed);
      await peer.close();
      await closed;
      await settle();
      expect(events.whereType<Reconnecting>(), isEmpty);
      expect(requests, 1);
    });

    test('disposing cancels a pending reconnect', () async {
      final (peer, _) = await authenticate(quick);
      final waiting = quick.events.firstWhere((event) => event is Reconnecting);
      await peer.close();
      await waiting;
      await quick.dispose();
      await settle();
      expect(requests, 1);
      expect(connections, 1);
    });
  });

  group('token refresh finishing after a reconnect', () {
    // The shared harness above blocks every lookup after the first on one
    // completer; these tests need the refresh (request 2) to stay in flight
    // while the reconnect's own lookup (request 3) answers immediately.
    late HttpServer server;
    late ConsoleSocket socket;
    late List<WebSocket> peers; // every accepted socket, in order
    late Completer<http.Response> refreshGate;
    late Completer<void> refreshArrived;
    var requests = 0;

    String details(String token) => jsonEncode({
          'data': {'token': token, 'socket': 'ws://127.0.0.1:${server.port}'},
        });

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      peers = [];
      final upgraded = StreamController<WebSocket>.broadcast();
      upgraded.stream.listen(peers.add); // subscribed before any handshake
      addTearDown(upgraded.close);
      server.listen((request) async {
        upgraded.add(await WebSocketTransformer.upgrade(request));
      });
      refreshGate = Completer<http.Response>();
      refreshArrived = Completer<void>();
      requests = 0;
      final api = PterodactylApiClient(
        const Credentials(panelUrl: 'https://panel.example.com', apiKey: 'test-only'),
        client: MockClient((_) async {
          requests++;
          if (requests == 1) return http.Response(details('token-1'), 200);
          if (requests == 2) {
            refreshArrived.complete();
            return refreshGate.future; // the token refresh stays in flight
          }
          return http.Response(details('token-2'), 200); // the reconnect's fresh lookup
        }),
      );
      socket = ConsoleSocket(api, 'abc', retryBase: const Duration(milliseconds: 10));
      addTearDown(() async {
        await socket.dispose();
        api.close();
        await server.close(force: true);
      });
    });

    Future<WebSocket> accepted(int index) async {
      while (peers.length <= index) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return peers[index];
    }

    /// Connects, authenticates on connection 1, starts a token refresh whose
    /// answer is held back, drops the connection and lets the socket
    /// reconnect and re-authenticate on connection 2. Returns the new peer.
    Future<(WebSocket, StreamIterator<dynamic>)> dropAndReconnect() async {
      await socket.connect();
      final peer1 = await accepted(0);
      final frames1 = StreamIterator(peer1);
      addTearDown(frames1.cancel);
      expect(await frames1.moveNext(), isTrue);
      expect(jsonDecode(frames1.current as String)['args'], ['token-1']);
      final firstAuth = socket.events.firstWhere((event) => event is AuthSuccess);
      peer1.add('{"event":"auth success"}');
      await firstAuth;

      peer1.add('{"event":"token expiring"}');
      await refreshArrived.future; // refresh (request 2) now in flight

      final secondAuth = socket.events.where((event) => event is AuthSuccess).first;
      await peer1.close(); // the panel drops the connection mid-refresh
      final peer2 = await accepted(1);
      final frames2 = StreamIterator(peer2);
      addTearDown(frames2.cancel);
      expect(await frames2.moveNext(), isTrue);
      expect(jsonDecode(frames2.current as String)['args'], ['token-2']);
      peer2.add('{"event":"auth success"}');
      await secondAuth;
      return (peer2, frames2);
    }

    test('a stale answer does not re-auth the reconnected socket', () async {
      final events = <ConsoleEvent>[];
      final subscription = socket.events.listen(events.add);
      addTearDown(subscription.cancel);
      final (peer2, frames2) = await dropAndReconnect();

      refreshGate.complete(http.Response(details('token-1'), 200)); // the old refresh lands
      final staleFrame =
          await frames2.moveNext().timeout(const Duration(seconds: 2), onTimeout: () => false);

      expect(staleFrame, isFalse, reason: 'a stale token must not re-auth the new socket');
      expect(socket.state, ConsoleConnectionState.authenticated);
      expect(events.whereType<SocketClosed>(), hasLength(1));
      expect(peer2.close(), completes);
    });

    test('a stale failure does not close the reconnected socket', () async {
      final events = <ConsoleEvent>[];
      final subscription = socket.events.listen(events.add);
      addTearDown(subscription.cancel);
      final (peer2, _) = await dropAndReconnect();

      refreshGate.complete(http.Response('boom', 500)); // the old refresh fails
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events.whereType<SocketClosed>(), hasLength(1),
          reason: 'only the original drop, not the stale refresh failure');
      expect(events.whereType<Reconnecting>(), hasLength(1));
      expect(socket.state, ConsoleConnectionState.authenticated);
      expect(peer2.close(), completes);
    });
  });
}
