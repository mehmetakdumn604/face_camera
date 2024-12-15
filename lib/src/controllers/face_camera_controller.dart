import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_camera/face_camera.dart';
import 'package:face_camera/src/handlers/enum_handler.dart';
import 'package:face_camera/src/handlers/face_identifier.dart';
import 'package:face_camera/src/utils/logger.dart';
import 'package:flutter/material.dart';

class FaceCameraController extends ChangeNotifier {
  CameraController? _controller;
  double _currentZoomLevel = 1.2;
  double _scaleFactor = 1.2;

  double get scaleFactor => _scaleFactor;

  set scaleFactor(double value) {
    if (value == _scaleFactor) return;
    _scaleFactor = value;
    notifyListeners();
  }

  void onScaleStart(details) {
    _currentZoomLevel = _scaleFactor;
    notifyListeners();
  }

  void onScaleUpdate(ScaleUpdateDetails details, CameraController? controller) {
    _scaleFactor = (_currentZoomLevel * details.scale).clamp(1.0, 3.0);

    notifyListeners();
    controller?.setZoomLevel(_scaleFactor);
    debugPrint('Gesture updated $_scaleFactor');
  }

  onTapZoomLevel(double zoomLevel, CameraController? controller) {
    _scaleFactor = zoomLevel;
    notifyListeners();
    controller?.setZoomLevel(_scaleFactor);
  }

  bool _alreadyCheckingImage = false;
  DetectedFace? _detectedFace;
  int _currentFlashMode = 0;
  final List<CameraFlashMode> _availableFlashMode = [CameraFlashMode.off, CameraFlashMode.auto, CameraFlashMode.always];
  int _currentCameraLens = 0;
  final List<CameraLens> _availableCameraLens = [];
  Timer? _timer;

  CameraController? get controller => _controller;
  DetectedFace? get detectedFace => _detectedFace;

  set detectedFace(DetectedFace? value) {
    _detectedFace = value;
    notifyListeners();
  }

  int get currentFlashMode => _currentFlashMode;
  List<CameraFlashMode> get availableFlashMode => _availableFlashMode;

  int get currentCameraLens => _currentCameraLens;

  set currentCameraLens(int value) {
    _currentCameraLens = value;
    notifyListeners();
  }

  List<CameraLens> get availableCameraLens => _availableCameraLens;

  void getAllAvailableCameraLens(List<CameraDescription> cameras, CameraLens? defaultCameraLens) {
    for (CameraDescription d in cameras) {
      final lens = EnumHandler.cameraLensDirectionToCameraLens(d.lensDirection);
      if (lens != null && !_availableCameraLens.contains(lens)) {
        _availableCameraLens.add(lens);
      }
    }

    if (defaultCameraLens != null) {
      try {
        _currentCameraLens = _availableCameraLens.indexOf(defaultCameraLens);
      } catch (e) {
        logError(e.toString());
      }
    }
  }

  Future<void> initCamera(List<CameraDescription> cameras, ImageResolution imageResolution, bool enableAudio, CameraOrientation? orientation, CameraFlashMode defaultFlashMode) async {
    final selectedCameras = cameras.where((c) => c.lensDirection == EnumHandler.cameraLensToCameraLensDirection(_availableCameraLens[_currentCameraLens])).toList();

    if (selectedCameras.isNotEmpty) {
      _controller = CameraController(selectedCameras.first, EnumHandler.imageResolutionToResolutionPreset(imageResolution), enableAudio: enableAudio, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);

      await _controller!.initialize().then((_) {
        _controller?.setZoomLevel(1.2);
        notifyListeners();
      });

      await changeFlashMode(_availableFlashMode.indexOf(defaultFlashMode));

      await _controller!.lockCaptureOrientation(EnumHandler.cameraOrientationToDeviceOrientation(orientation)).then((_) {
        notifyListeners();
      });
    }

    startImageStream();
  }

  Future<void> changeFlashMode(int index) async {
    try {
      await _controller?.setFlashMode(EnumHandler.cameraFlashModeToFlashMode(_availableFlashMode[index])).then((_) {
        _currentFlashMode = index;
        notifyListeners();
      });
    } catch (e) {
      logError(e.toString());
    }
  }

  void disposeController() {
    final CameraController? cameraController = _controller;

    if (cameraController != null && cameraController.value.isInitialized) {
      cameraController.dispose();
    }
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      if (cameraController.value.isStreamingImages) {
        try {
          cameraController.stopImageStream();
        } catch (e) {
          logError(e.toString());
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!cameraController.value.isStreamingImages) {
        startImageStream();
      }
    }
  }

  void startImageStream() async {
    final CameraController? cameraController = _controller;
    if (cameraController != null) {
      if (cameraController.value.isRecordingVideo == true) {
        try {
          await cameraController.stopVideoRecording();
        } catch (e) {
          logError(e.toString());
        }
      }
      try {
        cameraController.startImageStream(processImage);
      } catch (e) {
        logError(e.toString());
      }
    }
  }

  void processImage(CameraImage cameraImage) async {
    final CameraController? cameraController = _controller;
    if (!_alreadyCheckingImage) {
      _alreadyCheckingImage = true;
      try {
        await FaceIdentifier.scanImage(cameraImage: cameraImage, controller: cameraController, performanceMode: FaceDetectorMode.fast).then((result) async {
          _detectedFace = result;
          notifyListeners();

          if (result != null) {
            try {
              if (result.wellPositioned) {
                // Handle face detected logic here
              }
            } catch (e) {
              logError(e.toString());
            }
          }
        });
        _alreadyCheckingImage = false;
      } catch (ex, stack) {
        logError('$ex, $stack');
      }
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      logError(e.code, e.description);
      return null;
    }
  }

  void onLongPressStart(Function(int) onTimerStarted) async {
    final CameraController? cameraController = _controller;
    if (cameraController?.value.isRecordingVideo == true) return;
    await cameraController?.prepareForVideoRecording();

    onTimerStarted(15);

    try {
      if (cameraController?.value.isStreamingImages == true) {
        try {
          await cameraController?.stopImageStream();
        } catch (e) {
          logError(e.toString());
        }
      }
      if (cameraController?.value.isRecordingVideo == true) {
        return;
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (timer.tick == 15) {
          onLongPressFinished(
            (int tick) {
              timer.cancel();
            },
          );
        }
      });

      await cameraController?.startVideoRecording();
    } catch (e) {
      logError(e.toString());
    }
  }

  void onLongPressFinished(Function(int) onTimerFinished) async {
    onTimerFinished(_timer?.tick ?? 0);
    _timer?.cancel();
    final CameraController? cameraController = _controller;
    if (cameraController?.value.isRecordingVideo != true) return;

    try {
      XFile? video = await cameraController?.stopVideoRecording();
      if (video == null) {
        throw Exception('Video is null');
      }

      // Handle video capture logic here
    } catch (e) {
      logError(e.toString());
    }
  }
}
