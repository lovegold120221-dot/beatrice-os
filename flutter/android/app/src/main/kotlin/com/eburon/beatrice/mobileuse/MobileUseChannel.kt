package com.eburon.beatrice.mobileuse

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.app.Activity
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.database.Cursor
import android.net.Uri
import android.provider.Settings
import android.provider.OpenableColumns
import android.view.accessibility.AccessibilityManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MobileUseChannel(
    private val context: Activity,
    flutterEngine: FlutterEngine,
) {
    companion object {
        const val NAME = "com.eburon.beatrice/mobile_use_v1"
        const val PICK_GGUF_REQUEST = 8614
        const val PREFS = "mobile_use_v1"
        const val OPTIONAL_PERMISSION_REQUEST = 8710

        @Volatile
        private var activeChannel: MethodChannel? = null

        fun notifyRuntimeStopped(reason: String) {
            activeChannel?.invokeMethod(
                "runtimeStopped",
                mapOf("reason" to reason),
            )
        }
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAME)
    private var pendingModelResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun register() {
        activeChannel = channel
        channel.setMethodCallHandler(::handle)
    }

    fun unregister() {
        channel.setMethodCallHandler(null)
        if (activeChannel === channel) activeChannel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(status())
            "requestOptionalPermission" -> requestOptionalPermission(call, result)
            "updateRuntimeTaskState" -> {
                if (!MobileUseRuntimeService.isRunning) {
                    result.success(false)
                    return
                }
                context.startService(
                    Intent(context, MobileUseRuntimeService::class.java).apply {
                        action = MobileUseRuntimeService.ACTION_UPDATE
                        putExtra("state", call.argument<String>("state") ?: "active")
                        putExtra("detail", call.argument<String>("detail") ?: "Task in progress")
                    },
                )
                result.success(true)
            }
            "selectLocalModel" -> selectLocalModel(result)
            "prepareLocalModel" -> prepareLocalModel(result)
            "removeLocalModel" -> {
                removeLocalModel()
                result.success(true)
            }
            "openAccessibilitySettings" -> {
                val component = ComponentName(context, MobileUseAccessibilityService::class.java)
                val detailsIntent = Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS")
                    .putExtra(
                        "android.provider.extra.EXTRA_ACCESSIBILITY_SERVICE_COMPONENT_NAME",
                        component.flattenToString(),
                    )
                try {
                    context.startActivity(detailsIntent)
                } catch (_: Exception) {
                    context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                }
                result.success(true)
            }
            "startRuntime" -> {
                if (!isAccessibilityEnabled()) {
                    result.error(
                        "ACCESSIBILITY_REQUIRED",
                        "Enable MobileUseAgent in Android Accessibility settings first",
                        null,
                    )
                    return
                }
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, MobileUseRuntimeService::class.java).apply {
                        action = MobileUseRuntimeService.ACTION_START
                    },
                )
                result.success(true)
            }
            "stopRuntime" -> {
                if (MobileUseRuntimeService.isRunning) {
                    context.startService(
                        Intent(context, MobileUseRuntimeService::class.java).apply {
                            action = MobileUseRuntimeService.ACTION_STOP
                        },
                    )
                }
                result.success(true)
            }
            "testRuntime" -> result.success(
                mapOf(
                    "ok" to (MobileUseRuntimeService.isRunning && isAccessibilityEnabled()),
                    "status" to status(),
                ),
            )
            "readScreen" -> result.success(
                MobileUseAccessibilityService.instance?.readVisibleControls(),
            )
            "clickText" -> result.success(
                MobileUseAccessibilityService.instance?.clickText(
                    call.argument<String>("text") ?: "",
                ) ?: false,
            )
            "setFocusedText" -> result.success(
                MobileUseAccessibilityService.instance?.setFocusedText(
                    call.argument<String>("text") ?: "",
                ) ?: false,
            )
            "tap" -> result.success(
                MobileUseAccessibilityService.instance?.tap(
                    call.argument<Number>("x")?.toFloat() ?: 0f,
                    call.argument<Number>("y")?.toFloat() ?: 0f,
                ) ?: false,
            )
            "swipe" -> result.success(
                MobileUseAccessibilityService.instance?.swipe(
                    call.argument<Number>("startX")?.toFloat() ?: 0f,
                    call.argument<Number>("startY")?.toFloat() ?: 0f,
                    call.argument<Number>("endX")?.toFloat() ?: 0f,
                    call.argument<Number>("endY")?.toFloat() ?: 0f,
                ) ?: false,
            )
            "back" -> result.success(
                MobileUseAccessibilityService.instance?.back() ?: false,
            )
            "home" -> result.success(
                MobileUseAccessibilityService.instance?.home() ?: false,
            )
            "launchApp" -> {
                val packageName = call.argument<String>("packageName") ?: ""
                result.success(
                    MobileUseAccessibilityService.instance?.launchApp(packageName) ?: false,
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun status(): Map<String, Any?> {
        val preferences = context.getSharedPreferences(
            "mobile_use_runtime",
            Context.MODE_PRIVATE,
        )
        val storedState = preferences.getString("state", "stopped") ?: "stopped"
        val interrupted = !MobileUseRuntimeService.isRunning &&
            storedState in setOf("starting", "active", "planning")
        return mapOf(
            "version" to 1,
            "runtimeRunning" to MobileUseRuntimeService.isRunning,
            "accessibilityEnabled" to isAccessibilityEnabled(),
            "accessibilityConnected" to (MobileUseAccessibilityService.instance != null),
            "localModel" to localModelMetadata(),
            "optionalPermissions" to optionalPermissionStates(),
            "runtimeTaskState" to if (interrupted) "interrupted" else storedState,
            "runtimeTaskDetail" to if (interrupted) {
                "Android stopped the app process before the task completed. Please retry."
            } else {
                preferences.getString("detail", "No task is running")
            },
        )
    }

    private fun optionalPermissionStates(): Map<String, Boolean> = mapOf(
        "microphone" to hasAllPermissions(arrayOf(Manifest.permission.RECORD_AUDIO)),
        "notifications" to (
            Build.VERSION.SDK_INT < 33 ||
                hasAllPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS))
            ),
        "contacts" to hasAllPermissions(arrayOf(Manifest.permission.READ_CONTACTS)),
        "phone" to hasAllPermissions(arrayOf(Manifest.permission.CALL_PHONE)),
        "sms" to hasAllPermissions(
            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.SEND_SMS),
        ),
    )

    private fun requestOptionalPermission(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_ACTIVE", "Another permission request is active", null)
            return
        }
        val key = call.argument<String>("permission") ?: ""
        val permissions = when (key) {
            "microphone" -> arrayOf(Manifest.permission.RECORD_AUDIO)
            "notifications" -> if (Build.VERSION.SDK_INT >= 33) {
                arrayOf(Manifest.permission.POST_NOTIFICATIONS)
            } else emptyArray()
            "contacts" -> arrayOf(Manifest.permission.READ_CONTACTS)
            "phone" -> arrayOf(Manifest.permission.CALL_PHONE)
            "sms" -> arrayOf(Manifest.permission.READ_SMS, Manifest.permission.SEND_SMS)
            else -> {
                result.error("UNKNOWN_PERMISSION", "Unknown optional permission: $key", null)
                return
            }
        }
        if (permissions.isEmpty() || hasAllPermissions(permissions)) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        context.requestPermissions(permissions, OPTIONAL_PERMISSION_REQUEST)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != OPTIONAL_PERMISSION_REQUEST) return false
        val pending = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        pending.success(
            grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED },
        )
        return true
    }

    private fun hasAllPermissions(permissions: Array<String>): Boolean =
        permissions.all {
            ContextCompat.checkSelfPermission(context, it) ==
                PackageManager.PERMISSION_GRANTED
        }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_GGUF_REQUEST) return false
        val pending = pendingModelResult ?: return true
        pendingModelResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return true
        }

        val uri = data.data!!
        val metadata = queryMetadata(uri)
        val name = metadata["name"] as? String ?: ""
        val size = metadata["size"] as? Long ?: 0L
        if (!name.lowercase().endsWith(".gguf") || size <= 0L) {
            pending.error(
                "INVALID_GGUF",
                "Choose a non-empty file whose name ends in .gguf",
                null,
            )
            return true
        }

        try {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (error: SecurityException) {
            pending.error(
                "URI_PERMISSION_FAILED",
                "Android did not grant durable read access: ${error.message}",
                null,
            )
            return true
        }

        copyModelToPrivateStorage(uri, name, size, pending)
        return true
    }

    private fun selectLocalModel(result: MethodChannel.Result) {
        if (pendingModelResult != null) {
            result.error("PICKER_ACTIVE", "A model picker is already open", null)
            return
        }
        pendingModelResult = result
        context.startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/octet-stream"
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                )
            },
            PICK_GGUF_REQUEST,
        )
    }

    private fun removeLocalModel() {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString("modelPath", null)?.let { File(it).delete() }
        prefs.getString("modelUri", null)?.let {
            try {
                context.contentResolver.releasePersistableUriPermission(
                    Uri.parse(it),
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // The grant may already have been revoked by Android or the provider.
            }
        }
        prefs.edit()
            .remove("modelUri")
            .remove("modelName")
            .remove("modelSize")
            .remove("modelPath")
            .apply()
    }

    private fun localModelMetadata(): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val uri = prefs.getString("modelUri", null)
        val path = prefs.getString("modelPath", null)
        val localFileReady = path != null && File(path).isFile
        return mapOf(
            "selected" to (uri != null || localFileReady),
            "name" to prefs.getString("modelName", null),
            "size" to prefs.getLong("modelSize", 0L),
            "uri" to uri,
            "path" to path,
            "localFileReady" to localFileReady,
            "runtimeReady" to false,
            "runtimeStatus" to if (localFileReady) "Ready to load offline" else "Local copy required",
        )
    }

    private fun prepareLocalModel(result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val path = prefs.getString("modelPath", null)
        if (path != null && File(path).isFile) {
            result.success(localModelMetadata())
            return
        }
        val uriValue = prefs.getString("modelUri", null)
        val name = prefs.getString("modelName", null)
        val size = prefs.getLong("modelSize", 0L)
        if (uriValue == null || name == null || size <= 0L) {
            result.error("MODEL_NOT_SELECTED", "Select a local GGUF model first", null)
            return
        }
        copyModelToPrivateStorage(Uri.parse(uriValue), name, size, result)
    }

    private fun copyModelToPrivateStorage(
        uri: Uri,
        name: String,
        expectedSize: Long,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                val modelDirectory = File(context.filesDir, "mobileuse_models")
                if (!modelDirectory.exists() && !modelDirectory.mkdirs()) {
                    throw IllegalStateException("Could not create private model storage")
                }
                if (modelDirectory.usableSpace < expectedSize + 64L * 1024L * 1024L) {
                    throw IllegalStateException(
                        "Not enough device storage to copy ${formatBytes(expectedSize)} GGUF",
                    )
                }
                val safeName = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val destination = File(modelDirectory, safeName)
                val temporary = File(modelDirectory, "$safeName.part")
                temporary.delete()
                context.contentResolver.openInputStream(uri)?.use { input ->
                    val header = ByteArray(4)
                    if (input.read(header) != 4 || !header.contentEquals(byteArrayOf(0x47, 0x47, 0x55, 0x46))) {
                        throw IllegalArgumentException("The selected file is not a valid GGUF file")
                    }
                    FileOutputStream(temporary).use { output ->
                        output.write(header)
                        input.copyTo(output, 1024 * 1024)
                        output.fd.sync()
                    }
                } ?: throw IllegalStateException("Android could not open the selected document")
                if (temporary.length() <= 4L) {
                    throw IllegalArgumentException("The selected GGUF file is empty")
                }
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val previousPath = prefs.getString("modelPath", null)
                if (destination.exists() && !destination.delete()) {
                    throw IllegalStateException("Could not replace the previous local model copy")
                }
                if (!temporary.renameTo(destination)) {
                    throw IllegalStateException("Could not finalize the private model copy")
                }
                prefs.edit()
                    .putString("modelUri", uri.toString())
                    .putString("modelName", name)
                    .putLong("modelSize", destination.length())
                    .putString("modelPath", destination.absolutePath)
                    .apply()
                if (previousPath != null && previousPath != destination.absolutePath) {
                    File(previousPath).delete()
                }
                context.runOnUiThread { result.success(localModelMetadata()) }
            } catch (error: Exception) {
                context.runOnUiThread {
                    result.error(
                        "MODEL_COPY_FAILED",
                        error.message ?: "Could not copy the GGUF into private app storage",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun formatBytes(bytes: Long): String =
        if (bytes >= 1024L * 1024L * 1024L) {
            String.format("%.1f GB", bytes.toDouble() / (1024L * 1024L * 1024L))
        } else {
            String.format("%.1f MB", bytes.toDouble() / (1024L * 1024L))
        }

    private fun queryMetadata(uri: Uri): Map<String, Any?> {
        var name: String? = null
        var size = 0L
        val cursor: Cursor? = context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = it.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0) name = it.getString(nameIndex)
                if (sizeIndex >= 0 && !it.isNull(sizeIndex)) size = it.getLong(sizeIndex)
            }
        }
        return mapOf("name" to name, "size" to size)
    }

    private fun isAccessibilityEnabled(): Boolean {
        val manager = context.getSystemService(AccessibilityManager::class.java)
        return manager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
        ).any {
            it.resolveInfo.serviceInfo.packageName == context.packageName &&
                it.resolveInfo.serviceInfo.name ==
                MobileUseAccessibilityService::class.java.name
        }
    }
}
