package com.imstardye.unipulse

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.core.content.pm.ShortcutManagerCompat
import com.imstardye.unipulse.common.GlobalState
import com.imstardye.unipulse.common.QuickAction
import com.imstardye.unipulse.common.action
import com.imstardye.unipulse.common.shortcutId
import kotlinx.coroutines.launch

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
        finish()
    }

    // A caller that repeats an action before this instance is gone reaches it here, not onCreate.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent) {
        val action = QuickAction.entries.firstOrNull {
            it.action == intent.action ||
                "com.follow.clash.action.${it.name}" == intent.action ||
                "com.follow.clash.dev.action.${it.name}" == intent.action
        } ?: return
        ShortcutManagerCompat.reportShortcutUsed(this, action.shortcutId)
        GlobalState.launch {
            when (action) {
                QuickAction.START -> ServiceState.handleStartAction()
                QuickAction.STOP -> ServiceState.handleStopAction()
                QuickAction.TOGGLE -> ServiceState.handleToggleAction()
            }
        }
    }
}
