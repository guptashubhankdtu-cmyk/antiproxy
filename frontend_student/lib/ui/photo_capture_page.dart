import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import '../services/student_data_service.dart';

class PhotoCapturePage extends StatefulWidget {
  final bool isRequired;
  final VoidCallback? onPhotoUploaded;
  
  const PhotoCapturePage({
    super.key,
    this.isRequired = false,
    this.onPhotoUploaded,
  });

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isFaceAligned = false;
  bool _isCapturing = false;
  bool _isUploading = false;
  bool _isProcessing = false;
  FaceDetector? _faceDetector;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: false,
        enableClassification: true,
        enableTracking: false,
        minFaceSize: 0.1,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
        }
        return;
      }

      // Use front camera
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isInitialized || _isCapturing || _isUploading || _isProcessing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = image;
        _isCapturing = false;
        _isProcessing = true;
      });

      // Process the captured image for face alignment
      await _processCapturedImage(image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
        setState(() {
          _isCapturing = false;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processCapturedImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector!.processImage(inputImage);

      final isAligned = _checkFaceAlignment(faces);

      if (mounted) {
        setState(() {
          _isFaceAligned = isAligned;
          _isProcessing = false;
        });

        if (isAligned) {
          // Face is aligned, proceed with upload
          await _uploadPhoto(imagePath);
        } else {
          // Face not aligned, show error and allow retry
          _showAlignmentError();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  bool _checkFaceAlignment(List<Face> faces) {
    if (faces.isEmpty) return false;

    final face = faces.first;
    final headEulerAngleY = face.headEulerAngleY ?? 0;
    final headEulerAngleX = face.headEulerAngleX ?? 0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0;

    // Check alignment criteria (same as Kotlin code)
    final yawOk = headEulerAngleY.abs() < 15;
    final pitchOk = headEulerAngleX.abs() < 15;
    final rollOk = headEulerAngleZ.abs() < 10;

    return yawOk && pitchOk && rollOk;
  }

  void _showAlignmentError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Face Not Aligned'),
        content: const Text(
          'Please ensure your face is:\n'
          '• Centered in the frame\n'
          '• Looking straight ahead\n'
          '• Well-lit\n'
          '• Not tilted',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _capturedImage = null;
                _isFaceAligned = false;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPhoto(String imagePath) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final studentService = context.read<StudentDataService>();
      await studentService.uploadPhoto(imagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Call callback if provided
        if (widget.onPhotoUploaded != null) {
          widget.onPhotoUploaded!();
        }
        
        // Navigate back after a short delay (only if not required)
        if (!widget.isRequired) {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          // If required, navigate back to home after callback
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isUploading = false;
          _capturedImage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isRequired,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isRequired ? 'Upload Your Photo (Required)' : 'Capture Photo'),
          automaticallyImplyLeading: !widget.isRequired,
        ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview
                SizedBox.expand(
                  child: CameraPreview(_cameraController!),
                ),

                // Face alignment indicator overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isFaceAligned ? Colors.green : Colors.red,
                        width: 4,
                      ),
                    ),
                  ),
                ),

                // Instructions
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Text(
                      _isProcessing
                          ? 'Processing...'
                          : _isUploading
                              ? 'Uploading...'
                              : widget.isRequired
                                  ? 'Please upload your photo to continue. Position your face within the circle and tap capture'
                                  : 'Position your face within the circle and tap capture',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Capture button
                if (!_isProcessing && !_isUploading)
                  Positioned(
                    bottom: 50,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _isCapturing ? null : _capturePhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: const CircleBorder(),
                        ),
                        child: _isCapturing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 32,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),

                // Processing indicator
                if (_isProcessing || _isUploading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
      ),
    );
  }
}
