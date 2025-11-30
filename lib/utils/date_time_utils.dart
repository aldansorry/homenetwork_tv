/// Utility functions for date and time formatting
class DateTimeUtils {
  DateTimeUtils._(); // Private constructor to prevent instantiation

  /// Format duration to HH:MM:SS or MM:SS format
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = _twoDigits(duration.inMinutes.remainder(60));
    final seconds = _twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '${_twoDigits(hours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Convert integer to two-digit string
  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

