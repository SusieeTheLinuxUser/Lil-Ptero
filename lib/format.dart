/// Defaults to https:// when the input omits a scheme (e.g. "panel.example.com").
String normalizePanelUrl(String raw) {
  var url = raw.trim();
  // A scheme with missing or doubled slashes ("https:/host", "https:///host")
  // has no "://" and would otherwise be prefixed again into an unusable URL.
  url = url.replaceFirstMapped(
    RegExp(r'^(https?):/+(?!/)', caseSensitive: false),
    (match) => '${match.group(1)!}://',
  );
  if (!url.contains('://')) {
    // Plain host, or protocol-relative ("//host") — strip any leading slashes
    // so the prefix can't end up with an empty host.
    url = 'https://${url.replaceFirst(RegExp(r'^/+'), '')}';
  }
  url = url.replaceFirst(RegExp(r'/+$'), '');
  return url;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}

String formatUptime(Duration uptime) {
  if (uptime.inSeconds < 60) return '${uptime.inSeconds}s';
  if (uptime.inMinutes < 60) return '${uptime.inMinutes}m ${uptime.inSeconds % 60}s';
  if (uptime.inHours < 24) return '${uptime.inHours}h ${uptime.inMinutes % 60}m';
  return '${uptime.inDays}d ${uptime.inHours % 24}h';
}
