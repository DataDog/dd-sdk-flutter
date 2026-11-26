/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import com.datadog.android.api.context.DatadogContext
import java.util.concurrent.Callable
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executor
import java.util.concurrent.FutureTask
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicReference

/**
 * Reads the Datadog context with a bounded wait, for callers on the Flutter UI thread.
 *
 * The SDK's context read waits for the SDK's single context thread, which also processes
 * RUM events in order. When that thread is backed up, an unbounded wait from the UI thread
 * can exceed the ANR threshold. This reader runs the read on a background thread and waits
 * at most [timeoutMs] for it. If the read has not finished by then, it returns the last
 * context it read, or `null` if no read has finished yet.
 *
 * Only one read runs at a time. Callers that arrive while a read is in progress wait on
 * that same read. Once a read has timed out, later callers return the last known context
 * without waiting until that read finishes, so a stalled read costs at most one wait.
 */
internal class CoreContextReader(
    private val timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    private val executor: Executor = createReaderExecutor(),
    private val readContext: () -> DatadogContext?
) {
    private val inFlightRead = AtomicReference<FutureTask<DatadogContext?>?>(null)

    @Volatile
    private var lastKnownContext: DatadogContext? = null

    @Volatile
    private var timedOutRead: FutureTask<DatadogContext?>? = null

    // Any failure to get a fresh context falls back to the last known one.
    @Suppress("SwallowedException")
    fun read(): DatadogContext? {
        val pendingRead = currentOrNewRead() ?: return lastKnownContext
        if (pendingRead === timedOutRead) return lastKnownContext
        return try {
            pendingRead.get(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: TimeoutException) {
            timedOutRead = pendingRead
            lastKnownContext
        } catch (e: ExecutionException) {
            lastKnownContext
        } catch (e: CancellationException) {
            lastKnownContext
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            lastKnownContext
        }
    }

    // A rejected read is reported as `null`, so the caller falls back to the last known context.
    @Suppress("SwallowedException")
    private fun currentOrNewRead(): FutureTask<DatadogContext?>? {
        while (true) {
            val existing = inFlightRead.get()
            if (existing != null && !existing.isDone) return existing

            val newRead = FutureTask(
                Callable {
                    readContext().also { lastKnownContext = it }
                }
            )
            if (inFlightRead.compareAndSet(existing, newRead)) {
                return try {
                    executor.execute(newRead)
                    newRead
                } catch (e: RejectedExecutionException) {
                    inFlightRead.compareAndSet(newRead, null)
                    null
                }
            }
        }
    }

    companion object {
        internal const val DEFAULT_TIMEOUT_MS = 100L
        private const val THREAD_NAME = "datadog-flutter-context-reader"
        private const val KEEP_ALIVE_SECONDS = 30L

        private fun createReaderExecutor(): Executor = ThreadPoolExecutor(
            1,
            1,
            KEEP_ALIVE_SECONDS,
            TimeUnit.SECONDS,
            LinkedBlockingQueue()
        ) { runnable ->
            Thread(runnable, THREAD_NAME).apply { isDaemon = true }
        }.apply { allowCoreThreadTimeOut(true) }
    }
}
