// lib/features/face_scan/presentation/face_scan_screen.dart
// Live camera with ML Kit face detection, blink liveness, auto-capture
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

// ── Liveness state ────────────────────────────────────
enum _LivenessState { waitingFace, waitingBlink, blinkDetected, processing, result }

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});
  @override State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _camera;
  FaceDetector?     _detector;
  bool              _processingFrame = false;
  _LivenessState    _state = _LivenessState.waitingFace;
  String            _statusText = 'Position face inside the circle';
  Color             _ringColor  = Colors.white;

  // Blink tracking
  bool _eyesWereClosed = false;
  Timer? _blinkTimeoutTimer;

  // Result
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initDetector();
  }

  Future<void> _initDetector() async {
    _detector = FaceDetector(options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ));
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _camera = CameraController(front, ResolutionPreset.medium, enableAudio: false);
    await _camera!.initialize();
    if (mounted) {
      setState(() {});
      _camera!.startImageStream(_processFrame);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processingFrame || _state == _LivenessState.processing || _state == _LivenessState.result) return;
    _processingFrame = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final faces = await _detector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _updateStatus(_LivenessState.waitingFace, 'No face detected', Colors.red);
        _eyesWereClosed = false;
        _blinkTimeoutTimer?.cancel();
        return;
      }
      if (faces.length > 1) {
        _updateStatus(_LivenessState.waitingFace, 'Only one face please', Colors.red);
        return;
      }

      final face = faces.first;
      final inCircle = _isFaceInCircle(face);

      if (!inCircle) {
        _updateStatus(_LivenessState.waitingFace, 'Move face into the circle', Colors.orange);
        return;
      }

      // Face is in circle — request blink
      if (_state == _LivenessState.waitingFace) {
        _updateStatus(_LivenessState.waitingBlink, 'Blink your eyes to verify ✨', Colors.yellow);
        _startBlinkTimeout();
      }

      if (_state == _LivenessState.waitingBlink) {
        final leftOpen  = face.leftEyeOpenProbability  ?? 1.0;
        final rightOpen = face.rightEyeOpenProbability ?? 1.0;
        final eyesClosed = leftOpen < 0.3 && rightOpen < 0.3;
        final eyesOpen   = leftOpen > 0.7 && rightOpen > 0.7;

        if (eyesClosed) { _eyesWereClosed = true; }
        if (eyesOpen && _eyesWereClosed) {
          // Full blink cycle detected!
          _blinkTimeoutTimer?.cancel();
          _updateStatus(_LivenessState.blinkDetected, '✓ Verified!', AppColors.primary);
          await Future.delayed(300.ms);
          await _captureAndSend();
        }
      }
    } finally {
      _processingFrame = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    // Simplified: use first plane for grayscale
    try {
      final bytes = image.planes.first.bytes;
      final size  = Size(image.width.toDouble(), image.height.toDouble());
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (_) { return null; }
  }

  bool _isFaceInCircle(Face face) {
    final sz = MediaQuery.sizeOf(context);
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    final r  = sz.width * 0.35;

    final box  = face.boundingBox;
    final faceCx = box.left + box.width / 2;
    final faceCy = box.top  + box.height / 2;
    final dist = sqrt(pow(faceCx - cx, 2) + pow(faceCy - cy, 2));
    return dist < r && box.width > r * 0.8;
  }

  void _updateStatus(_LivenessState state, String text, Color color) {
    if (!mounted) return;
    setState(() { _state = state; _statusText = text; _ringColor = color; });
  }

  void _startBlinkTimeout() {
    _blinkTimeoutTimer?.cancel();
    _blinkTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (_state == _LivenessState.waitingBlink) {
        _eyesWereClosed = false;
        _updateStatus(_LivenessState.waitingFace, 'Please try again', Colors.red);
        Future.delayed(1.seconds, () {
          if (mounted && _state == _LivenessState.waitingFace) {
            setState(() => _statusText = 'Position face inside the circle');
          }
        });
      }
    });
  }

  Future<void> _captureAndSend() async {
    _updateStatus(_LivenessState.processing, 'Processing...', AppColors.primary);
    await _camera!.stopImageStream();

    try {
      final img = await _camera!.takePicture();
      final bytes = await img.readAsBytes();
      final b64 = base64Encode(bytes);

      // Get GPS
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      final res = await ApiClient.instance.post(ApiConstants.attendanceMarkMobile, data: {
        'image': b64,
        if (pos != null) 'latitude': pos.latitude,
        if (pos != null) 'longitude': pos.longitude,
      });

      if (mounted) setState(() {
        _result = Map<String, dynamic>.from(res as Map);
        _state = _LivenessState.result;
      });

      // Auto-dismiss after 3 seconds
      await Future.delayed(3.seconds);
      if (mounted) _resetScan();
    } catch (e) {
      if (mounted) setState(() {
        _result = {'status': 'Error', 'message': '$e'};
        _state = _LivenessState.result;
      });
      await Future.delayed(3.seconds);
      if (mounted) _resetScan();
    }
  }

  void _resetScan() {
    _eyesWereClosed = false;
    _result = null;
    setState(() {
      _state = _LivenessState.waitingFace;
      _statusText = 'Position face inside the circle';
      _ringColor = Colors.white;
    });
    _camera!.startImageStream(_processFrame);
  }

  @override
  void dispose() {
    _blinkTimeoutTimer?.cancel();
    _camera?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final sz = MediaQuery.sizeOf(context);
    final circleR = sz.width * 0.35;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          CameraPreview(_camera!),

          // Dark overlay outside circle
          CustomPaint(painter: _CircleOverlayPainter(sz, circleR)),

          // Circle ring
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  circleR * 2,
              height: circleR * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _ringColor, width: 4),
              ),
            ).animate(
              onPlay: _state == _LivenessState.blinkDetected ? (c) => c.repeat() : null,
            ).shimmer(color: AppColors.primary, duration: 600.ms),
          ),

          // Status text
          Positioned(
            bottom: 120,
            left: 0, right: 0,
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(_statusText, textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ringColor, fontSize: 16, fontWeight: FontWeight.w600,
                  shadows: [const Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ).animate().fadeIn(),
              if (_state == _LivenessState.waitingBlink)
                const Text('(eyes must fully close then open)',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),

          // Result overlay
          if (_state == _LivenessState.result && _result != null)
            _ResultOverlay(result: _result!)
              .animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),

          // Back button
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circle cutout overlay painter ────────────────────
class _CircleOverlayPainter extends CustomPainter {
  final Size size;
  final double radius;
  _CircleOverlayPainter(this.size, this.radius);

  @override
  void paint(Canvas canvas, Size _) {
    final paint = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_) => false;
}

// ── Result overlay card ───────────────────────────────
class _ResultOverlay extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultOverlay({required this.result});

  @override
  Widget build(BuildContext context) {
    final status = result['status'] as String? ?? 'Error';
    Color cardColor;
    IconData icon;
    String title;
    String subtitle = result['studentName'] as String? ?? '';
    String extra = '';

    switch (status) {
      case 'Present': case 'Late':
        cardColor = AppColors.present;
        icon = Icons.check_circle;
        title = status == 'Late' ? '⏰ Late' : '✅ Present';
        final streak = result['streak'] as int? ?? 0;
        final emotion = result['emotion'] as String? ?? '';
        extra = streak > 1 ? '🔥 $streak-day streak' : '';
        if (emotion.isNotEmpty) extra += '  ${_emojiFor(emotion)}';
        break;
      case 'Already Marked':
        cardColor = AppColors.warning;
        icon = Icons.check;
        title = 'Already Marked ✓';
        break;
      case 'Unknown':
        cardColor = AppColors.error;
        icon = Icons.help_outline;
        title = 'Unknown Face';
        subtitle = 'Student not enrolled';
        break;
      case 'Spoofing':
        cardColor = AppColors.error;
        icon = Icons.warning_amber;
        title = '⚠️ Liveness Failed';
        subtitle = 'Real face required';
        break;
      case 'OutOfZone':
        cardColor = AppColors.error;
        icon = Icons.location_off;
        title = '📍 Outside Allowed Area';
        subtitle = 'Move to department zone';
        break;
      default:
        cardColor = AppColors.error;
        icon = Icons.error_outline;
        title = 'Error';
        subtitle = result['message'] as String? ?? '';
    }

    return Positioned(
      bottom: 80, left: 24, right: 24,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: cardColor.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            if (extra.isNotEmpty) Text(extra, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
    );
  }

  String _emojiFor(String e) {
    switch (e.toUpperCase()) {
      case 'HAPPY': return '😊'; case 'CALM': return '😌'; case 'SAD': return '😔'; default: return '';
    }
  }
}
