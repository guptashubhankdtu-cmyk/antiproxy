import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  static const _espChannel = MethodChannel('com.antiproxy/esp_scan');
  bool _isScanning = false;
  final Map<String, _Device> _devices = {};

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied = statuses.entries
        .where((e) => e.value.isDenied || e.value.isPermanentlyDenied)
        .toList();
    if (denied.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth permissions are required to scan nearby devices.'),
        ),
      );
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    setState(() {
      _devices.clear();
      _isScanning = true;
    });

    try {
      final result = await _espChannel.invokeMethod<List<dynamic>>('scanDevices');
      final parsed = (result ?? [])
          .whereType<Map>()
          .map((raw) {
            final data = Map<String, dynamic>.from(raw);
            return _Device(
              address: data['address'] as String? ?? 'unknown',
              name: data['name'] as String? ?? 'Unknown Device',
              rssi: (data['rssi'] as num?)?.toInt() ?? 0,
            );
          })
          .toList();

      parsed.sort((a, b) => b.rssi.compareTo(a.rssi));
      if (mounted) {
        setState(() {
          _devices
            ..clear()
            ..addEntries(parsed.map((d) => MapEntry(d.address, d)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ESP scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceList = _devices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Devices (Bluetooth)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: _isScanning
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isScanning ? 'Scanning...' : 'Scan Nearby'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Devices found: ${deviceList.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (!_isScanning)
                  TextButton.icon(
                    onPressed: _devices.isEmpty ? null : () => setState(_devices.clear),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: deviceList.isEmpty
                ? const Center(
                    child: Text('No devices found yet. Tap Scan to search.'),
                  )
                : ListView.separated(
                    itemCount: deviceList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = deviceList[index];
                      final name = r.name.isNotEmpty ? r.name : 'Unknown Device';
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(name),
                        subtitle: Text(r.address),
                        trailing: Text('${r.rssi} dBm'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Device {
  const _Device({
    required this.address,
    required this.name,
    required this.rssi,
  });

  final String address;
  final String name;
  final int rssi;
}
