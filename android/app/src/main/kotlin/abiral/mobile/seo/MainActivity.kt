package abiral.mobile.seo

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pendingShares = arrayListOf<String>()
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        if (savedInstanceState == null) {
            receiveShare(intent)
        } else {
            // Recreating the activity must not replay an already consumed share.
            pendingShares.addAll(
                savedInstanceState.getStringArrayList(PENDING_SHARES) ?: arrayListOf()
            )
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mobile_seo/incoming_share"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "takePendingShares") {
                    val shares = pendingShares.toList()
                    pendingShares.clear()
                    result.success(shares)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveShare(intent)
    }

    private fun receiveShare(intent: Intent) {
        if (intent.action != Intent.ACTION_SEND ||
            (intent.type != "text/plain" && intent.type != "text/uri-list")) return
        val text = try {
            intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                ?: intent.clipData?.let { clip ->
                    if (clip.itemCount == 0) null
                    else clip.getItemAt(0).let { it.text?.toString() ?: it.uri?.toString() }
                }
                ?: ""
        } catch (_: RuntimeException) {
            ""
        }
        // Bound activity state without truncating a URL into a different URL.
        if (pendingShares.size == 8) pendingShares.removeAt(0)
        pendingShares.add(if (text.length <= 32768) text else "")
        shareChannel?.invokeMethod("shareAvailable", null)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putStringArrayList(PENDING_SHARES, ArrayList(pendingShares))
        super.onSaveInstanceState(outState)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        shareChannel?.setMethodCallHandler(null)
        shareChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val PENDING_SHARES = "mobile_seo.pending_shares"
    }
}
