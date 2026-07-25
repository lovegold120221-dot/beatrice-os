package com.eburon.beatrice.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

class LivePcmAudioChannel(flutterEngine: FlutterEngine) {
    companion object {
        const val NAME = "com.eburon.beatrice/live_pcm_v1"
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAME)
    private val executor = ThreadPoolExecutor(
        1,
        1,
        0L,
        TimeUnit.MILLISECONDS,
        LinkedBlockingQueue<Runnable>(),
    )
    private val playbackGeneration = AtomicLong(0)
    private var track: AudioTrack? = null
    private var sampleRate = 0

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> {
                    val rate = call.argument<Int>("sampleRate") ?: 24000
                    val generation = playbackGeneration.get()
                    executor.execute {
                        if (generation == playbackGeneration.get()) ensureTrack(rate)
                    }
                    result.success(null)
                }
                "write" -> {
                    val data = call.argument<ByteArray>("data")
                    val rate = call.argument<Int>("sampleRate") ?: 24000
                    if (data == null || data.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val generation = playbackGeneration.get()
                    executor.execute {
                        if (generation == playbackGeneration.get()) write(data, rate)
                    }
                    result.success(null)
                }
                "stop" -> {
                    playbackGeneration.incrementAndGet()
                    executor.queue.clear()
                    executor.execute { releaseTrack() }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun write(data: ByteArray, rate: Int) {
        ensureTrack(rate)?.write(data, 0, data.size, AudioTrack.WRITE_BLOCKING)
    }

    private fun ensureTrack(rate: Int): AudioTrack? {
        if (track != null && sampleRate == rate) return track
        releaseTrack()
        sampleRate = rate
        val minimum = AudioTrack.getMinBufferSize(
            rate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(0)
        // PCM16 mono uses two bytes per sample. rate / 5 is about 100 ms,
        // which limits queued speech while retaining enough headroom for
        // normal mobile-network jitter.
        val targetBufferBytes = maxOf(minimum, rate / 5)
        track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(rate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(targetBufferBytes)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build()
            .also { audioTrack ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val minimumFrames = maxOf(1, minimum / 2)
                    audioTrack.setStartThresholdInFrames(
                        minOf(audioTrack.bufferCapacityInFrames, minimumFrames),
                    )
                }
                audioTrack.play()
            }
        return track
    }

    private fun releaseTrack() {
        try {
            track?.pause()
            track?.flush()
            track?.stop()
        } catch (_: Exception) {
        }
        track?.release()
        track = null
        sampleRate = 0
    }
}
