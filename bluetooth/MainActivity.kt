package com.example.myapplication

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.ActivityCompat
import java.util.*

class MainActivity : ComponentActivity() {

    private lateinit var bluetoothAdapter: BluetoothAdapter

    // UI State variables
    private val presentStudentsList = mutableStateListOf<String>()
    private val registeredMacAddresses = mutableSetOf<String>()
    private var statusMessage by mutableStateOf("Ready to take attendance")

    // Permission Request Handler
    private val requestPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { permissions ->
            // Optionally handle permission results here
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Initialize Bluetooth Adapter
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter

        // 2. Ask for permissions immediately
        requestPermissions()

        // 3. Register the Receiver (The Listener)
        val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
        registerReceiver(studentFoundReceiver, filter)

        setContent {
            Column(
                modifier = Modifier.fillMaxSize().padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Classroom Attendance",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 10.dp)
                )

                Text(
                    text = statusMessage,
                    fontSize = 14.sp,
                    color = Color.DarkGray,
                    modifier = Modifier.padding(bottom = 20.dp)
                )

                // THE BUTTON
                Button(
                    onClick = { startAutoAttendance() },
                    modifier = Modifier.fillMaxWidth().height(60.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4CAF50))
                ) {
                    Text("START SCANNING", fontSize = 18.sp)
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text(
                    text = "Devices Found (${presentStudentsList.size}):",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.align(Alignment.Start)
                )

                // LIST OF FOUND DEVICES
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 10.dp)
                        .background(Color(0xFFF0F0F0))
                ) {
                    items(presentStudentsList) { deviceString ->
                        Text(
                            text = deviceString,
                            modifier = Modifier
                                .padding(10.dp)
                                .fillMaxWidth(),
                            fontSize = 16.sp,
                            color = Color.Black
                        )
                        // Grey Divider Line
                        Spacer(modifier = Modifier.height(1.dp).fillMaxWidth().background(Color.Gray))
                    }
                }
            }
        }
    }

    private fun requestPermissions() {
        requestPermissionLauncher.launch(
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )
        )
    }

    @SuppressLint("MissingPermission")
    private fun startAutoAttendance() {
        // CHECK 1: Is Bluetooth Hardware On?
        if (!bluetoothAdapter.isEnabled) {
            statusMessage = "Error: Bluetooth is OFF"
            Toast.makeText(this, "Turn ON Bluetooth in Settings!", Toast.LENGTH_LONG).show()
            return
        }

        // RESET LISTS
        presentStudentsList.clear()
        registeredMacAddresses.clear()

        // CHECK 2: Stop any previous scan
        if (bluetoothAdapter.isDiscovering) {
            bluetoothAdapter.cancelDiscovery()
        }

        // CHECK 3: Start Scan and VERIFY it started
        val success = bluetoothAdapter.startDiscovery()

        if (success) {
            statusMessage = "Scanning... (Receiver Active)"
            Toast.makeText(this, "Success: Scanning Started!", Toast.LENGTH_SHORT).show()
        } else {
            statusMessage = "SCAN FAILED TO START"
            Toast.makeText(this, "ERROR: System blocked scan. Check GPS/Location!", Toast.LENGTH_LONG).show()
        }
    }

    // THE RECEIVER: Runs automatically when a device is found
    private val studentFoundReceiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context, intent: Intent) {
            val action: String? = intent.action
            if (BluetoothDevice.ACTION_FOUND == action) {
                // Get the device
                val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)

                val address = device?.address ?: "No Address"
                val name = device?.name ?: "Unknown Device" // Fallback if name is hidden

                // Add to list if not already added
                if (!registeredMacAddresses.contains(address)) {
                    registeredMacAddresses.add(address)

                    // Add nicely formatted string to the list
                    presentStudentsList.add("📱 $name\nID: $address")
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(studentFoundReceiver) } catch (e: Exception) {}
    }
}