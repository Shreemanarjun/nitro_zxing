package dev.shreeman.nitro_zxing

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import nitro.nitro_zxing_module.NitroZxingJniBridge

class NitroZxingPlugin : FlutterPlugin, ActivityAware {

    companion object {
        init { System.loadLibrary("nitro_zxing") }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // registerFactory: one impl per Dart-side instance (multi-instance
        // registry). The old single-instance register(impl, context) API no
        // longer exists on the generated JniBridge.
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Instance cleanup is driven by Dart's dispose() → the destroy_instance
        // C bridge call; the generated JniBridge has no engine-level teardown.
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        NitroZxingJniBridge.onActivityAttached(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        NitroZxingJniBridge.onActivityDetached()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        NitroZxingJniBridge.onActivityAttached(binding.activity)
    }

    override fun onDetachedFromActivity() {
        NitroZxingJniBridge.onActivityDetached()
    }
}