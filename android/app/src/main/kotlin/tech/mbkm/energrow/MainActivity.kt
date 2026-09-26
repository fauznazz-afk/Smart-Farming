package tech.mbkm.energrow

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import tech.mbkm.energrow.alarm.AlarmBridgePlugin

/**
 * `FlutterFragmentActivity`, not `FlutterActivity`, because `local_auth` needs a
 * Fragment to host its `BiometricPrompt`.
 *
 * This also registers the app's own plugin. `GeneratedPluginRegistrant` only
 * knows about packages from pub, so a plugin that lives in this module has to be
 * attached by hand.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AlarmBridgePlugin())
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
}
