import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pterodactyl_mobile/update_check.dart';

const _tagUrl = 'https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases/tag/';

void main() {
  group('isNewerVersion', () {
    test('newer / same / older', () {
      expect(isNewerVersion('0.1.4', '0.1.3'), isTrue);
      expect(isNewerVersion('0.1.3', '0.1.3'), isFalse);
      expect(isNewerVersion('0.1.2', '0.1.3'), isFalse);
    });
    test('numeric, not string, comparison: 0.1.10 > 0.1.9', () {
      expect(isNewerVersion('0.1.10', '0.1.9'), isTrue);
      expect(isNewerVersion('0.1.9', '0.1.10'), isFalse);
    });
    test('garbage versions are never newer', () {
      expect(isNewerVersion('banana', '0.1.3'), isFalse);
      expect(isNewerVersion('0.1.x', '0.1.3'), isFalse);
      expect(isNewerVersion('', '0.1.3'), isFalse);
    });
    test('a longer candidate wins on its extra segment', () {
      expect(isNewerVersion('0.1.1', '0.1'), isTrue);
    });
  });

  group('versionFromGithubLocation', () {
    test('parses .../releases/tag/vX.Y.Z', () {
      expect(versionFromGithubLocation('${_tagUrl}v0.1.3'), '0.1.3');
    });
    test('null for a missing header or a non-tag location', () {
      expect(versionFromGithubLocation(null), isNull);
      expect(versionFromGithubLocation('https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases'), isNull);
      expect(versionFromGithubLocation('https://example.com/elsewhere'), isNull);
    });
    test('garbage tag versions are rejected', () {
      expect(versionFromGithubLocation('${_tagUrl}vlatest'), isNull);
      expect(versionFromGithubLocation('${_tagUrl}v0.1.x'), isNull);
      expect(versionFromGithubLocation('${_tagUrl}vnot.a.version'), isNull);
    });
  });

  group('github redirect vs appVersion', () {
    bool newer(String? location) {
      final version = versionFromGithubLocation(location);
      return version != null && isNewerVersion(version, appVersion);
    }

    test('newer release -> true', () => expect(newer('${_tagUrl}v0.1.4'), isTrue));
    test('same release -> false', () => expect(newer('${_tagUrl}v$appVersion'), isFalse));
    test('older release -> false', () => expect(newer('${_tagUrl}v0.1.2'), isFalse));
    test('garbage location -> false', () {
      expect(newer('${_tagUrl}vbanana'), isFalse);
      expect(newer('https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases/latest'), isFalse);
    });
  });

  group('fdroid response parsing', () {
    test('suggestedVersionCode and latest versionName are parsed', () {
      const body =
          '{"packageName":"dev.susiee.lilptero","suggestedVersionCode":5,"packages":[{"versionName":"0.1.4","versionCode":5}]}';
      expect(fdroidSuggestedVersionCode(body), 5);
      expect(fdroidLatestVersionName(body), '0.1.4');
    });
    test('names the suggested package, not a newer unsuggested one listed first', () {
      const body =
          '{"suggestedVersionCode":5,"packages":[{"versionName":"0.2.0-beta","versionCode":6},{"versionName":"0.1.4","versionCode":5}]}';
      expect(fdroidLatestVersionName(body), '0.1.4');
    });
    test('missing fields -> null', () {
      const body = '{"packageName":"dev.susiee.lilptero","packages":[]}';
      expect(fdroidSuggestedVersionCode(body), isNull);
      expect(fdroidLatestVersionName(body), isNull);
    });
    test('garbage bodies -> null', () {
      expect(fdroidSuggestedVersionCode('<html>error</html>'), isNull);
      expect(fdroidSuggestedVersionCode('"a string"'), isNull);
      expect(fdroidLatestVersionName('{"packages":"not a list"}'), isNull);
    });
  });

  group('fdroid fetch', () {
    test('newer suggestedVersionCode -> version name', () async {
      final version = await fetchNewerVersionName(
        fdroid: true,
        fdroidClient: MockClient((_) async => http.Response(
              '{"suggestedVersionCode":5,"packages":[{"versionName":"0.1.4","versionCode":5}]}',
              200,
            )),
      );
      expect(version, '0.1.4');
    });
    test('same build number -> null (up to date)', () async {
      final version = await fetchNewerVersionName(
        fdroid: true,
        fdroidClient: MockClient((_) async => http.Response(
              '{"suggestedVersionCode":$appBuildNumber,"packages":[{"versionName":"$appVersion","versionCode":$appBuildNumber}]}',
              200,
            )),
      );
      expect(version, isNull);
    });
    test('404 (not listed yet) -> null, not an error', () async {
      final version = await fetchNewerVersionName(
        fdroid: true,
        fdroidClient: MockClient((_) async => http.Response('not found', 404)),
      );
      expect(version, isNull);
    });
    test('server error -> null, silently', () async {
      final version = await fetchNewerVersionName(
        fdroid: true,
        fdroidClient: MockClient((_) async => http.Response('boom', 500)),
      );
      expect(version, isNull);
    });
  });

  test('version constants stay in sync with pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(.+)\+(\d+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'version: line not found in pubspec.yaml');
    expect(match!.group(1), appVersion, reason: 'appVersion drifted from pubspec.yaml');
    expect(match.group(2), '$appBuildNumber', reason: 'appBuildNumber drifted from pubspec.yaml');
  });
}