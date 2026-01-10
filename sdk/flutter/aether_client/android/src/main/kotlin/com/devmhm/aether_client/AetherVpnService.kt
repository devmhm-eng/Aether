package com.devmhm.aether_client

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import mobile.Mobile

class AetherVpnService : VpnService() {

    private var interfaceFd: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "STOP") {
            stopVpn()
            return START_NOT_STICKY
        }

        val config = intent?.getStringExtra("config") ?: "{}"
        
        // 1. Build VPN Interface
        val builder = Builder()
        builder.setSession("AetherVPN")
        builder.addAddress("10.0.0.2", 32)
        builder.addRoute("0.0.0.0", 0)
        builder.setMtu(1500)

        // Exclude own app
        try {
            builder.addDisallowedApplication(packageName)
        } catch (e: Exception) {
            Log.e("AetherVPN", "Failed to exclude package: ${e.message}")
        }
        
        builder.addDnsServer("1.1.1.1")
        builder.addDnsServer("8.8.8.8")

        try {
            interfaceFd = builder.establish()
            if (interfaceFd != null) {
                val fd = interfaceFd!!.fd
                Log.i("AetherVPN", "VPN Established. FD: $fd")
                
                // 2. Pass FD and Config to Xray Core
                // We pass generic asset dir (filesDir) for logs/geo files
                val assetDir = filesDir.absolutePath

                Thread {
                    try {
                        // Go Bindings: StartVPN(fd int, config string, assetDir string)
                        // Maps to: Mobile.startVPN(long, String, String)
                        Mobile.startVPN(fd.toLong(), config, assetDir)
                    } catch (e: Exception) {
                        Log.e("AetherVPN", "Xray Core Error: ${e.message}")
                        stopSelf()
                    }
                }.start()
                
            } else {
                Log.e("AetherVPN", "Failed to establish VPN interface (null FD)")
                stopSelf()
            }
        } catch (e: Exception) {
            Log.e("AetherVPN", "Error starting VPN: ${e.message}")
            stopSelf()
        }

        return START_STICKY
    }

    private fun stopVpn() {
        try {
            Mobile.stopVPN()
            interfaceFd?.close()
            interfaceFd = null
            stopSelf()
        } catch (e: Exception) {
             Log.e("AetherVPN", "Error stopping: ${e.message}")
        }
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}
