package io.trtc.tuikit.atomicx.albumpicker

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * AtomicAlbumPickerPlugin module
 *
 * Intermediary layer between AtomicXPlugin and AlbumPickerHandler,
 * managing MethodChannels and EventChannels for the Flutter Plugin layer.
 */
class AtomicAlbumPickerPlugin(
    private val pluginBinding: FlutterPlugin.FlutterPluginBinding
) : MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL_NAME = "atomic_x/album_picker"
        private const val EVENT_CHANNEL_NAME = "atomic_x/album_picker_events"
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val albumPickerHandler = AlbumPickerHandler(pluginBinding.flutterAssets) { event ->
        eventSink?.success(event)
    }

    init {
        methodChannel = MethodChannel(pluginBinding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(pluginBinding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel?.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "pickMedia" -> {
                albumPickerHandler.handlePickMedia(call, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
    }
}
