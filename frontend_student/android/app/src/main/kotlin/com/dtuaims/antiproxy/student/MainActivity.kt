package com.dtuaims.antiproxy.student

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.antiproxy/esp_scan"
    private val handler = Handler(Looper.getMainLooper())

    private var scanReceiver: BroadcastReceiver? = null
    private var pendingResult: MethodChannel.Result? = null
    private var isScanning = false
    private val foundDevices = linkedMapOf<String, Map<String, Any>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanDevices" -> startNativeScan(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startNativeScan(result: MethodChannel.Result) {
        if (isScanning) {
            result.error("BUSY", "Scan already in progress", null)
            return
        }

        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("NO_BT", "Bluetooth is unavailable or disabled", null)
            return
        }

        if (!hasScanPermission()) {
            result.error("NO_PERMISSION", "Bluetooth scan/connect permission missing", null)
            return
        }

        // Clean previous state
        stopScanInternal()
        foundDevices.clear()
        pendingResult = result
        isScanning = true

        // Listen for found devices (including RSSI)
        scanReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt()
                        val address = device?.address ?: return
                        val name = device.name ?: "Unknown Device"
                        // Preserve latest RSSI per device
                        foundDevices[address] = mapOf(
                            "address" to address,
                            "name" to name,
                            "rssi" to rssi
                        )
                    }

                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> finishScan()
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        registerReceiver(scanReceiver, filter)

        adapter.cancelDiscovery()
        val started = adapter.startDiscovery()
        if (!started) {
            stopScanInternal()
            result.error("SCAN_FAILED", "Failed to start discovery", null)
            return
        }

        // Auto-finish scan after a short window (e.g., 10 seconds)
        handler.postDelayed({ finishScan() }, 10_000)
    }

    private fun finishScan() {
        val result = pendingResult ?: return
        val devices = foundDevices.values.toList()
        stopScanInternal()
        result.success(devices)
    }

    private fun stopScanInternal() {
        if (isScanning) {
            BluetoothAdapter.getDefaultAdapter()?.cancelDiscovery()
        }
        scanReceiver?.let {
            runCatching { unregisterReceiver(it) }
        }
        scanReceiver = null
        isScanning = false
        handler.removeCallbacksAndMessages(null)
        pendingResult = null
        foundDevices.clear()
    }

    private fun hasScanPermission(): Boolean {
        val connectGranted = ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.BLUETOOTH_CONNECT
        ) == PackageManager.PERMISSION_GRANTED
        val scanGranted = ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.BLUETOOTH_SCAN
        ) == PackageManager.PERMISSION_GRANTED
        return connectGranted && scanGranted
    }

    override fun onDestroy() {
        stopScanInternal()
        super.onDestroy()
    }
}
