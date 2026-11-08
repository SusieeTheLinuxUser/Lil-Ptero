import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

/// Wait before reconnect attempt [attempt] (0-based): 1, 2, 4, 8, 16, then 30
/// times [base] for every later attempt.
Duration reconnectDelay(int attempt, {Duration base = const Duration(seconds: 1)}) =>
    base * min(1 << min(attempt, 5), 30);

bool _isAuthError(Object error) => error is ApiException && (error.statusCode == 401 || error.statusCode == 403);

/// Wraps a Pterodactyl console websocket: fetches a token, connects,
/// authenticates, refreshes the token in place on `token expiring`, and
/// surfaces parsed [ConsoleEvent]s (including a local [SocketClosed] on
/// disconnect) as a stream.
///
/// After a drop it reconnects on its own with backoff, announcing each wait
/// with [Reconnecting]. It gives up (a [SocketClosed] with no [Reconnecting]
/// after it) when the panel rejects the key or token, or the server was last
/// seen offline. [dispose] stops it.
/// ponytail: no attempt limit, the 30 s cap keeps it cheap while the console is open.
class ConsoleSocket {
  final PterodactylApiClient apiClient;
  final String serverIdentifier;

  /// How long the handshake, or an auth answer, may take. Without it a panel that
  /// stalls leaves the console spinning forever with no Reconnect button.
  final Duration timeout;

  /// First reconnect wait; later ones double, see [reconnectDelay].
  final Duration retryBase;

  WebSocket? _socket;
  Timer? _authTimer;
  Timer? _retryTimer;
  StreamSubscription? _subscription;
  final _controller = StreamController<ConsoleEvent>.broadcast();
  final _stateMachine = ConsoleStateMachine();
  bool _disposed = false;
  bool _authRejected = false;
  ServerState? _serverState;
  int _attempt = 0;

  ConsoleSocket(this.apiClient, this.serverIdentifier,
      {this.timeout = const Duration(seconds: 15), this.retryBase = const Duration(seconds: 1)});

  Stream<ConsoleEvent> get events => _controller.stream;
  ConsoleConnectionState get state => _stateMachine.state;

  /// First connection. Throws if it fails; only later drops are retried.
  Future<void> connect() => _open();

  Future<void> _open() async {
    if (_disposed) return;
    _stateMachine.state = ConsoleConnectionState.connecting;
    final WebsocketDetails details;
    try {
      details = await apiClient.getWebsocketDetails(serverIdentifier);
    } catch (e) {
      if (_isAuthError(e)) _authRejected = true;
      rethrow;
    }
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
    if (event is TokenExpired || event is JwtError) {
      // An expired token is replaced on reconnect; a rejected one would fail again.
      if (event is JwtError) _authRejected = true;
      _controller.add(event);
      _handleClosed();
      return;
    }
    if (event is StatusChanged) _serverState = event.state;
    final previousState = state;
    _stateMachine.onEvent(event);
    if (event is AuthSuccess) {
      // Answered: a timer left running could close the socket later, mid token refresh.
      _authTimer?.cancel();
      _attempt = 0;
    }
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
    } catch (e) {
      if (_isAuthError(e)) _authRejected = true;
      _handleClosed();
    }
  }

  void _handleClosed() {
    if (_disposed || state == ConsoleConnectionState.disconnected) return;
    _authTimer?.cancel();
    _stateMachine.onDisconnected();
    // Drop the old listener so its late onDone can't close the next attempt.
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_socket?.close());
    _socket = null;
    _controller.add(const SocketClosed());
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed || _authRejected || _serverState == ServerState.offline) return;
    final delay = reconnectDelay(_attempt++, base: retryBase);
    _controller.add(Reconnecting(delay));
    _retryTimer = Timer(delay, () async {
      try {
        await _open();
      } catch (_) {
        if (_disposed) return;
        _stateMachine.onDisconnected();
        _controller.add(const SocketClosed());
        _scheduleRetry();
      }
    });
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
    _retryTimer?.cancel();
    _stateMachine.onDisconnected();
    await _subscription?.cancel();
    await _socket?.close();
    await _controller.close();
  }
}
