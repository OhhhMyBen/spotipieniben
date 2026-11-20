String formatDuration(Duration d) {
  final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  final minStr = hours > 0 ? minutes.toString().padLeft(2, '0') : '$minutes';
  final secStr = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minStr:$secStr';
  }
  return '$minStr:$secStr';
}

String formatRemaining(Duration position, Duration total) {
  final remaining = total - position;
  if (remaining <= Duration.zero) return '-0:00';
  return '-${formatDuration(remaining)}';
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}
