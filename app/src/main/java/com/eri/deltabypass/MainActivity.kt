package com.eri.deltabypass

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.eri.deltabypass.ui.DeltaBypassTheme
import com.eri.deltabypass.ui.screen.App

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DeltaBypassTheme {
                App()
            }
        }
    }
}