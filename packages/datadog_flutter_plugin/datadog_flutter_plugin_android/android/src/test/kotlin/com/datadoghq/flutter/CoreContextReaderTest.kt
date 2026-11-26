/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isLessThan
import assertk.assertions.isNull
import assertk.assertions.isSameAs
import assertk.assertions.isTrue
import com.datadog.android.api.context.DatadogContext
import io.mockk.mockk
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test

class CoreContextReaderTest {
    private val executor = Executors.newSingleThreadExecutor()

    // Holds a read open until the test releases it, standing in for a backed-up context thread.
    private val releaseRead = CountDownLatch(1)

    @AfterEach
    fun afterEach() {
        releaseRead.countDown()
        executor.shutdownNow()
    }

    @Test
    fun `M return the context W read() {read finishes in time}`() {
        // Given
        val context = mockk<DatadogContext>()
        val reader = CoreContextReader(timeoutMs = 1_000, executor = executor) { context }

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(context)
    }

    @Test
    fun `M return null within the timeout W read() {read blocked, no earlier context}`() {
        // Given
        val reader = CoreContextReader(timeoutMs = 50, executor = executor) {
            releaseRead.await()
            mockk<DatadogContext>()
        }

        // When
        val startNs = System.nanoTime()
        val result = reader.read()
        val elapsedMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNs)

        // Then
        assertThat(result).isNull()
        assertThat(elapsedMs).isLessThan(1_000)
    }

    @Test
    fun `M return the last known context W read() {later read blocked}`() {
        // Given
        val firstContext = mockk<DatadogContext>()
        val calls = AtomicInteger(0)
        val reader = CoreContextReader(timeoutMs = 50, executor = executor) {
            if (calls.getAndIncrement() == 0) {
                firstContext
            } else {
                releaseRead.await()
                mockk<DatadogContext>()
            }
        }
        reader.read()

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(firstContext)
    }

    @Test
    fun `M start one read W read() called repeatedly {read blocked}`() {
        // Given
        val calls = AtomicInteger(0)
        val reader = CoreContextReader(timeoutMs = 10, executor = executor) {
            calls.incrementAndGet()
            releaseRead.await()
            mockk<DatadogContext>()
        }

        // When
        repeat(5) { reader.read() }

        // Then
        assertThat(calls.get()).isEqualTo(1)
    }

    @Test
    fun `M return the fresh context W read() {blocked read finished}`() {
        // Given
        val readFinished = CountDownLatch(1)
        val context = mockk<DatadogContext>()
        val reader = CoreContextReader(timeoutMs = 10, executor = executor) {
            releaseRead.await()
            context.also { readFinished.countDown() }
        }
        reader.read()

        // When
        releaseRead.countDown()
        assertThat(readFinished.await(1, TimeUnit.SECONDS)).isTrue()
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(context)
    }

    @Test
    fun `M return the last known context W read() {read throws}`() {
        // Given
        val firstContext = mockk<DatadogContext>()
        val calls = AtomicInteger(0)
        val reader = CoreContextReader(timeoutMs = 1_000, executor = executor) {
            if (calls.getAndIncrement() == 0) firstContext else error("read failed")
        }
        reader.read()

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(firstContext)
    }

    @Test
    fun `M forget the last known context W read() {SDK returns no context}`() {
        // Given
        val calls = AtomicInteger(0)
        val reader = CoreContextReader(timeoutMs = 1_000, executor = executor) {
            if (calls.getAndIncrement() == 0) mockk<DatadogContext>() else null
        }
        reader.read()

        // When
        val result = reader.read()

        // Then
        assertThat(result).isNull()
    }

    @Test
    fun `M return the last known context W read() {executor rejects the read}`() {
        // Given
        val context = mockk<DatadogContext>()
        var reject = false
        val reader = CoreContextReader(
            timeoutMs = 1_000,
            executor = { runnable ->
                if (reject) throw RejectedExecutionException()
                runnable.run()
            }
        ) { context }
        reader.read()
        reject = true

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(context)
    }
}
