package com.example.tg_answer

import io.flutter.embedding.android.FlutterActivity
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {
    override fun onDestroy() {
        super.onDestroy()
        exitProcess(0)
    }
}
