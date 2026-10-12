import Flutter
import UIKit

public class AtomicXPlugin: NSObject, FlutterPlugin {
  private var permission: Permission?
  private var device: Device?
  private var albumPicker: AtomicAlbumPickerPlugin?
  private var imageUploader: AtomicImageUploaderPlugin?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "atomic_x", binaryMessenger: registrar.messenger())
    let instance = AtomicXPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    instance.permission = Permission(registrar: registrar)
    instance.device = Device(registrar: registrar)
    instance.albumPicker = AtomicAlbumPickerPlugin(registrar: registrar)
    instance.imageUploader = AtomicImageUploaderPlugin(registrar: registrar)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  deinit {
    albumPicker?.dispose()
    imageUploader?.dispose()
  }
}
