import 'package:camera/camera.dart';
import 'package:face_camera/src/controllers/face_camera_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ZoomCircleRow extends StatelessWidget {
  ZoomCircleRow({
    super.key,
    this.cameraController,
  });
  final CameraController? cameraController;
  @override
  Widget build(BuildContext context) {
    final FaceCameraController faceCameraController = context.watch<FaceCameraController>();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black26,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          zoomCircle(
            zoomLevel: 1,
            displayValue: "0.5",
            faceCameraController: faceCameraController,
            controller: cameraController,
          ),
          const SizedBox(width: 5),
          zoomCircle(
            zoomLevel: 1.2,
            displayValue: "1",
            faceCameraController: faceCameraController,
            controller: cameraController,
          ),
          const SizedBox(width: 5),
          zoomCircle(
            zoomLevel: 2,
            displayValue: "2",
            faceCameraController: faceCameraController,
            controller: cameraController,
          ),
        ],
      ),
    );
  }

  final List<double> _zoomValues = [1, 1.2, 2];
  bool isSelectedZoomCircle(double value, double zoomCircleValue) {
    int index = _zoomValues.indexOf(zoomCircleValue);
    if (index == -1) return false;

    if (index == 0) {
      return value > 0.5 && value < 1.2;
    } else if (index == 1) {
      return value >= 1.2 && value < 2;
    }
    return value >= 2;
  }

  Widget zoomCircle(
      {required double zoomLevel,
      required String displayValue,
      required FaceCameraController faceCameraController,
      CameraController? controller}) {
    final bool isSelected = isSelectedZoomCircle(faceCameraController.scaleFactor, zoomLevel);
    return GestureDetector(
      onTap: () => faceCameraController.onTapZoomLevel(zoomLevel, controller),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: isSelected ? Colors.orange : Colors.black.withOpacity(.5),
        child: Text(
          zoomDisplayText(isSelected, faceCameraController, displayValue),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String zoomDisplayText(bool isSelected, FaceCameraController faceCameraController, String displayValue) {
    double scaleFactor = faceCameraController.scaleFactor;
    if (isSelected && scaleFactor < 1.2) {
      return "${(faceCameraController.scaleFactor - 0.5).toStringAsFixed(1)}x";
    }
    if (scaleFactor == 1.2) {
      scaleFactor = 1.0;
    }
    return isSelected ? "${scaleFactor.toStringAsFixed(1)}x" : "${displayValue}x";
  }
}
