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

  /// How long the handshake, or an auth answer, may take. Without it a panel that
  /// stalls leaves the console spinning forever with no Reconnect button.
  final Duration timeout;

  WebSocket? _socket;
  Timer? _authTimer;
  StreamSubscription? _subscription;
  final _controller = StreamController<ConsoleEvent>.broadcast();
  final _stateMachine = ConsoleStateMachine();
  bool _disposed = false;

  ConsoleSocket(this.apiClient, this.serverIdentifier, {this.timeout = const Duration(seconds: 15)});

  Stream<ConsoleEvent> get events => _controller.stream;
  ConsoleConnectionState get state => _stateMachine.state;

  Future<void> connect() async {
    if (_disposed) return;
    final details = await apiClient.getWebsocketDetails(serverIdentifier);
    if (_disposed) return;
    final pending = WebSocket.connect(
      details.socketUrl,
      headers: {'Origin': apiClient.credentials.panelUrl},
    );
    final WebSocket socket;
    try {
      socket = await pending.timeout(timeout);
    } on TimeoutException {
      // The handshake can't be cancelled; close it if it ever finishes.
      unawaited(pending.then((late) => late.close(), onError: (_) {}));
      rethrow;
    }
    if (_disposed) {
      await socket.close();
      return;
    }
    _socket = socket;
    // Pings detect half-open connections (Wi-Fi to mobile handoff) so onDone fires.
    socket.pingInterval = const Duration(seconds: 30);
    _subscription = socket.listen(_handleRaw, onDone: _handleClosed, onError: (_) => _handleClosed());
    _sendAuth(details.token);
  }

  void _sendAuth(String token) {
    _stateMachine.onAuthSent();
    _authTimer?.cancel();
    _authTimer = Timer(timeout, () {
      if (state != ConsoleConnectionState.authenticated) _handleClosed();
    });
    _socket?.add(jsonEncode({
      'event': 'auth',
      'args': [token],
    }));
  }

  void _handleRaw(dynamic raw) {
    if (_disposed || state == ConsoleConnectionState.disconnected) return;
    final ConsoleEvent event;
    try {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      event = ConsoleEvent.fromFrame(frame);
    } on FormatException {
      _handleClosed();
      return;
    } on TypeError {
      _handleClosed();
      return;
    }
    if (event is TokenExpired) {
      _controller.add(event);
      _handleClosed();
      return;
    }
    final previousState = state;
    _stateMachine.onEvent(event);
    // Answered: a timer left running could close the socket later, mid token refresh.
    if (event is AuthSuccess) _authTimer?.cancel();
    _controller.add(event);
    if (event is TokenExpiring && previousState == ConsoleConnectionState.authenticated) {
      unawaited(_refreshToken());
    }
  }

  Future<void> _refreshToken() async {
    try {
      final details = await apiClient.getWebsocketDetails(serverIdentifier);
      if (_disposed || state == ConsoleConnectionState.disconnected) return;
      _sendAuth(details.token);
    } catch (_) {
      _handleClosed();
    }
  }

  void _handleClosed() {
    if (_disposed || state == ConsoleConnectionState.disconnected) return;
    _authTimer?.cancel();
    _stateMachine.onDisconnected();
    unawaited(_socket?.close());
    _controller.add(const SocketClosed());
  }

  void sendCommand(String command) {
    if (_disposed || state != ConsoleConnectionState.authenticated) return;
    _socket?.add(jsonEncode({
      'event': 'send command',
      'args': [command],
    }));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _authTimer?.cancel();
    _stateMachine.onDisconnected();
    await _subscription?.cancel();
    await _socket?.close();
    await _controller.close();
  }
}
