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
