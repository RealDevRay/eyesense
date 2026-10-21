package com.devray.eyesense

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Foreground, bounded, low-rate measurements. No location or runtime permissions. */
class DeviceSensors(context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler, SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val methods = MethodChannel(messenger, "eyesense/sensors")
    private val events = EventChannel(messenger, "eyesense/sensors/events")
    private val handler = Handler(Looper.getMainLooper())
    private val types = linkedMapOf(
        "accelerometer" to Sensor.TYPE_ACCELEROMETER,
        "gravity" to Sensor.TYPE_GRAVITY,
        "gyroscope" to Sensor.TYPE_GYROSCOPE,
        "light" to Sensor.TYPE_LIGHT,
        "proximity" to Sensor.TYPE_PROXIMITY,
    )
    private var foreground = false
    private var sink: EventChannel.EventSink? = null
    private var session: Any? = null
    private val lastSent = mutableMapOf<Int, Long>()
    private val registered = mutableSetOf<Int>()
    private val watchdog = Runnable { stop() }

    init {
        methods.setMethodCallHandler { call, result ->
            if (call.method == "capabilities") {
                result.success(mapOf("sensors" to capabilities()))
            } else {
                result.notImplemented()
            }
        }
        events.setStreamHandler(this)
    }

    private fun sensor(type: Int): Sensor? = try {
        manager?.getDefaultSensor(type)
    } catch (_: RuntimeException) {
        null
    }

    private fun capabilities(): Map<String, String> = types.mapValues { (_, type) ->
        when {
            manager == null -> "unavailable"
            sensor(type) == null -> "missing"
            else -> "available"
        }
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        stop()
        if (!foreground) {
            eventSink.error("paused", "Sensor checks require the foreground activity.", null)
            eventSink.endOfStream()
            return
        }
        sink = eventSink
        session = (arguments as? Map<*, *>)?.get("session")
        val states = types.mapValues { (_, type) ->
            val deviceSensor = sensor(type)
            when {
                manager == null -> "unavailable"
                deviceSensor == null -> "missing"
                else -> {
                    val success = try {
                        // 10 Hz request; delivery is further throttled to 5 Hz.
                        manager.registerListener(this, deviceSensor, 100_000, handler)
                    } catch (_: RuntimeException) {
                        false
                    }
                    if (success) {
                        registered.add(type)
                        "available"
                    } else {
                        "unavailable"
                    }
                }
            }
        }
        try {
            eventSink.success(mapOf("session" to session, "sensors" to states))
            if (registered.isEmpty()) {
                stop()
            } else {
                // Independent fail-safe if Dart cancels late or loses its engine.
                handler.postDelayed(watchdog, 900)
            }
        } catch (_: RuntimeException) {
            stop()
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        val output = sink ?: return
        if (!foreground || event.sensor.type !in registered) return
        // Unreliable samples must not generate confident guidance.
        if (event.sensor.type != Sensor.TYPE_LIGHT &&
            event.sensor.type != Sensor.TYPE_PROXIMITY &&
            event.accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE
        ) return
        val now = SystemClock.elapsedRealtimeNanos()
        val last = lastSent[event.sensor.type]
        if (last != null && now - last < 200_000_000L) return
        if (event.timestamp <= 0 || event.timestamp > now) return
        val name = types.entries.firstOrNull { it.value == event.sensor.type }?.key ?: return
        val message = mutableMapOf<String, Any?>(
            "session" to session,
            "sensor" to name,
            // Android SensorEvent timestamps use the same monotonic time base.
            "ageMillis" to (now - event.timestamp) / 1_000_000.0,
        )
        if (event.sensor.type == Sensor.TYPE_PROXIMITY) {
            val value = event.values.firstOrNull() ?: return
            val maximum = event.sensor.maximumRange
            if (!value.isFinite() || value < 0 || !maximum.isFinite() || maximum <= 0) return
            // Usually front/top-mounted. Never export these values as rear-camera
            // object distance; a near report means only this sensor may be covered.
            message["covered"] = value < maximum && value < minOf(5f, maximum)
        } else {
            val count = if (event.sensor.type == Sensor.TYPE_LIGHT) 1 else 3
            if (event.values.size < count) return
            val values = event.values.take(count)
            if (values.any { !it.isFinite() }) return
            message["values"] = values.map { it.toDouble() }
        }
        lastSent[event.sensor.type] = now
        try {
            output.success(message)
        } catch (_: RuntimeException) {
            stop()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onCancel(arguments: Any?) {
        stop()
    }

    fun resume() {
        foreground = true
        // Never restart sampling automatically after a lifecycle transition.
    }

    fun pause() {
        foreground = false
        try {
            sink?.error("paused", "Sensor check stopped when the activity paused.", null)
        } catch (_: RuntimeException) {
            // The engine may already be detached.
        } finally {
            stop()
        }
    }

    private fun stop() {
        handler.removeCallbacks(watchdog)
        try {
            manager?.unregisterListener(this)
        } catch (_: RuntimeException) {
            // Continue releasing channel state even if the system service fails.
        } finally {
            registered.clear()
            lastSent.clear()
            val previous = sink
            sink = null
            session = null
            try {
                previous?.endOfStream()
            } catch (_: RuntimeException) {
                // The engine may already be detached.
            }
        }
    }

    fun detach() {
        pause()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
