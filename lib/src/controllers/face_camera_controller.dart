import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceCameraController extends ChangeNotifier {
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
}
