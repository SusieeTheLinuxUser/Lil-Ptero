import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_client.dart';
import 'models.dart';

enum ConsoleConnectionState { connecting, authenticating, authenticated, refreshingToken, disconnected }

/// Pure state machine for the console auth/token-refresh lifecycle, kept
/// free of any socket I/O so it can be unit tested with scripted events.
class ConsoleStateMachine {
  ConsoleConnectionState state = ConsoleConnectionState.connecting;

  ConsoleConnectionState onEvent(ConsoleEvent event) {
    switch (event) {
      case AuthSuccess():
        state = ConsoleConnectionState.authenticated;
      case TokenExpiring():
        if (state == ConsoleConnectionState.authenticated) {
          state = ConsoleConnectionState.refreshingToken;
        }
      case TokenExpired():
        state = ConsoleConnectionState.disconnected;
      default:
        break;
    }
    return state;
  }

  void onAuthSent() {
    state = ConsoleConnectionState.authenticating;
  }

  void onDisconnected() {
    state = ConsoleConnectionState.disconnected;
  }
}

/// Wraps a Pterodactyl console websocket: fetches a token, connects,
/// authenticates, refreshes the token in place on `token expiring`, and
/// surfaces parsed [ConsoleEvent]s (including a local [SocketClosed] on
/// disconnect) as a stream.
class ConsoleSocket {
  final PterodactylApiClient apiClient;
  final String serverIdentifier;

  WebSocket? _socket;
  StreamSubscription? _subscription;
  final _controller = StreamController<ConsoleEvent>.broadcast();
  final _stateMachine = ConsoleStateMachine();

  ConsoleSocket(this.apiClient, this.serverIdentifier);

  Stream<ConsoleEvent> get events => _controller.stream;
  ConsoleConnectionState get state => _stateMachine.state;

  Future<void> connect() async {
    final details = await apiClient.getWebsocketDetails(serverIdentifier);
    final socket = await WebSocket.connect(
      details.socketUrl,
      headers: {'Origin': apiClient.credentials.panelUrl},
    );
    _socket = socket;
    _subscription = socket.listen(_handleRaw, onDone: _handleClosed, onError: (_) => _handleClosed());
    _sendAuth(details.token);
  }

  void _sendAuth(String token) {
    _stateMachine.onAuthSent();
    _socket?.add(jsonEncode({
      'event': 'auth',
      'args': [token],
    }));
  }

  void _handleRaw(dynamic raw) {
    final frame = jsonDecode(raw as String) as Map<String, dynamic>;
    final event = ConsoleEvent.fromFrame(frame);
    _stateMachine.onEvent(event);
    _controller.add(event);
    if (event is TokenExpiring) {
      unawaited(_refreshToken());
    } else if (event is TokenExpired) {
      _socket?.close();
    }
  }

  Future<void> _refreshToken() async {
    final details = await apiClient.getWebsocketDetails(serverIdentifier);
    _sendAuth(details.token);
  }

  void _handleClosed() {
    _stateMachine.onDisconnected();
    _controller.add(const SocketClosed());
  }

  void sendCommand(String command) {
    _socket?.add(jsonEncode({
      'event': 'send command',
      'args': [command],
    }));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _socket?.close();
    await _controller.close();
  }
}
