package com.agilebiz.denizen_ai

import android.app.ActivityManager
import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.write4me.llama_flutter_android.LlamaFlutterAndroidPlugin

/**
 * DenizenAiPlugin
 * 
 * Central on-device multimodal AI and vector search plugin for Flutter.
 * Bridges sqlite-vec C extensions, hardware telemetry, and llama.cpp native inference.
 */
class DenizenAiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private val llamaPlugin = LlamaFlutterAndroidPlugin()
    private var systemChannel: MethodChannel? = null
    private var applicationContext: Context? = null

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
        applicationContext = binding.applicationContext
        systemChannel = MethodChannel(binding.binaryMessenger, "com.agilebiz.denizen_ai/system")
        systemChannel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceTotalRam" -> {
                try {
                    val actManager = applicationContext?.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    if (actManager != null) {
                        actManager.getMemoryInfo(memInfo)
                        result.success(memInfo.totalMem)
                    } else {
                        // Default fallback: 4GB
                        result.success(4L * 1024 * 1024 * 1024)
                    }
                } catch (e: Exception) {
                    result.error("RAM_QUERY_ERROR", "Failed to query device RAM: ${e.message}", null)
                }
            }
            "isVisionSupported" -> {
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        systemChannel?.setMethodCallHandler(null)
        systemChannel = null
        applicationContext = null
        llamaPlugin.onDetachedFromEngine(binding)
    }
}
