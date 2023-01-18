package com.datadoghq.flutter

import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

class PerformanceTracker {
    var minInMs = Double.POSITIVE_INFINITY
        private set
    var maxInMs = 0.0
        private set
    var avgInMs = 0.0
        private set
    var samples = 0
        private set

    fun addSample(sampleInNs: Long) {
        val milliseconds = sampleInNs / TimeUnit.MILLISECONDS.toNanos(1).toDouble()
        minInMs = min(minInMs, milliseconds)
        maxInMs = max(maxInMs, milliseconds)
        avgInMs = (milliseconds + (samples * avgInMs)) / (samples + 1)
        samples += 1
    }
}
