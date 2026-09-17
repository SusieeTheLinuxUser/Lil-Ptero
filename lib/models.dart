enum ServerState { running, starting, stopping, offline, unknown }

ServerState parseServerState(String? value) {
  switch (value) {
    case 'running':
      return ServerState.running;
    case 'starting':
      return ServerState.starting;
    case 'stopping':
      return ServerState.stopping;
    case 'offline':
      return ServerState.offline;
    default:
      return ServerState.unknown;
  }
}

class PteroServer {
  final String identifier;
  final String name;
  final String? description;
  final int memoryLimitMb;
  final int diskLimitMb;
  final int cpuLimitPercent;

  const PteroServer({
    required this.identifier,
    required this.name,
    this.description,
    this.memoryLimitMb = 0,
    this.diskLimitMb = 0,
    this.cpuLimitPercent = 0,
  });

  factory PteroServer.fromJson(Map<String, dynamic> json) {
    final attributes = (json['attributes'] as Map?)?.cast<String, dynamic>() ?? json;
    final limits = (attributes['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PteroServer(
      identifier: attributes['identifier'] as String,
      name: attributes['name'] as String,
      description: attributes['description'] as String?,
      memoryLimitMb: (limits['memory'] as num?)?.toInt() ?? 0,
      diskLimitMb: (limits['disk'] as num?)?.toInt() ?? 0,
      cpuLimitPercent: (limits['cpu'] as num?)?.toInt() ?? 0,
    );
  }
}

class ServerResources {
  final ServerState currentState;
  final int memoryBytes;
  final double cpuAbsolute;
  final int diskBytes;
  final int networkRxBytes;
  final int networkTxBytes;
  final int uptimeMs;

  const ServerResources({
    required this.currentState,
    this.memoryBytes = 0,
    this.cpuAbsolute = 0,
    this.diskBytes = 0,
    this.networkRxBytes = 0,
    this.networkTxBytes = 0,
    this.uptimeMs = 0,
  });

  factory ServerResources.fromJson(Map<String, dynamic> json) {
    final attributes = (json['attributes'] as Map?)?.cast<String, dynamic>() ?? json;
    final resources = (attributes['resources'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ServerResources(
      currentState: parseServerState(attributes['current_state'] as String?),
      memoryBytes: (resources['memory_bytes'] as num?)?.toInt() ?? 0,
      cpuAbsolute: (resources['cpu_absolute'] as num?)?.toDouble() ?? 0,
      diskBytes: (resources['disk_bytes'] as num?)?.toInt() ?? 0,
      networkRxBytes: (resources['network_rx_bytes'] as num?)?.toInt() ?? 0,
      networkTxBytes: (resources['network_tx_bytes'] as num?)?.toInt() ?? 0,
      uptimeMs: (resources['uptime'] as num?)?.toInt() ?? 0,
    );
  }
}

class WebsocketDetails {
  final String token;
  final String socketUrl;

  const WebsocketDetails({required this.token, required this.socketUrl});

  factory WebsocketDetails.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map).cast<String, dynamic>();
    return WebsocketDetails(
      token: data['token'] as String,
      socketUrl: data['socket'] as String,
    );
  }
}

/// A parsed frame from the Pterodactyl console websocket (`{event, args}`).
sealed class ConsoleEvent {
  const ConsoleEvent();

  factory ConsoleEvent.fromFrame(Map<String, dynamic> frame) {
    final event = frame['event'] as String? ?? '';
    final args = (frame['args'] as List?)?.cast<String>() ?? const <String>[];
    switch (event) {
      case 'auth success':
        return const AuthSuccess();
      case 'console output':
        return ConsoleOutput(args.isNotEmpty ? args[0] : '');
      case 'status':
        return StatusChanged(parseServerState(args.isNotEmpty ? args[0] : null));
      case 'stats':
        return StatsUpdate(args.isNotEmpty ? args[0] : '{}');
      case 'token expiring':
        return const TokenExpiring();
      case 'token expired':
        return const TokenExpired();
      default:
        return UnknownEvent(event);
    }
  }
}

class AuthSuccess extends ConsoleEvent {
  const AuthSuccess();
}

class ConsoleOutput extends ConsoleEvent {
  final String line;
  const ConsoleOutput(this.line);
}

class StatusChanged extends ConsoleEvent {
  final ServerState state;
  const StatusChanged(this.state);
}

class StatsUpdate extends ConsoleEvent {
  final String rawJson;
  const StatsUpdate(this.rawJson);
}

class TokenExpiring extends ConsoleEvent {
  const TokenExpiring();
}

class TokenExpired extends ConsoleEvent {
  const TokenExpired();
}

class UnknownEvent extends ConsoleEvent {
  final String event;
  const UnknownEvent(this.event);
}

/// Emitted locally (not a server frame) when the socket connection closes.
class SocketClosed extends ConsoleEvent {
  const SocketClosed();
}
