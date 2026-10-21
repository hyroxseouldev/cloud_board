package com.sunmkim.cloudboard

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.SoundPool
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Short, bundled WAVs only. One retained decoder pool + one bounded audio queue. */
internal class AndroidCueAudio(private val context: Context, messenger: BinaryMessenger) {
    private val thread = HandlerThread("CloudBoardCue", Process.THREAD_PRIORITY_AUDIO).apply { start() }
    private val handler = Handler(thread.looper)
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "com.sunmkim.cloudboard/cue_audio")
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    private val pool = SoundPool.Builder().setMaxStreams(1).setAudioAttributes(attributes).build()
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val samples = mutableMapOf<String, Int>()
    private val durations = mutableMapOf<String, Long>()
    private data class Loading(val key: String, val file: File, val replies: MutableList<MethodChannel.Result>)
    private val loading = mutableMapOf<Int, Loading>()
    private var stream = 0
    private var playingOwner: String? = null
    private var playingTerminal = false
    private var playingCueId: String? = null
    private var focusBlocked = false
    private var releaseAt = 0L
    private val releaseFocus = Runnable { abandonFocus() }
    private var foreground = true
    private var focused = false
    private var disposed = false
    private var activeOwner: String? = null
    private val focusListener: AudioManager.OnAudioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { change ->
        handler.post {
            if (change == AudioManager.AUDIOFOCUS_GAIN) {
                focused = true
                focusBlocked = false
            } else if (focused) {
                focused = false
                focusBlocked = true
                queue.suspend()
            }
        }
    }
    private val focusRequest = if (Build.VERSION.SDK_INT >= 26) {
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener, handler).build()
    } else null
    private val queue: AudioCueQueue = AudioCueQueue(
        System::currentTimeMillis, SystemClock::uptimeMillis, SystemClock::elapsedRealtime,
        { task, at -> handler.postAtTime(task, at); Unit }, { handler.removeCallbacks(it) },
        { cue, due, late -> play(cue, due, late) }, { stopStream() },
        { cue, late -> Log.i(TAG, "dropLate cue=${cue.id.hashCode()} lateMs=$late") },
        { cue, due ->
            if (foreground && !focusBlocked && acquireFocus()) {
                releaseFocusAfter(due + (durations[cue.key] ?: 1500L) + 150)
            }
        },
    )

    init {
        pool.setOnLoadCompleteListener { _, id, status -> handler.post { loaded(id, status) } }
        channel.setMethodCallHandler { call, result -> handler.post { handle(call, result) } }
    }

    private fun reply(result: MethodChannel.Result, error: String? = null) {
        main.post { if (error == null) result.success(null) else result.error("audio_prepare", error, null) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) { reply(result, "Audio engine disposed"); return }
        try {
            when (call.method) {
                "prepare" -> { prepare(call, result); return }
                "activate" -> {
                    val owner = requireNotNull(call.argument<String>("owner"))
                    val preserve = playingTerminal && playingCueId == call.argument<String>("terminalCueId")
                    activeOwner = owner
                    queue.activate(owner, stopPlaying = !preserve)
                    if (preserve) playingOwner = owner
                }
                "replace" -> {
                    val owner = requireNotNull(call.argument<String>("owner"))
                    if (owner == activeOwner && foreground) {
                        val raw = call.argument<List<Map<String, Any>>>("cues") ?: emptyList()
                        require(raw.size <= 32)
                        val cues = raw.map { AudioCueQueue.Cue(
                            it["id"] as String, it["key"] as String,
                            (it["localDeadlineMs"] as Number).toLong()) }
                        require(cues.all { it.id.length <= 256 && samples.containsKey(it.key) })
                        queue.replace(owner, cues, (call.argument<Number>("volume") ?: 1).toFloat())
                    }
                }
                "immediate" -> {
                    val owner = requireNotNull(call.argument<String>("owner"))
                    if (owner == activeOwner && foreground) {
                        val raw = requireNotNull(call.argument<Map<String, Any>>("cue"))
                        val cue = AudioCueQueue.Cue(raw["id"] as String, raw["key"] as String,
                            (raw["localDeadlineMs"] as Number).toLong())
                        require(cue.id.length <= 256 && samples.containsKey(cue.key))
                        queue.immediate(owner, cue, (call.argument<Number>("volume") ?: 1).toFloat())
                    }
                }
                "cancel" -> {
                    val owner = requireNotNull(call.argument<String>("owner"))
                    val preserve = call.argument<Boolean>("preserveEnd") == true && playingTerminal
                    queue.cancel(owner, stopPlaying = !preserve)
                    if (!preserve && playingOwner == owner) stopStream()
                    if (activeOwner == owner) {
                        activeOwner = null
                        if (!preserve) abandonFocus()
                    }
                }
                // Provider disposal cancels audio; decoded resources remain owned
                // by this Activity until engine teardown (also safe on hot restart).
                "dispose" -> { activeOwner?.let { queue.cancel(it) }; activeOwner = null; stopStream(); abandonFocus() }
                else -> { main.post { result.notImplemented() }; return }
            }
            reply(result)
        } catch (error: Exception) {
            reply(result, error.message ?: "Audio request failed")
        }
    }

    private fun prepare(call: MethodCall, result: MethodChannel.Result) {
        val key = requireNotNull(call.argument<String>("key"))
        require(key.matches(Regex("[A-Za-z]+:(tick|start)")))
        if (samples.containsKey(key)) { reply(result); return }
        loading.values.firstOrNull { it.key == key }?.let { it.replies.add(result); return }
        require(samples.size + loading.size < 20)
        val wav = requireNotNull(call.argument<ByteArray>("wav"))
        require(wav.size in 44..1_048_576 && String(wav, 0, 4, Charsets.US_ASCII) == "RIFF" &&
            String(wav, 8, 4, Charsets.US_ASCII) == "WAVE")
        durations[key] = wavDurationMs(wav)
        val file = File.createTempFile("cloudboard-cue-", ".wav", context.cacheDir)
        try {
            file.writeBytes(wav)
            val id = pool.load(file.path, 1)
            require(id != 0) { "SoundPool load rejected" }
            loading[id] = Loading(key, file, mutableListOf(result))
            handler.postDelayed({ if (loading.containsKey(id)) loaded(id, -1) }, 9500)
        } catch (error: Exception) { file.delete(); throw error }
    }

    private fun loaded(id: Int, status: Int) {
        val entry = loading.remove(id) ?: return
        entry.file.delete()
        if (status == 0 && !disposed) {
            samples[entry.key] = id
            Log.i(TAG, "prepared key=${entry.key}")
            entry.replies.forEach { reply(it) }
        } else {
            pool.unload(id)
            entry.replies.forEach { reply(it, "SoundPool preparation failed ($status)") }
        }
    }

    private fun play(cue: AudioCueQueue.Cue, due: Long, late: Long) {
        if (!foreground || !focused || disposed) return
        val sample = samples[cue.key] ?: return
        stopStream()
        stream = pool.play(sample, queue.volume, queue.volume, 1, 0, 1f)
        playingOwner = activeOwner
        playingCueId = cue.id
        playingTerminal = cue.id.contains("/end/")
        releaseFocusAfter(SystemClock.uptimeMillis() + (durations[cue.key] ?: 1500L) + 100)
        // This is the native API invocation, NOT acoustic/speaker onset.
        Log.i(TAG, "nativePlay cue=${cue.id.hashCode()} key=${cue.key} dueUptimeMs=$due callUptimeMs=${SystemClock.uptimeMillis()} lateMs=$late accepted=${stream != 0}")
    }

    private fun stopStream() {
        if (stream != 0) pool.stop(stream)
        stream = 0
        playingOwner = null
        playingCueId = null
        playingTerminal = false
    }

    private fun releaseFocusAfter(at: Long) {
        releaseAt = maxOf(releaseAt, at)
        handler.removeCallbacks(releaseFocus)
        handler.postAtTime(releaseFocus, releaseAt)
    }

    private fun wavDurationMs(wav: ByteArray): Long {
        val bytes = ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN)
        var offset = 12
        var byteRate = 0L
        var dataSize = 0L
        while (offset + 8 <= wav.size) {
            val size = bytes.getInt(offset + 4).toLong() and 0xffffffffL
            if (size > wav.size - offset - 8) break
            val name = String(wav, offset, 4, Charsets.US_ASCII)
            if (name == "fmt " && size >= 16) byteRate = bytes.getInt(offset + 16).toLong()
            if (name == "data") dataSize += size
            offset += 8 + size.toInt() + (size.toInt() and 1)
        }
        require(byteRate > 0 && dataSize > 0) { "Invalid WAV duration" }
        return (dataSize * 1000 / byteRate).coerceIn(1, 3000)
    }

    @Suppress("DEPRECATION")
    private fun acquireFocus(): Boolean {
        if (focusBlocked) return false
        if (focused) return true
        focused = if (Build.VERSION.SDK_INT >= 26) {
            manager.requestAudioFocus(focusRequest!!) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else manager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return focused
    }

    @Suppress("DEPRECATION")
    private fun abandonFocus() {
        handler.removeCallbacks(releaseFocus)
        releaseAt = 0
        if (Build.VERSION.SDK_INT >= 26) manager.abandonAudioFocusRequest(focusRequest!!)
        else manager.abandonAudioFocus(focusListener)
        focused = false
    }

    fun setForeground(value: Boolean) { handler.post {
        if (value && !foreground) focusBlocked = false
        foreground = value
        if (!value) { queue.suspend(); abandonFocus() }
    } }

    fun close() {
        channel.setMethodCallHandler(null)
        handler.post {
            disposed = true
            queue.suspend()
            abandonFocus()
            loading.keys.toList().forEach { loaded(it, -1) }
            pool.release()
            samples.clear()
            thread.quitSafely()
        }
    }

    companion object { private const val TAG = "CloudBoardCue" }
}
