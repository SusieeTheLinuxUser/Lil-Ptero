import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/update_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const installInfo = MethodChannel('dev.susiee.lilptero/install_info');

  const lastCheckKey = 'update_check_last_ms';

  late Map<String, String> store; // the "secure storage" contents
  late List<String> requests; // every HTTP request that was actually made

  setUp(() {
    store = {};
    requests = [];
    UpdatePrefs.enabled.value = true;
    messenger.setMockMethodCallHandler(storage, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      final key = args?['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : store[key];
        case 'write':
          final value = args?['value'] as String?;
          if (key != null && value != null) store[key] = value;
          return null;
        default:
          return null;
      }
    });
    // F-Droid client: the update check asks F-Droid, never GitHub.
    messenger.setMockMethodCallHandler(installInfo, (call) async {
      return call.method == 'installer' ? 'org.fdroid.fdroid' : null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(installInfo, null);
  });

  /// An F-Droid client that records every request it gets.
  http.Client fdroidClient(Future<http.Response> Function(http.Request request) handler) {
    return MockClient((request) {
      requests.add(request.url.toString());
      return handler(request);
    });
  }

  test('a failed check does not stamp the 24h timer', () async {
    await UpdatePrefs.maybeCheckAndNotify(
      fdroidClient: fdroidClient((_) async => throw http.ClientException('offline')),
    );
    expect(requests, isNotEmpty, reason: 'the check should have been attempted');
    expect(store.containsKey(lastCheckKey), isFalse);
  });

  test('an HTTP error does not stamp the 24h timer', () async {
    await UpdatePrefs.maybeCheckAndNotify(
      fdroidClient: fdroidClient((_) async => http.Response('boom', 500)),
    );
    expect(store.containsKey(lastCheckKey), isFalse);
  });

  test('a successful check stamps the 24h timer', () async {
    await UpdatePrefs.maybeCheckAndNotify(
      fdroidClient: fdroidClient((_) async => http.Response(
            '{"suggestedVersionCode":5,"packages":[{"versionName":"0.1.4","versionCode":5}]}',
            200,
          )),
    );
    final stamp = int.tryParse(store[lastCheckKey] ?? '');
    expect(stamp, isNotNull);
    expect((DateTime.now().millisecondsSinceEpoch - stamp!).abs(), lessThan(60000));
  });

  test('a newer version stamps the 24h timer', () async {
    await UpdatePrefs.maybeCheckAndNotify(
      fdroidClient: fdroidClient((_) async => http.Response(
            '{"suggestedVersionCode":999,"packages":[{"versionName":"99.0.0","versionCode":999}]}',
            200,
          )),
    );
    expect(store.containsKey(lastCheckKey), isTrue);
  });

  test('"not listed on F-Droid yet" (404) stamps the 24h timer', () async {
    await UpdatePrefs.maybeCheckAndNotify(
      fdroidClient: fdroidClient((_) async => http.Response('not found', 404)),
    );
    expect(store.containsKey(lastCheckKey), isTrue);
  });

  test('a check from the last 24h asks nothing at all', () async {
    store[lastCheckKey] = DateTime.now().millisecondsSinceEpoch.toString();
    await UpdatePrefs.maybeCheckAndNotify(
      fdroidClient: fdroidClient((_) async => http.Response('{}', 200)),
    );
    expect(requests, isEmpty);
  });
}
