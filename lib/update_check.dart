import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// F-Droid clients, by package name, as Android reports the installer. An
/// install from one of them asks F-Droid for updates, never GitHub. Decided
/// at runtime, not with a build flag: F-Droid verifies its build is the same
/// APK as the GitHub release (reproducible build, AllowedAPKSigningKeys in
/// fdroid/dev.susiee.lilptero.yml), so both channels must be one binary.
const fdroidClients = {
  'org.fdroid.fdroid',
  'org.fdroid.basic',
  'com.looker.droidify',
  'com.machiav3lli.fdroid', // Neo Store
};

/// Keep in sync with `version:` in pubspec.yaml (X.Y.Z+buildNumber);
/// test/update_check_test.dart fails the build if they drift.
const String appVersion = '0.1.4';

const _fdroidApiUrl = 'https://f-droid.org/api/v1/packages/dev.susiee.lilptero';
const githubLatestUrl = 'https://github.com/SusieeTheLinuxUser/Lil-Ptero/releases/latest';
const Duration updateCheckTimeout = Duration(seconds: 10);

/// True when [candidate] > [current], compared dot-by-dot as numbers (so
/// 0.1.10 > 0.1.9, unlike a string compare). Garbage is never "newer".
bool isNewerVersion(String candidate, String current) {
  final c = _numericSegments(candidate);
  final k = _numericSegments(current);
  if (c == null || k == null) return false;
  final length = c.length > k.length ? c.length : k.length;
  for (var i = 0; i < length; i++) {
    final a = i < c.length ? c[i] : 0;
    final b = i < k.length ? k[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

List<int>? _numericSegments(String version) {
  final segments = <int>[];
  for (final part in version.split('.')) {
    final value = int.tryParse(part);
    if (value == null) return null;
    segments.add(value);
  }
  return segments;
}

/// GET /releases/latest without following redirects; GitHub answers 302
/// with a `location` of .../releases/tag/vX.Y.Z. Returns the bare version
/// ("X.Y.Z") or null for a missing/garbage header.
String? versionFromGithubLocation(String? location) {
  if (location == null) return null;
  const tagPrefix = '/releases/tag/v';
  final start = location.indexOf(tagPrefix);
  if (start < 0) return null;
  final version = location.substring(start + tagPrefix.length);
  return _numericSegments(version) == null ? null : version;
}

/// F-Droid API body -> `suggestedVersionCode`, or null when missing/invalid.
int? fdroidSuggestedVersionCode(String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final code = json['suggestedVersionCode'];
    if (code is int) return code;
    if (code is String) return int.tryParse(code);
    return null;
  } on FormatException {
    return null;
  }
}

/// F-Droid API body -> `versionName` of the suggested package, or null when
/// missing/invalid. Used for the banner text; the update *decision* comes
/// from [fdroidSuggestedVersionCode]. Not simply the first package: F-Droid
/// lists newer unsuggested builds (betas) first.
String? fdroidLatestVersionName(String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final packages = json['packages'];
    if (packages is! List || packages.isEmpty) return null;
    final code = fdroidSuggestedVersionCode(body);
    final suggested = packages.firstWhere(
      (p) => p is Map && p['versionCode'] == code,
      orElse: () => packages.first,
    );
    if (suggested is! Map) return null;
    final name = suggested['versionName'];
    return name is String ? name : null;
  } on FormatException {
    return null;
  }
}

/// Newest published version name ("X.Y.Z") if it's newer than this build,
/// else null. Silent on any network error or timeout — a failed check
/// must never nag or crash the app. [fdroidClient] is injectable for tests.
Future<String?> fetchNewerVersionName({required bool fdroid, http.Client? fdroidClient}) async {
  try {
    return fdroid ? await _fetchFdroid(fdroidClient) : await _fetchGithub();
  } catch (_) {
    return null;
  }
}

Future<String?> _fetchFdroid(http.Client? client) async {
  final effective = client ?? http.Client();
  try {
    final response = await effective.get(Uri.parse(_fdroidApiUrl)).timeout(updateCheckTimeout);
    if (response.statusCode == 404) return null; // not listed on F-Droid yet
    if (response.statusCode != 200) return null;
    // Names, not version codes: each ABI's APK has its own code (build * 10 + ABI
    // digit), so the suggested code is no measure of "newer" for this phone.
    final name = fdroidLatestVersionName(response.body);
    return name != null && isNewerVersion(name, appVersion) ? name : null;
  } finally {
    if (client == null) effective.close();
  }
}

Future<String?> _fetchGithub() async {
  final client = HttpClient()..connectionTimeout = updateCheckTimeout;
  try {
    // package:http follows redirects and hides the 302, so use dart:io
    // and read the location header instead — no GitHub API (rate limits).
    final request = await client.getUrl(Uri.parse(githubLatestUrl));
    request.followRedirects = false;
    final response = await request.close().timeout(updateCheckTimeout);
    final version = versionFromGithubLocation(response.headers.value(HttpHeaders.locationHeader));
    return version != null && isNewerVersion(version, appVersion) ? version : null;
  } finally {
    client.close(force: true);
  }
}