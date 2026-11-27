import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/console_socket.dart';
import 'package:pterodactyl_mobile/models.dart';

void main() {
  test('authenticates then tracks a successful token refresh', () {
    final machine = ConsoleStateMachine();
    expect(machine.state, ConsoleConnectionState.connecting);

    machine.onEvent(const AuthSuccess());
    expect(machine.state, ConsoleConnectionState.authenticated);

    machine.onEvent(const TokenExpiring());
    expect(machine.state, ConsoleConnectionState.refreshingToken);

    machine.onEvent(const AuthSuccess());
    expect(machine.state, ConsoleConnectionState.authenticated);
  });

  test('token expired disconnects the machine even mid-refresh', () {
    final machine = ConsoleStateMachine();
    machine.onEvent(const AuthSuccess());
    machine.onEvent(const TokenExpiring());

    machine.onEvent(const TokenExpired());
    expect(machine.state, ConsoleConnectionState.disconnected);
  });

  test('socket close marks the machine disconnected', () {
    final machine = ConsoleStateMachine();
    machine.onEvent(const AuthSuccess());
    machine.onDisconnected();
    expect(machine.state, ConsoleConnectionState.disconnected);
  });

  test('an expiring token before authentication is ignored', () {
    final machine = ConsoleStateMachine();
    machine.onEvent(const TokenExpiring());
    expect(machine.state, ConsoleConnectionState.connecting);
    machine.onAuthSent();
    expect(machine.state, ConsoleConnectionState.authenticating);
    machine.onEvent(const TokenExpiring());
    expect(machine.state, ConsoleConnectionState.authenticating);
  });

  test('a repeated expiry frame does not restart the refresh', () {
    final machine = ConsoleStateMachine();
    machine.onEvent(const AuthSuccess());
    machine.onEvent(const TokenExpiring());
    machine.onEvent(const TokenExpiring());
    expect(machine.state, ConsoleConnectionState.refreshingToken);
  });

  test('a jwt error frame does not change the machine state', () {
    final machine = ConsoleStateMachine();
    machine.onEvent(const AuthSuccess());
    machine.onEvent(const JwtError());
    expect(machine.state, ConsoleConnectionState.authenticated);
  });

  test('token expired while still connecting disconnects', () {
    final machine = ConsoleStateMachine();
    machine.onEvent(const TokenExpired());
    expect(machine.state, ConsoleConnectionState.disconnected);
  });
}
