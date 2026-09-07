package com.agilebiz.denizen_ai

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import com.write4me.llama_flutter_android.LlamaFlutterAndroidPlugin

/**
 * DenizenAiPlugin
 * 
 * Central on-device multimodal AI and vector search plugin for Flutter.
 * Bridges sqlite-vec C extensions and llama.cpp native inference.
 */
class DenizenAiPlugin : FlutterPlugin {
    private val llamaPlugin = LlamaFlutterAndroidPlugin()

    companion object {
        init {
            try {
                System.loadLibrary("sqlite_vec")
            } catch (e: Throwable) {
                android.util.Log.w("DenizenAiPlugin", "Failed to load sqlite_vec: ${e.message}")
            }
        }
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        llamaPlugin.onAttachedToEngine(binding)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        llamaPlugin.onDetachedFromEngine(binding)
    }
}
