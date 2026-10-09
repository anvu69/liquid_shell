package vn.lasoai.liquid_shell

import android.app.Activity
import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import java.util.function.Consumer

/**
 * Streams the accessibility and power signals liquid_shell needs on Android
 * over the `vn.lasoai.liquid_shell/signals` event channel (spec §6).
 *
 * Every read is wrapped so a failure reports `false`. Every observer is
 * removed on cancel, on detach from the activity and on detach from the
 * engine. No permissions are needed.
 */
class LiquidShellPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler {
    private var context: Context? = null
    private var activity: Activity? = null
    private var channel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    private var settingsObserver: ContentObserver? = null
    private var powerReceiver: BroadcastReceiver? = null
    // Typed as Any so this class never references API 34 types on old devices.
    private var contrastListener: Any? = null
    private var blurListener: Consumer<Boolean>? = null
    private var blurWindowManager: WindowManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = EventChannel(binding.binaryMessenger, CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        removeObservers()
        sink = null
        channel?.setStreamHandler(null)
        channel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (sink != null) {
            addObservers()
            send()
        }
    }

    private fun detach() {
        removeObservers()
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        addObservers()
        send()
    }

    override fun onCancel(arguments: Any?) {
        removeObservers()
        sink = null
    }

    private fun send() {
        sink?.success(SignalReader.toPayload(read()))
    }

    private fun read(): RawSignals {
        val ctx = context
        val resolver = ctx?.contentResolver
        val api = Build.VERSION.SDK_INT
        return RawSignals(
            animatorDurationScale = attempt {
                Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
            },
            contrast = if (api >= 34) {
                attempt { ctx?.getSystemService(UiModeManager::class.java)?.contrast }
            } else {
                null
            },
            highTextContrast = attempt {
                Settings.Secure.getInt(resolver, HIGH_TEXT_CONTRAST, 0)
            },
            powerSaveMode = attempt {
                ctx?.getSystemService(PowerManager::class.java)?.isPowerSaveMode
            },
            crossWindowBlurEnabled = if (api >= 31) {
                attempt { windowManager()?.isCrossWindowBlurEnabled }
            } else {
                null
            },
            apiLevel = api,
        )
    }

    private fun windowManager(): WindowManager? =
        (activity ?: context)?.getSystemService(WindowManager::class.java)

    private fun addObservers() {
        val ctx = context ?: return
        removeObservers()

        val observer = object : ContentObserver(main) {
            override fun onChange(selfChange: Boolean) = send()
        }
        attempt {
            ctx.contentResolver.registerContentObserver(
                Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),
                false,
                observer,
            )
            ctx.contentResolver.registerContentObserver(
                Settings.Secure.getUriFor(HIGH_TEXT_CONTRAST),
                false,
                observer,
            )
            settingsObserver = observer
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = send()
        }
        val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        attempt {
            if (Build.VERSION.SDK_INT >= 33) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
            powerReceiver = receiver
        }

        if (Build.VERSION.SDK_INT >= 34) {
            attempt {
                val listener = UiModeManager.ContrastChangeListener { send() }
                ctx.getSystemService(UiModeManager::class.java)
                    ?.addContrastChangeListener(ctx.mainExecutor, listener)
                contrastListener = listener
            }
        }

        if (Build.VERSION.SDK_INT >= 31) {
            attempt {
                val wm = windowManager()
                val listener = Consumer<Boolean> { send() }
                wm?.addCrossWindowBlurEnabledListener(ctx.mainExecutor, listener)
                blurWindowManager = wm
                blurListener = listener
            }
        }
    }

    private fun removeObservers() {
        val ctx = context
        settingsObserver?.let { observer ->
            attempt { ctx?.contentResolver?.unregisterContentObserver(observer) }
        }
        settingsObserver = null
        powerReceiver?.let { receiver -> attempt { ctx?.unregisterReceiver(receiver) } }
        powerReceiver = null
        if (Build.VERSION.SDK_INT >= 34) {
            (contrastListener as? UiModeManager.ContrastChangeListener)?.let { listener ->
                attempt {
                    ctx?.getSystemService(UiModeManager::class.java)
                        ?.removeContrastChangeListener(listener)
                }
            }
        }
        contrastListener = null
        if (Build.VERSION.SDK_INT >= 31) {
            blurListener?.let { listener ->
                attempt { blurWindowManager?.removeCrossWindowBlurEnabledListener(listener) }
            }
        }
        blurListener = null
        blurWindowManager = null
    }

    /** Runs [block]; any SecurityException or other runtime failure → null. */
    private inline fun <T> attempt(block: () -> T): T? =
        try {
            block()
        } catch (e: SecurityException) {
            null
        } catch (e: Settings.SettingNotFoundException) {
            null
        } catch (e: RuntimeException) {
            null
        }

    private companion object {
        const val CHANNEL = "vn.lasoai.liquid_shell/signals"
        const val HIGH_TEXT_CONTRAST = "high_text_contrast_enabled"
    }
}
