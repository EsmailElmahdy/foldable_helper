package org.booktime.foldable_device

import android.app.Activity
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.ViewTreeObserver

import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowMetricsCalculator

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel

import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Android side of the `foldable_device` EventChannel.
 *
 * Posture comes from the hinge-angle sensor; hinge bounds/orientation from
 * WindowManager's FoldingFeature. Tracking runs only while Dart is listening
 * AND an activity is attached (it needs the activity's window and lifecycle).
 */
class FoldableDevicePlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler {

    private lateinit var channel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null

    /** Latest hinge angle: 0° = closed, 180° = flat. */
    private var hingeAngle: Float? = null

    /** Latest FoldingFeature — hinge bounds and orientation only. */
    private var latestFoldingFeature: FoldingFeature? = null

    private var layoutJob: Job? = null

    private val hingeAngleListener = object : SensorEventListener {
        // The angle can change without WindowInfoTracker emitting, so emit here too.
        override fun onSensorChanged(event: SensorEvent) {
            hingeAngle = event.values.firstOrNull()
            emitFoldableState()
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    /** Fires once Android finished laying out the window (fold/rotation included). */
    private val layoutListener = ViewTreeObserver.OnGlobalLayoutListener { emitFoldableState() }

    // ---- FlutterPlugin ----

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = EventChannel(binding.binaryMessenger, "foldable_device")
        channel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setStreamHandler(null)
    }

    // ---- ActivityAware ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        startTracking()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        stopTracking()
        activity = null
    }

    // ---- StreamHandler ----

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startTracking()
    }

    override fun onCancel(arguments: Any?) {
        stopTracking()
        eventSink = null
    }

    // ---- Tracking ----

    private fun startTracking() {
        val activity = activity ?: return
        if (eventSink == null || layoutJob != null) return

        val sensorManager = activity.getSystemService(Activity.SENSOR_SERVICE) as SensorManager
        sensorManager.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE)?.let {
            sensorManager.registerListener(hingeAngleListener, it, SensorManager.SENSOR_DELAY_NORMAL)
        }

        activity.window.decorView.viewTreeObserver.addOnGlobalLayoutListener(layoutListener)

        val owner = activity as? LifecycleOwner ?: return
        layoutJob = owner.lifecycleScope.launch {
            WindowInfoTracker.getOrCreate(activity)
                .windowLayoutInfo(activity)
                .collect { layoutInfo ->
                    latestFoldingFeature = layoutInfo.displayFeatures
                        .filterIsInstance<FoldingFeature>()
                        .firstOrNull()
                    emitFoldableState()
                }
        }
    }

    private fun stopTracking() {
        val activity = activity ?: return
        (activity.getSystemService(Activity.SENSOR_SERVICE) as SensorManager)
            .unregisterListener(hingeAngleListener)
        activity.window.decorView.viewTreeObserver.removeOnGlobalLayoutListener(layoutListener)
        layoutJob?.cancel()
        layoutJob = null
    }

    /**
     * 0° -> folded, >= 175° -> unfolded, anything between -> halfOpened.
     */
    private fun getStateFromAngle(angle: Float): String = when {
        angle <= 0f -> "folded"
        angle >= 175f -> "unfolded"
        else -> "halfOpened"
    }

    private fun emitFoldableState() {
        val activity = activity ?: return
        // No hinge sensor (non-foldable) -> nothing to report, same as before.
        val angle = hingeAngle ?: return

        val bounds = WindowMetricsCalculator.getOrCreate()
            .computeCurrentWindowMetrics(activity)
            .bounds
        val foldingFeature = latestFoldingFeature
        // Hinge bounds in logical pixels (like iOS points / Flutter's
        // coordinate space), not physical pixels.
        val density = activity.resources.displayMetrics.density

        eventSink?.success(
            mapOf(
                "state" to getStateFromAngle(angle),
                "isFoldableDevice" to activity.packageManager
                    .hasSystemFeature("android.hardware.sensor.hinge_angle"),
                // Logical pixels, window coordinates.
                "hingeLeft" to foldingFeature?.bounds?.left?.div(density),
                "hingeTop" to foldingFeature?.bounds?.top?.div(density),
                "hingeRight" to foldingFeature?.bounds?.right?.div(density),
                "hingeBottom" to foldingFeature?.bounds?.bottom?.div(density),
                // Hinge direction — NOT the same as landscape/portrait.
                "isVerticalHinge" to (foldingFeature?.orientation == FoldingFeature.Orientation.VERTICAL),
                // Same meaning as iOS ReservedRegion.isActive: the fold splits the window.
                "isFoldActive" to (foldingFeature?.isSeparating == true),
                "hingeAngle" to angle,
                "isLandscape" to (bounds.width() > bounds.height()),
            )
        )
    }
}
