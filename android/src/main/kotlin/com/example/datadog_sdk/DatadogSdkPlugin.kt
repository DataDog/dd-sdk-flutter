package com.example.datadog_sdk

import androidx.annotation.NonNull
import com.datadog.android.bridge.DdBridge
import com.datadog.android.bridge.DdSdkConfiguration

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

fun decodeDdSdkConfiguration(encoded: HashMap<String, Any?>): DdSdkConfiguration {
  @Suppress("UNCHECKED_CAST")
  return DdSdkConfiguration(
    clientToken = encoded["clientToken"] as String,
    env = encoded["env"] as String,
    applicationId = encoded["applicationId"] as String?,
    nativeCrashReportEnabled = encoded["nativeCrashReportEnabled"] as Boolean,
    sampleRate = encoded["sampleRate"] as Double?,
    site = encoded["site"] as String?,
    trackingConsent = encoded["trackingConsent"] as String?,
    additionalConfig = encoded["additionalConfig"] as Map<String, Any?>?
  )
}

/** DatadogSdkPlugin */
class DatadogSdkPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var binding: FlutterPlugin.FlutterPluginBinding;

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter")
    channel.setMethodCallHandler(this)

    binding = flutterPluginBinding
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "DdSdk.initialize" -> {
        val configuration = call.argument<HashMap<String, Any?>>("configuration")
          ?.let { decodeDdSdkConfiguration(it) }
        DdBridge.getDdSdk(binding.applicationContext).initialize(configuration!!)
      }
    }
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
