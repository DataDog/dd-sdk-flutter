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
import com.datadog.android.DatadogSite
import com.datadog.android.api.context.AccountInfo
import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.context.UserInfo
import com.datadog.android.api.feature.Feature
import com.datadog.android.privacy.TrackingConsent
import io.mockk.mockk
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
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

    // Stands in for the context with user and account removed.
    private val contextWithoutIdentity = mockk<DatadogContext>()
    private val withoutIdentity: (DatadogContext) -> DatadogContext = { contextWithoutIdentity }

    @AfterEach
    fun afterEach() {
        releaseRead.countDown()
        executor.shutdownNow()
    }

    private fun reader(
        timeoutMs: Long,
        executor: Executor = this.executor,
        readContext: () -> DatadogContext?
    ) = CoreContextReader(timeoutMs, executor, withoutIdentity, readContext)

    @Test
    fun `M return the full context W read() {read finishes in time}`() {
        // Given
        val context = mockk<DatadogContext>()
        val reader = reader(timeoutMs = 1_000) { context }

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(context)
    }

    @Test
    fun `M return null within the timeout W read() {read blocked, no earlier context}`() {
        // Given
        val reader = reader(timeoutMs = 50) {
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
    fun `M return the earlier context without identity W read() {later read blocked}`() {
        // Given
        val calls = AtomicInteger(0)
        val reader = reader(timeoutMs = 50) {
            if (calls.getAndIncrement() == 0) {
                mockk<DatadogContext>()
            } else {
                releaseRead.await()
                mockk<DatadogContext>()
            }
        }
        reader.read()

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(contextWithoutIdentity)
    }

    @Test
    fun `M return without waiting W read() {earlier read still in progress}`() {
        // Given
        val calls = AtomicInteger(0)
        val reader = reader(timeoutMs = 300) {
            if (calls.getAndIncrement() == 0) {
                mockk<DatadogContext>()
            } else {
                releaseRead.await()
                mockk<DatadogContext>()
            }
        }
        reader.read()
        reader.read()

        // When
        val startNs = System.nanoTime()
        val result = reader.read()
        val elapsedMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startNs)

        // Then
        assertThat(result).isSameAs(contextWithoutIdentity)
        assertThat(elapsedMs).isLessThan(150)
    }

    @Test
    fun `M start one read W read() called repeatedly {read blocked}`() {
        // Given
        val calls = AtomicInteger(0)
        val reader = reader(timeoutMs = 10) {
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
    fun `M return the full context W read() {blocked read finished}`() {
        // Given
        val context = mockk<DatadogContext>()
        val reader = reader(timeoutMs = 50) {
            releaseRead.await()
            context
        }
        reader.read()

        // When
        releaseRead.countDown()
        val deadlineNs = System.nanoTime() + TimeUnit.SECONDS.toNanos(1)
        var result = reader.read()
        while (result !== context && System.nanoTime() < deadlineNs) {
            Thread.sleep(10)
            result = reader.read()
        }

        // Then
        assertThat(result).isSameAs(context)
    }

    @Test
    fun `M return the earlier context without identity W read() {read throws}`() {
        // Given
        val calls = AtomicInteger(0)
        val reader = reader(timeoutMs = 1_000) {
            if (calls.getAndIncrement() == 0) mockk<DatadogContext>() else error("read failed")
        }
        reader.read()

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(contextWithoutIdentity)
    }

    @Test
    fun `M forget the earlier context W read() {SDK returns no context}`() {
        // Given
        val calls = AtomicInteger(0)
        val reader = reader(timeoutMs = 1_000) {
            if (calls.getAndIncrement() == 0) mockk<DatadogContext>() else null
        }
        reader.read()

        // When
        val result = reader.read()

        // Then
        assertThat(result).isNull()
    }

    @Test
    fun `M return the earlier context without identity W read() {executor rejects the read}`() {
        // Given
        var reject = false
        val reader = reader(
            timeoutMs = 1_000,
            executor = { runnable ->
                if (reject) throw RejectedExecutionException()
                runnable.run()
            }
        ) { mockk<DatadogContext>() }
        reader.read()
        reject = true

        // When
        val result = reader.read()

        // Then
        assertThat(result).isSameAs(contextWithoutIdentity)
    }

    @Test
    fun `M keep the RUM context and remove user and account W removeUserAndAccount()`() {
        // Given
        val rumContext = mapOf<String, Any?>("session_id" to "fake-session-id")
        val context = DatadogContext(
            site = DatadogSite.US1,
            clientToken = "fake-token",
            service = "fake-service",
            env = "fake-env",
            version = "1.0.0",
            versionCode = 1,
            variant = "",
            source = "flutter",
            sdkVersion = "1.0.0",
            time = mockk(),
            processInfo = mockk(),
            networkInfo = mockk(),
            deviceInfo = mockk(),
            userInfo = UserInfo(id = "fake-user-id"),
            accountInfo = AccountInfo(id = "fake-account-id"),
            trackingConsent = TrackingConsent.GRANTED,
            appBuildId = null,
            remoteConfigurationId = null,
            featuresContext = mapOf(Feature.RUM_FEATURE_NAME to rumContext)
        )

        // When
        val result = CoreContextReader.removeUserAndAccount(context)

        // Then
        assertThat(result.userInfo.id).isNull()
        assertThat(result.accountInfo).isNull()
        assertThat(result.featuresContext).isEqualTo(context.featuresContext)
    }
}
