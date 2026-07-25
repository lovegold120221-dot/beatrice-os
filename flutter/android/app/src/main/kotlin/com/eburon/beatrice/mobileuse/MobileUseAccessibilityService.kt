package com.eburon.beatrice.mobileuse

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.content.Intent
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class MobileUseAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        var instance: MobileUseAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    fun readVisibleControls(): Map<String, Any?>? {
        val root = rootInActiveWindow ?: return null
        if (root.packageName?.toString() == packageName) return null
        val controls = mutableListOf<Map<String, Any?>>()
        collectControls(root, controls, 0)
        return mapOf(
            "packageName" to root.packageName?.toString(),
            "controls" to controls,
        )
    }

    fun clickText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        if (root.packageName?.toString() == packageName) return false
        return root.findAccessibilityNodeInfosByText(text)
            .firstOrNull { it.isVisibleToUser }
            ?.let(::performSemanticClick) ?: false
    }

    fun setFocusedText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        if (root.packageName?.toString() == packageName) return false
        val target = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        if (!target.isEditable) return false
        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text,
            )
        }
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun tap(x: Float, y: Float): Boolean {
        val path = Path().apply { moveTo(x, y) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    fun swipe(startX: Float, startY: Float, endX: Float, endY: Float): Boolean {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    fun back(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)

    fun home(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)

    fun launchApp(packageName: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ?: return false
        return try {
            startActivity(launchIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun collectControls(
        node: AccessibilityNodeInfo,
        output: MutableList<Map<String, Any?>>,
        depth: Int,
    ) {
        if (depth > 12 || output.size >= 200) return
        if (
            node.isVisibleToUser &&
            (node.isClickable || node.isEditable || node.text != null ||
                node.contentDescription != null)
        ) {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            output.add(
                mapOf(
                    "text" to node.text?.toString(),
                    "description" to node.contentDescription?.toString(),
                    "viewId" to node.viewIdResourceName,
                    "clickable" to node.isClickable,
                    "editable" to node.isEditable,
                    "bounds" to listOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
                ),
            )
        }
        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { child ->
                collectControls(child, output, depth + 1)
                child.recycle()
            }
        }
    }

    private fun performSemanticClick(node: AccessibilityNodeInfo): Boolean {
        var current: AccessibilityNodeInfo? = node
        while (current != null) {
            if (current.isClickable) {
                return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            current = current.parent
        }
        return false
    }
}
