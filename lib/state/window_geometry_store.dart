// Where the window's last shape lives (ADR-0062): `<support>/window.json`,
// synchronous tmp+rename like the session sidecar. A torn or unreadable file
// is treated as absent — geometry is the one thing the app can lose without
// anyone noticing. Deliberately not in the backup: the target machine's
// screen is not this machine's screen.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

import 'window_geometry.dart';

class WindowGeometryStore {
  WindowGeometryStore._(this._file, this._value);

  static const fileName = 'window.json';

  /// Reads the persisted rectangle; absent/teared means null.
  static WindowGeometryStore open(Directory support) {
    final file = File('${support.path}/$fileName');
    WindowGeometry? value;
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          value = WindowGeometry.fromJson(decoded);
        }
      }
    } on FileSystemException {
      // Unreadable: start from nothing.
    } on FormatException {
      // Not JSON: same.
    }
    return WindowGeometryStore._(file, value);
  }

  final File _file;
  WindowGeometry? _value;

  /// The last saved rectangle, or null when nothing was saved (or the file
  /// was unreadable).
  WindowGeometry? get value => _value;

  /// Synchronous, because the caller is a debounced window callback: an async
  /// write here would race the next drag event, and the widget tests that
  /// drive geometry would hang on a Future that never finishes.
  void save(WindowGeometry geometry) {
    final temp = File('${_file.path}.tmp');
    try {
      temp.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(geometry.toJson()),
        flush: true,
      );
      temp.renameSync(_file.path);
      _value = geometry;
    } on FileSystemException {
      // The next drag event will try again; the window keeps its shape.
    }
  }
}

/// Saves the window's rectangle while the user drags or resizes, debounced
/// so a drag writes once at the end instead of per frame. Registered by the
/// composition root after the window exists (ADR-0062).
class WindowGeometryListener with WindowListener {
  WindowGeometryListener({required this.store});

  final WindowGeometryStore store;
  Timer? _debounce;

  @override
  void onWindowMove() => _schedule();

  @override
  void onWindowResize() => _schedule();

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final bounds = await windowManager.getBounds();
      store.save(
        WindowGeometry(
          x: bounds.left,
          y: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ),
      );
    });
  }
}
