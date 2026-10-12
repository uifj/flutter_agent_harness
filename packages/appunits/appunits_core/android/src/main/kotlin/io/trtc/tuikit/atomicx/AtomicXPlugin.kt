package io.trtc.tuikit.atomicx

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.trtc.tuikit.atomicx.permission.Permission
import io.trtc.tuikit.atomicx.device_info.Device
import io.trtc.tuikit.atomicx.albumpicker.AtomicAlbumPickerPlugin
import io.trtc.tuikit.atomicx.imageuploader.AtomicImageUploaderPlugin

/** Atomic_xPlugin */
class AtomicXPlugin: FlutterPlugin, ActivityAware {
  companion object {
      private const val TAG = "AtomicXPlugin"
  }

  private var permission: Permission? = null
  private var device: Device? = null
  private var pipManager: PictureInPictureManager? = null
  private var albumPickerPlugin: AtomicAlbumPickerPlugin? = null
  private var imageUploaderPlugin: AtomicImageUploaderPlugin? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    permission = Permission(flutterPluginBinding)
    device = Device(flutterPluginBinding)
    pipManager = PictureInPictureManager(flutterPluginBinding)
    albumPickerPlugin = AtomicAlbumPickerPlugin(flutterPluginBinding)
    imageUploaderPlugin = AtomicImageUploaderPlugin(flutterPluginBinding)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    permission?.dispose()
    permission = null
    pipManager?.dispose()
    pipManager = null
    albumPickerPlugin?.dispose()
    albumPickerPlugin = null
    imageUploaderPlugin?.dispose()
    imageUploaderPlugin = null
    device?.dispose()
    device = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    pipManager?.attachToActivity(binding.activity)
    permission?.onAttachedToActivity(binding)
    imageUploaderPlugin?.onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    pipManager?.updateActivity(null)
    permission?.onDetachedFromActivityForConfigChanges()
    imageUploaderPlugin?.onDetachedFromActivityForConfigChanges()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    pipManager?.updateActivity(binding.activity)
    permission?.onReattachedToActivityForConfigChanges(binding)
    imageUploaderPlugin?.onReattachedToActivityForConfigChanges(binding)
  }

  override fun onDetachedFromActivity() {
    pipManager?.detachFromActivity()
    permission?.onDetachedFromActivity()
    imageUploaderPlugin?.onDetachedFromActivity()
  }
}
