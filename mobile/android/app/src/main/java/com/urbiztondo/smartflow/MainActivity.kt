package com.urbiztondo.smartflow

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.urbiztondo.smartflow.data.SessionStore
import com.urbiztondo.smartflow.ui.SmartflowRoot

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val sessionStore = SessionStore(applicationContext)
        setContent {
            SmartflowRoot(sessionStore)
        }
    }
}
