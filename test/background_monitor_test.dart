import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/background_monitor.dart';
import 'package:pterodactyl_mobile/models.dart';

void main() {
  test('notifies only on a fresh transition into offline', () {
    expect(shouldNotifyOffline('running', ServerState.offline), isTrue);
  });

  test('does not notify when already offline last poll', () {
    expect(shouldNotifyOffline('offline', ServerState.offline), isFalse);
  });

  test('does not notify for non-offline states', () {
    expect(shouldNotifyOffline('running', ServerState.stopping), isFalse);
  });

  test('does not notify on the first poll with no prior state', () {
    expect(shouldNotifyOffline(null, ServerState.offline), isFalse);
  });

  test('a failed poll keeps the previous state', () {
    final currentStates = <String, String>{};
    carryForwardPreviousState(currentStates, {'a': 'running'}, 'a');
    expect(currentStates['a'], 'running');
  });

  test('a failed poll with no previous state stays absent', () {
    final currentStates = <String, String>{};
    carryForwardPreviousState(currentStates, <String, String>{}, 'a');
    expect(currentStates, isEmpty);
  });
}
