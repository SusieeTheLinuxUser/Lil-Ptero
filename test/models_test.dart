import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/models.dart';

void main() {
  group('PteroServer.fromJson', () {
    test('parses attributes and limits', () {
      final server = PteroServer.fromJson({
        'attributes': {
          'identifier': 'abc123',
          'name': 'Survival',
          'description': 'My server',
          'limits': {'memory': 2048, 'disk': 10240, 'cpu': 200},
        },
      });
      expect(server.identifier, 'abc123');
      expect(server.name, 'Survival');
      expect(server.description, 'My server');
      expect(server.memoryLimitMb, 2048);
      expect(server.diskLimitMb, 10240);
      expect(server.cpuLimitPercent, 200);
    });

    test('handles missing optional fields', () {
      final server = PteroServer.fromJson({
        'attributes': {'identifier': 'abc123', 'name': 'Survival'},
      });
      expect(server.description, isNull);
      expect(server.memoryLimitMb, 0);
    });
  });

  group('ServerResources.fromJson', () {
    test('parses state and resource usage', () {
      final resources = ServerResources.fromJson({
        'attributes': {
          'current_state': 'running',
          'resources': {
            'memory_bytes': 512,
            'cpu_absolute': 12.5,
            'disk_bytes': 1024,
            'network_rx_bytes': 10,
            'network_tx_bytes': 20,
            'uptime': 5000,
          },
        },
      });
      expect(resources.currentState, ServerState.running);
      expect(resources.cpuAbsolute, 12.5);
      expect(resources.memoryBytes, 512);
      expect(resources.uptimeMs, 5000);
    });

    test('defaults to unknown state and zeroed resources when missing', () {
      final resources = ServerResources.fromJson({'attributes': {}});
      expect(resources.currentState, ServerState.unknown);
      expect(resources.memoryBytes, 0);
    });
  });

  group('ConsoleEvent.fromFrame', () {
    test('parses console output', () {
      final event = ConsoleEvent.fromFrame({
        'event': 'console output',
        'args': ['hello'],
      });
      expect(event, isA<ConsoleOutput>());
      expect((event as ConsoleOutput).line, 'hello');
    });

    test('parses token lifecycle events', () {
      expect(ConsoleEvent.fromFrame({'event': 'token expiring', 'args': []}), isA<TokenExpiring>());
      expect(ConsoleEvent.fromFrame({'event': 'token expired', 'args': []}), isA<TokenExpired>());
      expect(ConsoleEvent.fromFrame({'event': 'auth success', 'args': []}), isA<AuthSuccess>());
    });

    test('unrecognized events become UnknownEvent', () {
      final event = ConsoleEvent.fromFrame({'event': 'mystery', 'args': []});
      expect(event, isA<UnknownEvent>());
      expect((event as UnknownEvent).event, 'mystery');
    });
  });
}
