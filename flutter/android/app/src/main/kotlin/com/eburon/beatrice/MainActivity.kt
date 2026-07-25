package com.eburon.beatrice

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.eburon.beatrice.mobileuse.MobileUseChannel
import com.eburon.beatrice.ocr.OcrChannel
import com.eburon.beatrice.audio.LivePcmAudioChannel

class MainActivity : FlutterActivity() {
  private var mobileUseChannel: MobileUseChannel? = null
  private var ocrChannel: OcrChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    mobileUseChannel = MobileUseChannel(this, flutterEngine).also { it.register() }
    ocrChannel = OcrChannel(this, flutterEngine).also { it.register() }
    LivePcmAudioChannel(flutterEngine).register()
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "beatrice/termux")
      .setMethodCallHandler { call, result ->
        if (call.method != "startOpenCode") return@setMethodCallHandler result.notImplemented()
        val command = "proot-distro login ubuntu --shared-tmp -- bash -lc 'opencode serve --hostname 127.0.0.1 --port 4096'"
        val intent = Intent("com.termux.RUN_COMMAND").apply {
          setPackage("com.termux")
          putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
          putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-lc", command))
          putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
        }
        try {
          sendBroadcast(intent)
          result.success(true)
        } catch (error: Exception) {
          result.error("TERMUX_UNAVAILABLE", error.message, null)
        }
      }
  }

  @Deprecated("Deprecated in Android")
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    if (ocrChannel?.onActivityResult(requestCode, resultCode, data) == true) return
    if (mobileUseChannel?.onActivityResult(requestCode, resultCode, data) == true) return
    super.onActivityResult(requestCode, resultCode, data)
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ) {
    if (mobileUseChannel?.onRequestPermissionsResult(
        requestCode,
        permissions,
        grantResults,
      ) == true
    ) return
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
  }

  override fun onDestroy() {
    mobileUseChannel?.unregister()
    mobileUseChannel = null
    super.onDestroy()
  }
}
