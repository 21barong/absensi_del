// lib/services/camera_service.dart
import 'dart:io';
import 'package:camera/camera.dart';

class CameraService {
  final List<CameraDescription> _cameras;
  CameraController? _cameraController;
  bool _isInitialized = false;

  CameraService(this._cameras);

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;

  Future<void> initializeCamera() async {
    if (_cameras.isEmpty) {
      print('ERROR: No cameras available.');
      return;
    }
    final frontCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      _isInitialized = true;
    } on CameraException catch (e) {
      print('Camera initialization error: ${e.description}');
      _isInitialized = false;
    }
  }

  Future<File?> captureFrame() async {
    if (!_isInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isTakingPicture) {
      print('Camera not ready or busy for capture.');
      return null;
    }
    try {
      final XFile? file = await _cameraController!.takePicture();
      if (file != null) {
        return File(file.path);
      }
      return null;
    } on CameraException catch (e) {
      print('Error taking picture: ${e.description}');
      return null;
    }
  }

  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
  }
}
