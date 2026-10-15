package com.sejong.sejong_english

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** 배경음악·효과음 재생 (기존 앱과 같은 방식) */
class MainActivity : FlutterActivity() {
    private val channelName = "sejong_english/audio"
    private var bgmPlayer: MediaPlayer? = null
    private var soundPool: SoundPool? = null
    private val soundIds = LinkedHashMap<String, Int>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> { initSounds(); result.success(null) }
                    "playBgm" -> { playBgm(); result.success(null) }
                    "stopBgm" -> {
                        try { bgmPlayer?.pause() } catch (e: Exception) { e.printStackTrace() }
                        result.success(null)
                    }
                    "playEffect" -> {
                        val asset = call.argument<String>("asset") ?: ""
                        soundIds[asset]?.let { id ->
                            soundPool?.play(id, 1.0f, 1.0f, 1, 0, 1.0f)
                        }
                        result.success(null)
                    }
                    "dispose" -> { releaseAll(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initSounds() {
        if (soundPool != null) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(attrs).build()
        soundPool = pool
        try {
            for (name in listOf("good.mp3", "bad.mp3")) {
                assets.openFd("flutter_assets/assets/audio/$name").use { fd ->
                    soundIds[name] = pool.load(fd, 1)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playBgm() {
        try {
            val player = bgmPlayer
            if (player == null) {
                val fd = assets.openFd("flutter_assets/assets/audio/backmusic.mp3")
                val mp = MediaPlayer()
                mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                fd.close()
                mp.isLooping = true
                mp.setVolume(0.5f, 0.5f)
                mp.prepare()
                mp.start()
                bgmPlayer = mp
            } else if (!player.isPlaying) {
                player.start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseAll() {
        try {
            bgmPlayer?.release()
            bgmPlayer = null
            soundPool?.release()
            soundPool = null
            soundIds.clear()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        releaseAll()
        super.onDestroy()
    }
}
