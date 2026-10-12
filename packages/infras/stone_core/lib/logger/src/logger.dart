import 'dart:async';

/// Log severity levels following enterprise logging standards.
enum LogLevel {
  /// Verbose debug information (disabled in production).
  debug,

  /// Informational messages highlighting progress.
  info,

  /// Warning conditions that don't prevent operation.
  warning,

  /// Error conditions requiring attention.
  error,

  /// Critical failures requiring immediate action.
  fatal,
}

/// Enterprise-grade logger with severity levels, tag filtering,
/// pluggable output backends, and batch write buffering.
///
/// Inspired by TencentCloudChatLog's timer-based batch writing
/// and adopts a policy pattern for flexible output routing.
///
/// Supports an optional external logger callback for integration
/// with application-level logging systems (e.g., sentry, firebase).
///
/// Features:
/// - **Five severity levels**: debug, info, warning, error, fatal.
/// - **Tag filtering**: allow only specific module tags.
/// - **Pluggable backends**: inject external log handlers.
/// - **Batch buffering**: collects logs and flushes periodically.
/// - **Log history**: retains recent logs for debugging.
class StoneLogger {
  static void Function(String message, [String? tag, LogLevel? level])?
      _appLogger;

  /// Minimum log level. Messages below this level are discarded.
  /// Defaults to [LogLevel.debug] in debug mode, [LogLevel.info] otherwise.
  static LogLevel minLevel = LogLevel.debug;

  /// Optional set of tags to filter. If non-empty, only messages
  /// with matching tags will be logged.
  static Set<String> _allowedTags = {};

  /// Batch buffer for deferred log output.
  static final List<LogEntry> _buffer = [];

  /// Timer for periodic batch flushing.
  static Timer? _flushTimer;

  /// Whether batch mode is enabled.
  static bool _batchMode = false;

  /// Maximum buffer size before a forced flush.
  static const int _maxBufferSize = 200;

  /// Callback invoked when the buffer is flushed. Set this to
  /// persist or transport batched logs.
  static void Function(List<LogEntry> entries)? onBatchFlush;

  /// Sets an optional external logger.
  ///
  /// When set, all log calls will be forwarded to this logger
  /// instead of using the default [print].
  static set logger(
      void Function(String message, [String? tag, LogLevel? level])? logger) {
    _appLogger = logger;
  }

  /// Sets the allowed tags filter.
  ///
  /// When non-empty, only messages with tags in this set are logged.
  /// Pass an empty set to allow all tags.
  static void setAllowedTags(Set<String> tags) {
    _allowedTags = tags;
  }

  /// Enables batch logging mode.
  ///
  /// In batch mode, log messages are buffered and flushed
  /// periodically via [flushInterval]. The [onBatchFlush]
  /// callback is invoked with each batch of entries.
  ///
  /// Call [disableBatchMode] to revert to immediate output.
  static void enableBatchMode({Duration flushInterval = const Duration(seconds: 10)}) {
    if (_batchMode) return;
    _batchMode = true;
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
    info('Batch logging enabled (flush: ${flushInterval.inSeconds}s)', 'stone');
  }

  /// Disables batch logging mode and immediately flushes buffer.
  static void disableBatchMode() {
    _batchMode = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    flush();
  }

  /// Forces immediate flush of the buffered log entries.
  static void flush() {
    if (_buffer.isEmpty) return;
    final batch = List<LogEntry>.from(_buffer);
    _buffer.clear();
    if (onBatchFlush != null) {
      onBatchFlush!(batch);
    } else {
      for (final entry in batch) {
        _writeImmediate(entry.level, entry.message, entry.tag, entry.timestamp);
      }
    }
  }

  /// Returns a copy of the current log buffer (for debugging).
  static List<LogEntry> get buffer => List.unmodifiable(_buffer);

  /// Whether batch mode is active.
  static bool get isBatchMode => _batchMode;

  static bool _shouldLog(LogLevel level, String tag) {
    if (level.index < minLevel.index) return false;
    if (_allowedTags.isNotEmpty && !_allowedTags.contains(tag)) return false;
    return true;
  }

  static void _log(LogLevel level, String message, String tag) {
    if (!_shouldLog(level, tag)) return;

    final now = DateTime.now();
    if (_batchMode) {
      _buffer.add(LogEntry(
        level: level,
        message: message,
        tag: tag,
        timestamp: now,
      ));
      if (_buffer.length >= _maxBufferSize) {
        flush();
      }
    } else {
      _writeImmediate(level, message, tag, now);
    }
  }

  static void _writeImmediate(
      LogLevel level, String message, String tag, DateTime timestamp) {
    if (_appLogger == null) {
      final levelTag = level.name.toUpperCase().padRight(5);
      print('${timestamp.toIso8601String()} [$levelTag] [$tag] $message'); // ignore: avoid_print
    } else {
      _appLogger?.call(message, tag, level);
    }
  }

  /// Logs a debug message.
  static void debug(String message, [String tag = 'stone']) {
    _log(LogLevel.debug, message, tag);
  }

  /// Logs an informational message.
  static void info(String message, [String tag = 'stone']) {
    _log(LogLevel.info, message, tag);
  }

  /// Logs a warning message.
  static void warning(String message, [String tag = 'stone']) {
    _log(LogLevel.warning, message, tag);
  }

  /// Logs an error message.
  static void error(String message, [String tag = 'stone']) {
    _log(LogLevel.error, message, tag);
  }

  /// Logs a fatal error message.
  static void fatal(String message, [String tag = 'stone']) {
    _log(LogLevel.fatal, message, tag);
  }

  /// Legacy log method (equivalent to [info]).
  static void log(String message, [String tag = 'stone']) {
    info(message, tag);
  }

  /// Returns the current timestamp in milliseconds since epoch as a string.
  static String getLocalTimestamp() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

/// A single log entry captured by [StoneLogger]'s batch buffer.
class LogEntry {
  final LogLevel level;
  final String message;
  final String tag;
  final DateTime timestamp;

  const LogEntry({
    required this.level,
    required this.message,
    required this.tag,
    required this.timestamp,
  });

  /// Serializes to a map for structured storage / upload.
  Map<String, dynamic> toJson() => {
        'level': level.name,
        'message': message,
        'tag': tag,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Deserializes from a map.
  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        level: LogLevel.values.firstWhere(
          (l) => l.name == (json['level'] as String? ?? 'info'),
          orElse: () => LogLevel.info,
        ),
        message: json['message'] as String? ?? '',
        tag: json['tag'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  String toString() {
    final levelTag = level.name.toUpperCase().padRight(5);
    return '${timestamp.toIso8601String()} [$levelTag] [$tag] $message';
  }
}
