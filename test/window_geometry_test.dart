// ADR-0062 guards: the persisted rectangle round-trips, and a restored
// rectangle can never land where the pointer cannot reach it.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/state/window_geometry.dart';
import 'package:planstar/state/window_geometry_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('window_geometry');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('clamp', () {
    final screen = const Rect.fromLTWH(0, 0, 1920, 1080);

    test('a rectangle on screen survives untouched', () {
      final geometry = const WindowGeometry(
        x: 100,
        y: 100,
        width: 1280,
        height: 860,
      );
      final clamped = geometry.clampedTo(screen);
      expect(clamped.x, 100);
      expect(clamped.y, 100);
      expect(clamped.width, 1280);
      expect(clamped.height, 860);
    });

    test('a window dragged mostly off screen is pulled back', () {
      // Left edge 1900: only 20px of the window would remain — past the
      // rescue band (x=1800 with 120px visible is legal and stays put).
      final geometry = const WindowGeometry(
        x: 1900,
        y: 1160,
        width: 1280,
        height: 860,
      );
      final clamped = geometry.clampedTo(screen);
      // The leading edge sits at most at `right - edgeRescue`…
      expect(clamped.x, 1920 - WindowGeometry.edgeRescue);
      // …and at least `min - edgeRescue` below the bottom edge.
      expect(clamped.y, 1080 - WindowGeometry.edgeRescue);
      expect(clamped.y, 1080 - WindowGeometry.edgeRescue);
    });

    test('a window larger than the screen shrinks to the screen', () {
      final geometry = const WindowGeometry(
        x: 0,
        y: 0,
        width: 4000,
        height: 3000,
      );
      final clamped = geometry.clampedTo(screen);
      expect(clamped.width, 1920);
      expect(clamped.height, 1080);
    });

    test('works on a screen whose origin is not the zero point', () {
      final screen = const Rect.fromLTWH(-1920, 0, 1920, 1080);
      final geometry = const WindowGeometry(
        x: 500,
        y: 100,
        width: 1280,
        height: 860,
      );
      final clamped = geometry.clampedTo(screen);
      // x=500 is fully off the left-placed screen; the rescue band pulls the
      // leading edge back so exactly 80px of the window is on screen.
      expect(clamped.x, 0 - WindowGeometry.edgeRescue);
    });

    test('a json round-trip preserves the rectangle', () {
      const geometry = WindowGeometry(x: 12.5, y: -3, width: 960, height: 640);
      final restored = WindowGeometry.fromJson(
        jsonDecode(jsonEncode(geometry.toJson())) as Map<String, Object?>,
      );
      expect(restored.x, 12.5);
      expect(restored.y, -3);
      expect(restored.width, 960);
      expect(restored.height, 640);
    });
  });

  group('store', () {
    test('saves and reads back', () {
      final store = WindowGeometryStore.open(root);
      store.save(const WindowGeometry(x: 8, y: 9, width: 1000, height: 700));

      final reopened = WindowGeometryStore.open(root);
      expect(reopened.value?.x, 8);
      expect(reopened.value?.width, 1000);
    });

    test('a torn file reads as absent', () {
      File('${root.path}/window.json').writeAsStringSync('{"x": 1, "y');
      final store = WindowGeometryStore.open(root);
      expect(store.value, isNull);
    });
  });
}
