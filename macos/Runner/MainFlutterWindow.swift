import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    registerProjectFolderChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// The `dsh/project_folder` method channel: native directory picking via
/// NSOpenPanel plus the security-scoped bookmark lifecycle, so a
/// user-selected workspace stays accessible to the app across restarts.
/// Mirrors IstiN/flutter_agent_harness's `fah/project_folder` channel:
/// pickDirectory returns {path, bookmark}; startAccessing resolves a stored
/// bookmark and claims access; stopAccessing releases it.
private func registerProjectFolderChannel(messenger: FlutterBinaryMessenger) {
  let channel = FlutterMethodChannel(
    name: "dsh/project_folder",
    binaryMessenger: messenger
  )
  channel.setMethodCallHandler { call, result in
    switch call.method {
    case "pickDirectory":
      result(pickDirectoryWithBookmark())
    case "startAccessing":
      let bookmark = call.arguments as? String ?? ""
      result(startAccessing(bookmarkBase64: bookmark))
    case "stopAccessing":
      let bookmark = call.arguments as? String ?? ""
      stopAccessing(bookmarkBase64: bookmark)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Opens an NSOpenPanel for a single directory and returns the chosen path
/// plus a security-scoped bookmark for it, or nil when cancelled.
private func pickDirectoryWithBookmark() -> [String: String]? {
  let panel = NSOpenPanel()
  panel.canChooseDirectories = true
  panel.canChooseFiles = false
  panel.allowsMultipleSelection = false
  panel.canCreateDirectories = true
  panel.prompt = "Open"
  panel.message = "Choose a workspace folder the agent may work in"
  guard panel.runModal() == .OK, let url = panel.url else { return nil }
  guard let bookmark = try? url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
  ) else {
    NSLog(
      "pickDirectoryWithBookmark: failed to create security-scoped bookmark for %@",
      url.path)
    return nil
  }
  return [
    "path": url.path,
    "bookmark": bookmark.base64EncodedString(),
  ]
}

/// Resolves a security-scoped bookmark and starts accessing the resource.
/// False when the bookmark cannot be decoded, is stale, or the folder is
/// gone — the caller falls back to asking the user to re-pick.
private func startAccessing(bookmarkBase64: String) -> Bool {
  guard let data = Data(base64Encoded: bookmarkBase64) else { return false }
  var stale = false
  guard
    let url = try? URL(
      resolvingBookmarkData: data,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    ), !stale
  else { return false }
  return url.startAccessingSecurityScopedResource()
}

/// Best-effort stop of a previously started security-scoped access.
private func stopAccessing(bookmarkBase64: String) {
  guard let data = Data(base64Encoded: bookmarkBase64) else { return }
  var stale = false
  guard
    let url = try? URL(
      resolvingBookmarkData: data,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
  else { return }
  url.stopAccessingSecurityScopedResource()
}
