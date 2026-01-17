import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/student_data_service.dart';
import '../models/class_model.dart';
import '../models/attendance_stats.dart';

class AttendanceDetailPage extends StatefulWidget {
  final ClassModel classModel;

  const AttendanceDetailPage({super.key, required this.classModel});

  @override
  State<AttendanceDetailPage> createState() => _AttendanceDetailPageState();
}

class _AttendanceDetailPageState extends State<AttendanceDetailPage> {
  AttendanceStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataService = context.read<StudentDataService>();
      final stats = await dataService.getAttendanceStats(widget.classModel.id);

      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classModel.code),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading attendance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_stats == null) {
      return const Center(
        child: Text('No data available'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClassInfo(),
            const SizedBox(height: 24),
            _buildOverallStats(),
            const SizedBox(height: 24),
            _buildPieChart(),
            const SizedBox(height: 24),
            _buildAttendanceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildClassInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.classModel.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  _stats!.studentName,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.badge, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  _stats!.rollNo,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStats() {
    final percentage = _stats!.percentage;
    final isGood = percentage >= 75.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isGood ? Icons.check_circle : Icons.warning,
                  color: isGood ? Colors.green : Colors.red,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Attendance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: isGood ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Present', _stats!.presentCount, Colors.green),
                _buildStatItem('Late', _stats!.lateCount, Colors.orange),
                _buildStatItem('Absent', _stats!.absentCount, Colors.red),
                _buildStatItem('Excused', _stats!.excusedCount, Colors.blue),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total Sessions: ${_stats!.totalCount}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    final total = _stats!.totalCount;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Attendance Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: [
                    if (_stats!.presentCount > 0)
                      PieChartSectionData(
                        value: _stats!.presentCount.toDouble(),
                        title:
                            '${(_stats!.presentCount / total * 100).toStringAsFixed(0)}%',
                        color: Colors.green,
                        radius: 75,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (_stats!.lateCount > 0)
                      PieChartSectionData(
                        value: _stats!.lateCount.toDouble(),
                        title:
                            '${(_stats!.lateCount / total * 100).toStringAsFixed(0)}%',
                        color: Colors.orange,
                        radius: 75,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (_stats!.absentCount > 0)
                      PieChartSectionData(
                        value: _stats!.absentCount.toDouble(),
                        title:
                            '${(_stats!.absentCount / total * 100).toStringAsFixed(0)}%',
                        color: Colors.red,
                        radius: 75,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (_stats!.excusedCount > 0)
                      PieChartSectionData(
                        value: _stats!.excusedCount.toDouble(),
                        title:
                            '${(_stats!.excusedCount / total * 100).toStringAsFixed(0)}%',
                        color: Colors.blue,
                        radius: 75,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem('Present', Colors.green),
                _buildLegendItem('Late', Colors.orange),
                _buildLegendItem('Absent', Colors.red),
                _buildLegendItem('Excused', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    if (_stats!.records.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.event_busy, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No attendance records yet',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stats!.records.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = _stats!.records[index];
              return _buildAttendanceRecordTile(record);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRecordTile(AttendanceRecord record) {
    final date = DateTime.parse(record.date);
    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final dayStr = DateFormat('EEEE').format(date);

    Color statusColor;
    IconData statusIcon;

    switch (record.status.toLowerCase()) {
      case 'present':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'excused':
        statusColor = Colors.blue;
        statusIcon = Icons.info;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Icon(statusIcon, color: statusColor, size: 24),
      ),
      title: Text(
        dateStr,
        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dayStr, style: TextStyle(color: Colors.grey[400])),
          if (record.recognizedByAi && record.similarityScore != null)
            Text(
              'AI Detected (${record.similarityScore!.toStringAsFixed(0)}% match)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
        ],
      ),
      trailing: Chip(
        label: Text(
          record.status.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        backgroundColor: statusColor.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
