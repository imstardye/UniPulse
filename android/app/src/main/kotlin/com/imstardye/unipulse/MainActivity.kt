package com.imstardye.unipulse

import com.imstardye.unipulse.plugins.AppPlugin
import com.imstardye.unipulse.plugins.BatteryPlugin
import com.imstardye.unipulse.plugins.LinkPlugin
import com.imstardye.unipulse.plugins.ServicePlugin
import com.imstardye.unipulse.plugins.TilePlugin
import com.imstardye.unipulse.plugins.WifiSsidPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(BatteryPlugin())
        flutterEngine.plugins.add(LinkPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(WifiSsidPlugin())
        ServiceState.attachFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        flutterEngine?.let(ServiceState::detachFlutterEngine)
        super.onDestroy()
    }
}
