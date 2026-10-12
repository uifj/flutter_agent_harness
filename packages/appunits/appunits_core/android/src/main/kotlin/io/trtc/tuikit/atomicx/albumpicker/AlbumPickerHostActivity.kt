package io.trtc.tuikit.atomicx.albumpicker

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity

/**
 * AlbumPickerHostActivity
 *
 * Minimal Activity that hosts the AAR's AlbumPickerView (a FrameLayout).
 * Config, theme, and listener are passed via AlbumPickerHandler's static companion.
 */
class AlbumPickerHostActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AlbumPickerHostActivity"
        var currentInstance: AlbumPickerHostActivity? = null
    }

    private var pickerView: AlbumPickerView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentInstance = this

        val config = AlbumPickerHandler.pendingConfig
        val theme = AlbumPickerHandler.pendingTheme ?: AlbumPickerTheme()
        val listener = AlbumPickerHandler.pendingListener

        if (config == null || listener == null) {
            Log.e(TAG, "Missing config or listener, finishing activity")
            finish()
            return
        }

        pickerView = AlbumPickerView(this)
        setContentView(pickerView)

        pickerView?.initialize(config = config, theme = theme, listener = listener)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (currentInstance == this) {
            currentInstance = null
        }
        AlbumPickerHandler.cleanup()
    }
}
