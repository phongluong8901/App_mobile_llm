package com.example.llm_app

import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.example.llm_app/tts"
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = tts?.setLanguage(Locale("vi", "VN"))
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale.US)
            }
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    runOnUiThread {
                        methodChannel?.invokeMethod("onTtsStart", utteranceId)
                    }
                }

                override fun onDone(utteranceId: String?) {
                    runOnUiThread {
                        methodChannel?.invokeMethod("onTtsDone", utteranceId)
                    }
                }

                override fun onError(utteranceId: String?) {
                    runOnUiThread {
                        methodChannel?.invokeMethod("onTtsError", utteranceId)
                    }
                }
            })
            ttsReady = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val rate = call.argument<Double>("rate")?.toFloat() ?: 1.0f
                    val pitch = call.argument<Double>("pitch")?.toFloat() ?: 1.0f
                    val utteranceId = call.argument<String>("utteranceId") ?: "utt_${System.currentTimeMillis()}"

                    if (ttsReady && text.isNotEmpty()) {
                        tts?.setSpeechRate(rate)
                        tts?.setPitch(pitch)
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stop" -> {
                    tts?.stop()
                    result.success(true)
                }
                "isReady" -> {
                    result.success(ttsReady)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
