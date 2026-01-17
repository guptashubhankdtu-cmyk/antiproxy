import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../services/student_data_service.dart';
import '../models/class_model.dart';
import 'attendance_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  static const _espChannel = MethodChannel('com.antiproxy/esp_scan');

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataService = context.read<StudentDataService>();
      dataService.refreshGamification();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('My Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final dataService = context.read<StudentDataService>();
              await dataService.loadData();
              await dataService.refreshGamification(forceRefresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            tooltip: 'Scan for ESP32',
            onPressed: () => _scanForEsp32(context),
          ),
        ],
      ),
      body: Consumer<StudentDataService>(
        builder: (context, dataService, child) {
          if (dataService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (dataService.classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, size: 80, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  const Text(
                    'No Classes Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are not enrolled in any classes yet.\nContact your teacher to get enrolled.',
                    style: TextStyle(color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await dataService.loadData();
                      await dataService.refreshGamification(forceRefresh: true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await dataService.loadData();
              await dataService.refreshGamification(forceRefresh: true);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: dataService.classes
                  .map((classModel) =>
                      _buildClassCard(context, classModel, dataService))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _scanForEsp32(BuildContext context) async {
    final data = context.read<StudentDataService>();
    final enabledClasses =
        data.classes.where((c) => data.btEnabledFor(c.id)).toList();
    if (enabledClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No classes with BT check-in enabled'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanning for ESP32...')),
    );

    // Ensure Bluetooth is supported and permissions are granted
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth not supported on this device')),
        );
        return;
      }

      // Request permissions (Android 12+ requires BLUETOOTH_SCAN/CONNECT; older needs location)
      if (await Permission.bluetoothScan.request().isDenied &&
          await Permission.locationWhenInUse.request().isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth permissions denied')),
        );
        return;
      }
      await Permission.bluetoothConnect.request();
      await Permission.locationWhenInUse.request();

      // Ensure adapter is ON
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on Bluetooth to proceed')),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth permission/state error: $e')),
      );
      return;
    }

    // First try native classic scan (same channel as teacher app)
    bool found = await _scanClassic(context, enabledClasses, data);

    // If not found via classic, fallback to BLE scan (in case device advertises BLE)
    if (!found) {
      found = await _scanBle(context, enabledClasses, data);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(found
            ? 'ESP32 detected. Marked present (local)'
            : 'ESP32 not found'),
        backgroundColor: found ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<bool> _scanClassic(BuildContext context, List<ClassModel> enabledClasses,
      StudentDataService data) async {
    try {
      final result = await HomePage._espChannel
          .invokeMethod<List<dynamic>>('scanDevices'); // returns list of maps
      final devices = (result ?? [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();

      for (final d in devices) {
        final name = (d['name'] as String? ?? '').toLowerCase();
        final mac = (d['address'] as String? ?? '').toUpperCase();
        final macNoColon = mac.replaceAll(':', '');
        const targetMac = '5C:01:3B:73:EA:A6';
        final targetMacNoColon = targetMac.replaceAll(':', '');

        final hasNameMatch = name.contains('esp32');
        final hasMacMatch = mac == targetMac ||
            macNoColon == targetMacNoColon ||
            mac.contains(targetMacNoColon);

        if (hasNameMatch || hasMacMatch) {
          for (final cls in enabledClasses) {
            data.markBtPresent(cls.id);
          }
          return true;
        }
      }
    } catch (e) {
      // ignore errors; will fallback to BLE
    }
    return false;
  }

  Future<bool> _scanBle(BuildContext context, List<ClassModel> enabledClasses,
      StudentDataService data) async {
    final completer = Future.delayed(const Duration(seconds: 10));
    bool found = false;
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final advName = (r.advertisementData.advName ?? '').toLowerCase();
        final localName = (r.advertisementData.localName ?? '').toLowerCase();
        final devName = (r.device.platformName).toLowerCase();
        final macRaw = r.device.remoteId.str;
        final mac = macRaw.toUpperCase();
        final macNoColon = mac.replaceAll(':', '');
        final macLower = macRaw.toLowerCase().replaceAll(':', '');

        const targetMac = '5C:01:3B:73:EA:A6';
        final targetMacNoColon = targetMac.replaceAll(':', '');

        final hasNameMatch = advName.contains('esp32') ||
            localName.contains('esp32') ||
            devName.contains('esp32');
        final hasMacMatch = mac == targetMac ||
            macNoColon == targetMacNoColon ||
            mac.contains(targetMacNoColon) ||
            macLower.contains(targetMacNoColon.toLowerCase());

        if (hasNameMatch || hasMacMatch) {
          found = true;
          for (final cls in enabledClasses) {
            data.markBtPresent(cls.id);
          }
        }
      }
    });

    await completer;
    await FlutterBluePlus.stopScan();
    await sub.cancel();
    return found;
  }

  Widget _buildClassCard(
      BuildContext context, ClassModel classModel, StudentDataService data) {
    final btEnabled = data.btEnabledFor(classModel.id);
    final btPresent = data.btPresentFor(classModel.id);

    Color btDotColor() {
      if (btPresent) return Colors.green;
      if (btEnabled) return Colors.amber;
      return Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.grey[900],
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttendanceDetailPage(classModel: classModel),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classModel.code,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          classModel.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  // BT dot indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: btDotColor(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        btPresent
                            ? 'BT Present'
                            : btEnabled
                                ? 'BT Ready'
                                : 'BT Off',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.class_, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Section ${classModel.section}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  if (classModel.ltpPattern != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      classModel.ltpPattern!,
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      classModel.teacherName,
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
              if (classModel.schedule.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.grey[800]),
                const SizedBox(height: 8),
                Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: classModel.schedule.map((schedule) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${schedule.getDayName()}: ${schedule.startTime}-${schedule.endTime}',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
