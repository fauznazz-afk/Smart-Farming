package tech.mbkm.energrow

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import tech.mbkm.energrow.alarm.AlarmBridgePlugin

/**
 * The app's host activity, and the place its own plugins are registered.
 *
 * `GeneratedPluginRegistrant` only knows about packages from pub, so a plugin
 * that lives in this module has to be attached by hand.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AlarmBridgePlugin())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.argument<Boolean>("secure") == true
                    // Applied on the UI thread: this touches the window, and the
                    // method channel handler is not on it.
                    runOnUiThread {
                        if (secure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Keeps [getIntent] pointing at the newest intent.
     *
     * A notification tap arrives here rather than through `onCreate` when the app
     * is already running, and the bridge reads the alarm id straight off the
     * activity's intent, so it has to be replaced. `singleTop` in the manifest is
     * what makes this method the delivery path in the first place.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private companion object {
        const val CHANNEL = "tech.mbkm.energrow/secure_window"
    }
}
