// attendance_bluetooth.dart
// Flutter single-file example: scan BLE devices and mark attendance using RSSI
// Requires flutter_blue_plus: ^2.0.6 (or compatible)
// Android: add BLUETOOTH, BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION permissions

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Attendance (RSSI)',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AttendanceHome(),
    );
  }
}

class AttendanceHome extends StatefulWidget {
  const AttendanceHome({super.key});

  @override
  State<AttendanceHome> createState() => _AttendanceHomeState();
}

class _AttendanceHomeState extends State<AttendanceHome> {
  final FlutterBluePlus _ble = FlutterBluePlus.instance;
  StreamSubscription? _scanSub;
  final Map<DeviceIdentifier, ScanResult> _results = {};
  final Map<String, AttendanceRecord> _attendance = {};

  // Configure these thresholds as needed
  static const int presentRssiThreshold = -70; // RSSI >= this means "present"
  static const int nearRssiThreshold = -85; // RSSI between near and present = "near"
  static const Duration seenTimeout = Duration(seconds: 10);

  // Whitelist: map device id (MAC or device identifier string) to student name.
  // For production, replace this with a proper backend or enrolled device list.
  final Map<String, String> enrolled = {
    // Example: 'AA:BB:CC:DD:EE:FF': 'Alice',
    // On Android, device.id.id may be MAC or randomised depending on platform.
  };

  @override
  void initState() {
    super.initState();
    startScan();
    // Periodic cleanup and attendance evaluation
    Timer.periodic(const Duration(seconds: 3), (_) => _updateAttendance());
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  void startScan() async {
    // Ensure Bluetooth is on. For production, handle permission flows and states.
    await _ble.turnOn();

    // Stop previous subscription
    await _scanSub?.cancel();

    _scanSub = _ble.scan(
      scanMode: ScanMode.lowLatency,
      allowDuplicates: true,
    ).listen((scanResult) {
      setState(() {
        _results[scanResult.device.id] = scanResult;
      });

      // Update seen time and RSSI for attendance evaluation
      final id = scanResult.device.id.id;
      final rssi = scanResult.rssi;
      final now = DateTime.now();

      final rec = _attendance.putIfAbsent(id, () => AttendanceRecord(id: id, name: enrolled[id] ?? 'Unknown'));
      rec.update(rssi, now);

      // If device is enrolled and RSSI strong enough, mark present automatically
      if (enrolled.containsKey(id) && rssi >= presentRssiThreshold) {
        rec.markPresent(now);
      }
    }, onError: (err) {
      // scanning error
    });
  }

  void stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
  }

  void _updateAttendance() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _attendance.forEach((id, rec) {
      // If not seen recently, mark absent
      if (now.difference(rec.lastSeen) > seenTimeout) {
        rec.markAbsent();
      } else {
        // If seen and RSSI above threshold but not yet confirmed, we can mark present
        if (rec.rssi != null && rec.rssi! >= presentRssiThreshold && !rec.present) {
          rec.markPresent(rec.lastSeen);
        }
      }
    });

    // Optional: remove very old entries from _results map
    _results.removeWhere((key, value) => now.difference(value.advertisementData.timestamp ?? now) > const Duration(seconds: 30));

    setState(() {});
  }

  // Manual override: toggle attendance for a device id
  void _toggleManual(String id) {
    final rec = _attendance.putIfAbsent(id, () => AttendanceRecord(id: id, name: enrolled[id] ?? 'Unknown'));
    if (rec.present) {
      rec.markAbsent();
    } else {
      rec.markPresent(DateTime.now());
    }
    setState(() {});
  }

  // Export attendance summary as a simple CSV string
  String exportCsv() {
    final rows = <String>['id,name,present,firstSeen,lastSeen,rssi'];
    _attendance.forEach((id, rec) {
      rows.add('${rec.id},"${rec.name}",${rec.present},${rec.firstSeen?.toIso8601String() ?? ''},${rec.lastSeen.toIso8601String()},${rec.rssi ?? ''}');
    });
    return rows.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final devices = _results.values.toList();
    devices.sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Attendance (RSSI)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              setState(() {});
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'stop') stopScan();
              if (v == 'start') startScan();
              if (v == 'export') {
                final csv = exportCsv();
                // For demo, show CSV in dialog. Replace with file export.
                await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('CSV'), content: SingleChildScrollView(child: Text(csv)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'start', child: Text('Start Scan')),
              const PopupMenuItem(value: 'stop', child: Text('Stop Scan')),
              const PopupMenuItem(value: 'export', child: Text('Export CSV')),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: const [
                Text('Present threshold (RSSI) : -70'),
                SizedBox(width: 12),
                Text('Near threshold : -85'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, i) {
                final r = devices[i];
                final id = r.device.id.id;
                final rec = _attendance[id] ?? AttendanceRecord(id: id, name: enrolled[id] ?? 'Unknown');
                final status = rec.present ? 'Present' : (rec.rssi != null && rec.rssi! >= nearRssiThreshold ? 'Near' : 'Absent');

                return ListTile(
                  leading: CircleAvatar(child: Text((rec.name.isNotEmpty ? rec.name[0] : '?'))),
                  title: Text(r.device.name.isNotEmpty ? r.device.name : id),
                  subtitle: Text('id: $id\nRSSI: ${r.rssi} dBm\nStatus: $status'),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _toggleManual(id),
                        child: Text(rec.present ? 'Revoke' : 'Mark'),
                      ),
                      const SizedBox(height: 6),
                      Text(rec.lastSeen == DateTime.fromMillisecondsSinceEpoch(0) ? '' : '${rec.lastSeen.hour}:${rec.lastSeen.minute.toString().padLeft(2, '0')}')
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          SizedBox(
            height: 140,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enrolled (whitelist) - edit in code'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 60,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: enrolled.entries.map((e) => Chip(label: Text('${e.value}\n${e.key}'))).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () async {
                      final csv = exportCsv();
                      await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('CSV'), content: SingleChildScrollView(child: Text(csv)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
                    },
                    child: const Text('Show Attendance CSV'),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class AttendanceRecord {
  final String id;
  String name;
  bool present = false;
  int? rssi;
  DateTime firstSeen = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastSeen = DateTime.fromMillisecondsSinceEpoch(0);

  AttendanceRecord({required this.id, this.name = 'Unknown'});

  void update(int newRssi, DateTime seenTime) {
    rssi = newRssi;
    lastSeen = seenTime;
    firstSeen = firstSeen.millisecondsSinceEpoch == 0 ? seenTime : firstSeen;
  }

  void markPresent(DateTime when) {
    present = true;
    firstSeen = firstSeen.millisecondsSinceEpoch == 0 ? when : firstSeen;
    lastSeen = when;
  }

  void markAbsent() {
    present = false;
  }
}
