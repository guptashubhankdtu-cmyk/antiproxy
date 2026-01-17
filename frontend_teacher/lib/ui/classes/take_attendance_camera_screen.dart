// lib/ui/classes/take_attendance_camera_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class TakeAttendanceCameraScreen extends StatefulWidget {
  const TakeAttendanceCameraScreen({super.key});

  @override
  State<TakeAttendanceCameraScreen> createState() =>
      _TakeAttendanceCameraScreenState();
}

class _TakeAttendanceCameraScreenState
    extends State<TakeAttendanceCameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras found.');
      }

      _controller = CameraController(
        _cameras!.first, // Use the first available camera
        ResolutionPreset.max,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;

      if (!(_controller?.value.isInitialized ?? false)) {
        throw Exception('Camera controller is not initialized');
      }

      final XFile picture = await _controller!.takePicture();

      // When a picture is taken, we return its path to the previous screen.
      if (mounted) Navigator.of(context).pop(picture.path);
    } catch (e) {
      debugPrint("Error taking picture: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Attendance Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _controller != null
                ? CameraPreview(_controller!)
                : const Center(child: Text('Camera not available.'));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
