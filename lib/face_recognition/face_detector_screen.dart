import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:stretching/score/score_history_screen.dart';
import 'package:stretching/score/score_persistence.dart';

class FaceDetectorScreen extends StatefulWidget {
  const FaceDetectorScreen({super.key});

  @override
  State<FaceDetectorScreen> createState() => _FaceDetectorScreenState();
}

class _FaceDetectorScreenState extends State<FaceDetectorScreen> {
  late List<CameraDescription> _cameras;
  CameraController? _controller;
  bool _isDetecting = false;
  FaceDetector? _faceDetector;

  String _faceInfo = 'No face detected';
  String _tiltDirection = '';
  String _lastTiltDirection = '';

  Timer? _timer;
  int _remainingTime = 10;
  int _turnCount = 0;
  bool _finished = false; // 종료 상태 플래그

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeFaceDetector();
    _startTimer();
  }

  /// ⏱️ 타이머 시작
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (_remainingTime > 0) {
        setState(() => _remainingTime--);
      } else {
        // 시간이 0초 도달
        if (_finished) return;
        _finished = true;

        await _stopDetection();

        if (mounted) {
          await _showCompletionDialog();
        }
      }

      // ✅ _finished 상태 확인
      if (_finished) {
        // 이미 종료되었으면 알림창 유지/중복 방지
        debugPrint('스트레칭 종료됨: Alert 표시 중');
      }
    });
  }

  /// 카메라 스트림 중지
  Future<void> _stopDetection() async {
    try {
      _timer?.cancel();
      _timer = null;
      _isDetecting = false;

      if (_controller != null &&
          _controller!.value.isInitialized &&
          _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    } catch (_) {
      // ignore
    }
  }

  /// 종료 알림창
  Future<void> _showCompletionDialog() async {
    final score = _turnCount * 10;
    await ScorePersistence.saveScore(score);

    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('스트레칭 종료'),
          content: Text('최종 점수: $score'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('기록 보기'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScoreHistoryScreen()),
                );
              },
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// 카메라 초기화
  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;

    await _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  /// 얼굴 탐지기 초기화
  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  /// 카메라 이미지 → 얼굴 탐지
  Future<void> _processCameraImage(CameraImage image) async {
    if (_finished) return; // 종료 후 탐지 중단
    if (_isDetecting) return;
    _isDetecting = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    final faces = await _faceDetector!.processImage(inputImage);

    if (faces.isNotEmpty) {
      final face = faces.first;
      final double? rotY = face.headEulerAngleY;
      final double? rotZ = face.headEulerAngleZ;

      String direction = '';
      if (rotY != null) {
        if (rotY < -30) {
          direction = '왼쪽';
        } else if (rotY > 30) {
          direction = '오른쪽';
        }
      }

      if (direction.isNotEmpty && direction != _lastTiltDirection) {
        if (_remainingTime > 0 && !_finished) {
          setState(() => _turnCount++);
        }
      }
      _lastTiltDirection = direction;

      setState(() {
        _faceInfo =
        'Y: ${rotY?.toStringAsFixed(2)}, Z: ${rotZ?.toStringAsFixed(2)}';
        _tiltDirection = direction;
      });
    } else {
      setState(() {
        _faceInfo = 'No face detected';
        _tiltDirection = '';
        _lastTiltDirection = '';
      });
    }

    _isDetecting = false;
  }

  /// 카메라 프레임 → MLKit 입력 이미지 변환
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow:
        image.planes.isNotEmpty ? image.planes.first.bytesPerRow : 0,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopDetection();
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  /// UI 빌드
  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final previewRatio = _controller!.value.aspectRatio;
    final score = _turnCount * 10;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Transform.scale(
            scale: 1 / (previewRatio * deviceRatio),
            alignment: Alignment.topCenter,
            child: CameraPreview(_controller!),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCard('Time', '$_remainingTime s'),
                      _buildInfoCard('Score', '$score'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_tiltDirection.isNotEmpty && _remainingTime > 0 && !_finished)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _tiltDirection,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _faceInfo,
                        style:
                        const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 정보 카드
  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}