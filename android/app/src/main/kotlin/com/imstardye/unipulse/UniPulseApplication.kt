package com.imstardye.unipulse

import android.app.Application
import android.content.Context
import com.imstardye.unipulse.common.GlobalState

class UniPulseApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
