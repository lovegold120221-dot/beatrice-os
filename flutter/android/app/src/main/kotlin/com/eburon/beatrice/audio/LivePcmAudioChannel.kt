package com.eburon.beatrice.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class LivePcmAudioChannel(flutterEngine: FlutterEngine) {
    companion object {
        const val NAME = "com.eburon.beatrice/live_pcm_v1"
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAME)
    private val executor = Executors.newSingleThreadExecutor()
    private var track: AudioTrack? = null
    private var sampleRate = 0

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "write" -> {
                    val data = call.argument<ByteArray>("data")
                    val rate = call.argument<Int>("sampleRate") ?: 24000
                    if (data == null || data.isEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    executor.execute { write(data, rate) }
                    result.success(null)
                }
                "stop" -> {
                    executor.execute { releaseTrack() }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun write(data: ByteArray, rate: Int) {
        if (track == null || sampleRate != rate) {
            releaseTrack()
            sampleRate = rate
            val minimum = AudioTrack.getMinBufferSize(
                rate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
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
                .setBufferSizeInBytes(maxOf(minimum, rate / 2))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
                .also { it.play() }
        }
        track?.write(data, 0, data.size, AudioTrack.WRITE_BLOCKING)
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
