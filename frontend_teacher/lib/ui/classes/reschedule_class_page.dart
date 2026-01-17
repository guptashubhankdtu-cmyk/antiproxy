import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/class_model.dart';
import '../../models/reschedule_model.dart';
import '../../services/http_data_service.dart';
import '../../utils/holiday_config.dart';

class RescheduleClassPage extends StatefulWidget {
  final ClassModel classModel;

  const RescheduleClassPage({
    super.key,
    required this.classModel,
  });

  @override
  State<RescheduleClassPage> createState() => _RescheduleClassPageState();
}

class _RescheduleClassPageState extends State<RescheduleClassPage> {
  DateTime? _originalDate;
  String? _originalStartTime; // Changed to String for immutable display
  String? _originalEndTime; // Changed to String for immutable display
  DateTime? _rescheduledDate;
  String? _rescheduledStartTime; // Changed to String for dropdown
  String? _rescheduledEndTime; // Changed to String for dropdown
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  // Time slots from 8:00 AM to 6:00 PM
  final List<String> _timeSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00'
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatTime(String time24) {
    final parts = time24.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];

    if (hour == 0) {
      return '12:$minute AM';
    } else if (hour < 12) {
      return '$hour:$minute AM';
    } else if (hour == 12) {
      return '12:$minute PM';
    } else {
      return '${hour - 12}:$minute PM';
    }
  }

  Future<void> _selectOriginalDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate:
          DateTime.now().add(const Duration(days: 365)), // Allow future dates
      selectableDayPredicate: (d) => !isPublicHoliday(d),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: const Color(0xFF2D2D2D),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1F1F1F),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _originalDate = picked;
        // Auto-fetch the time for this day
        _fetchOriginalTime(picked);
      });
    }
  }

  void _fetchOriginalTime(DateTime date) {
    // Get the day name from the date
    final dayName = DateFormat('EEEE').format(date);

    // Check if this day exists in the class schedule
    if (widget.classModel.schedule != null &&
        widget.classModel.schedule!.containsKey(dayName)) {
      final timeSlot = widget.classModel.schedule![dayName]!;
      final startTime = timeSlot['start'] ?? '';
      final endTime = timeSlot['end'] ?? '';

      if (startTime.isNotEmpty && endTime.isNotEmpty) {
        setState(() {
          _originalStartTime = startTime; // Store as string directly
          _originalEndTime = endTime; // Store as string directly
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No time slot found for this day'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No class scheduled on $dayName'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectRescheduledDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (d) => !isPublicHoliday(d),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: const Color(0xFF2D2D2D),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1F1F1F),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _rescheduledDate = picked;
      });
    }
  }

  Future<void> _saveReschedule() async {
    // Validate all fields
    if (_originalDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the original class date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_originalStartTime == null || _originalEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the original class time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_rescheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the rescheduled date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_rescheduledStartTime == null || _rescheduledEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the rescheduled time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final reschedule = RescheduleModel(
        classId: widget.classModel.docId!,
        originalDate: DateFormat('yyyy-MM-dd').format(_originalDate!),
        originalStartTime: _originalStartTime!,
        originalEndTime: _originalEndTime!,
        rescheduledDate: DateFormat('yyyy-MM-dd').format(_rescheduledDate!),
        rescheduledStartTime: _rescheduledStartTime!,
        rescheduledEndTime: _rescheduledEndTime!,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );

      await context.read<HttpDataService>().saveReschedule(reschedule);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Class rescheduled successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving reschedule: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reschedule Class',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${widget.classModel.name} | Code: ${widget.classModel.id} | Section: ${widget.classModel.section}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Original Class Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class to Reschedule',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Original Date
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectOriginalDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF3A3A3A)),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF2D2D2D),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 20, color: Color(0xFF9E9E9E)),
                            const SizedBox(width: 12),
                            Text(
                              _originalDate == null
                                  ? 'Select original date'
                                  : DateFormat('EEEE, MMMM d, yyyy')
                                      .format(_originalDate!),
                              style: TextStyle(
                                fontSize: 15,
                                color: _originalDate == null
                                    ? const Color(0xFF9E9E9E)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Original Time (Immutable - Auto-fetched)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D2D2D),
                                  border:
                                      Border.all(color: const Color(0xFF3A3A3A)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock,
                                        size: 16, color: Color(0xFF9E9E9E)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _originalStartTime == null
                                            ? '--:--'
                                            : _formatTime(_originalStartTime!),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: _originalStartTime == null
                                              ? const Color(0xFF9E9E9E)
                                              : Colors.white,
                                          fontWeight: _originalStartTime != null
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D2D2D),
                                  border:
                                      Border.all(color: const Color(0xFF3A3A3A)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock,
                                        size: 16, color: Color(0xFF9E9E9E)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _originalEndTime == null
                                            ? '--:--'
                                            : _formatTime(_originalEndTime!),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: _originalEndTime == null
                                              ? const Color(0xFF9E9E9E)
                                              : Colors.white,
                                          fontWeight: _originalEndTime != null
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Rescheduled Class Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rescheduled Class Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Rescheduled Date
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectRescheduledDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF3A3A3A)),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF2D2D2D),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 20, color: Color(0xFF9E9E9E)),
                            const SizedBox(width: 12),
                            Text(
                              _rescheduledDate == null
                                  ? 'Select rescheduled date'
                                  : DateFormat('EEEE, MMMM d, yyyy')
                                      .format(_rescheduledDate!),
                              style: TextStyle(
                                fontSize: 15,
                                color: _rescheduledDate == null
                                    ? const Color(0xFF9E9E9E)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rescheduled Time (Dropdown Selection)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _rescheduledStartTime,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                hint: const Text('Select time', style: TextStyle(color: Colors.grey)),
                                dropdownColor: const Color(0xFF2D2D2D),
                                style: const TextStyle(color: Colors.white),
                                items: _timeSlots.map((time) {
                                  return DropdownMenuItem(
                                    value: time,
                                    child: Text(_formatTime(time)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _rescheduledStartTime = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _rescheduledEndTime,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                hint: const Text('Select time', style: TextStyle(color: Colors.grey)),
                                dropdownColor: const Color(0xFF2D2D2D),
                                style: const TextStyle(color: Colors.white),
                                items: _timeSlots.map((time) {
                                  return DropdownMenuItem(
                                    value: time,
                                    child: Text(_formatTime(time)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _rescheduledEndTime = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Reason Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason (Optional)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter reason for rescheduling...',
                        hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveReschedule,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isLoading ? 'Saving...' : 'Save Reschedule'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
