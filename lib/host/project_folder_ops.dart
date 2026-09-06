// Native project-folder operations: directory picking plus the
// security-scoped bookmark access lifecycle (macOS).
//
// A port of IstiN/flutter_agent_harness's `ProjectFolderChannelOps` — the
// Swift side lives in `macos/Runner/MainFlutterWindow.swift` on the
// `dsh/project_folder` channel. The seam is an interface so the file tree,
// the settings panel and startup can all be driven by fakes in tests.
//
// Why bookmarks at all: without one, the folder the user picked is
// accessible only while the app lives. The bookmark is the OS's own promise
// that the SAME app may reach the SAME folder tomorrow — resolved with
// `startAccessing` before any file under the workspace is touched.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;

/// The native folder-pick and bookmark lifecycle, behind an interface so
/// tests can drive the flows without a window or a platform channel.
abstract interface class ProjectFolderOps {
  /// Opens the native directory panel; null when cancelled/unsupported.
  ///
  /// The bookmark is what makes the pick durable: store it beside the path
  /// (see [AppSettings.workspaceBookmark]) and resolve it at the next launch
  /// with [startAccessing] before touching anything under the path.
  Future<({String path, String bookmark})?> pickDirectory();

  /// Resolves a security-scoped bookmark and starts accessing the folder.
  /// False when the bookmark is stale or the folder is gone — the caller
  /// falls back to asking the user to re-pick.
  Future<bool> startAccessing(String bookmark);

  /// Best-effort stop of a previously started access.
  Future<void> stopAccessing(String bookmark);
}

/// The method-channel-backed [ProjectFolderOps] (macOS only).
final class ProjectFolderChannelOps implements ProjectFolderOps {
  /// Creates the ops over the `dsh/project_folder` channel.
  const ProjectFolderChannelOps();

  /// Whether native project-folder picking is available (macOS only).
  ///
  /// `kIsWeb` first: `dart:io Platform` throws on the web.
  static bool get isSupported => !kIsWeb && Platform.isMacOS;

  static const _channel = MethodChannel('dsh/project_folder');

  @override
  Future<({String path, String bookmark})?> pickDirectory() async {
    if (!isSupported) return null;
    final result = await _channel.invokeMapMethod<String, String>(
      'pickDirectory',
    );
    if (result == null) return null;
    final path = result['path'];
    final bookmark = result['bookmark'];
    if (path == null || bookmark == null) return null;
    return (path: path, bookmark: bookmark);
  }

  @override
  Future<bool> startAccessing(String bookmark) async {
    if (!isSupported) return false;
    final ok = await _channel.invokeMethod<bool>('startAccessing', bookmark);
    return ok ?? false;
  }

  @override
  Future<void> stopAccessing(String bookmark) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('stopAccessing', bookmark);
  }
}

/// Restores the workspace access a previous launch recorded, if any.
///
/// Called once at startup, before anything reads under `settings.workspaceRoot`
/// — a bookmark that is never resolved is a permission that was never claimed.
/// Returns whether access was restored, so the caller can decide whether the
/// saved root is trustworthy this launch.
///
/// The failure paths are quiet by design: a stale bookmark, a missing folder,
/// or a non-macOS platform all mean the same thing — "ask the user again" —
/// and the hero picker already says that with its own UI.
Future<bool> restoreWorkspaceAccess({
  required String? bookmark,
  ProjectFolderOps? ops,
}) async {
  if (bookmark == null || bookmark.isEmpty) return false;
  final resolved = ops ??
      (ProjectFolderChannelOps.isSupported
          ? const ProjectFolderChannelOps()
          : null);
  if (resolved == null) return false;
  try {
    return await resolved.startAccessing(bookmark);
  } catch (_) {
    // A channel that answers with an error (not false) is still just "no
    // access"; the app must come up, not crash on its own restore step.
    return false;
  }
}
