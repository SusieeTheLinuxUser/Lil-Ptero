import 'package:flutter_test/flutter_test.dart';
import 'package:pterodactyl_mobile/format.dart';

void main() {
  group('formatBytes', () {
    test('bytes under 1024 shown as B', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
    });
    test('kilobytes', () => expect(formatBytes(1024), '1.0 KB'));
    test('megabytes', () => expect(formatBytes(1024 * 1024), '1.0 MB'));
    test('gigabytes', () => expect(formatBytes(1024 * 1024 * 1024), '1.0 GB'));
  });

  group('formatUptime', () {
    test('seconds', () => expect(formatUptime(const Duration(seconds: 59)), '59s'));
    test('minutes', () => expect(formatUptime(const Duration(seconds: 60)), '1m 0s'));
    test('hours', () => expect(formatUptime(const Duration(minutes: 60)), '1h 0m'));
    test('days', () => expect(formatUptime(const Duration(hours: 24)), '1d 0h'));
  });

  group('normalizePanelUrl', () {
    test('adds https:// when no scheme is given', () {
      expect(normalizePanelUrl('panel.example.com'), 'https://panel.example.com');
    });
    test('leaves an explicit scheme alone', () {
      expect(normalizePanelUrl('http://panel.example.com'), 'http://panel.example.com');
      expect(normalizePanelUrl('https://panel.example.com'), 'https://panel.example.com');
    });
    test('strips a trailing slash', () {
      expect(normalizePanelUrl('panel.example.com/'), 'https://panel.example.com');
    });
    test('trims surrounding whitespace', () {
      expect(normalizePanelUrl('  panel.example.com  '), 'https://panel.example.com');
    });
  });
}
