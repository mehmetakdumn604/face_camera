import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_camera/src/handlers/face_identifier.dart';
import 'package:face_camera/src/widgets/zoom_circle_row.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../face_camera.dart';
import 'handlers/enum_handler.dart';
import 'paints/face_painter.dart';
import 'paints/hole_painter.dart';
import 'res/builders.dart';
import 'utils/logger.dart';

class SmartFaceCamera extends StatefulWidget {
  /// Use this to set image resolution.
  final ImageResolution imageResolution;

  /// Use this to set initial camera lens direction.
  final CameraLens? defaultCameraLens;

  /// Use this to set initial flash mode.
  final CameraFlashMode defaultFlashMode;

  /// Set false to disable capture sound.
  final bool enableAudio;

  /// Set true to capture image on face detected.
  final bool autoCapture;

  /// Set false to hide all controls.
  final bool showControls;

  /// Set false to hide capture control icon.
  final bool showCaptureControl;

  /// Set false to hide flash control control icon.
  final bool showFlashControl;

  /// Set false to hide camera lens control icon.
  final bool showCameraLensControl;

  /// Use this pass a message above the camera.
  final String? message;

  /// Style applied to the message widget.
  final TextStyle messageStyle;

  /// Use this to lock camera orientation.
  final CameraOrientation? orientation;

  /// Callback invoked when camera captures image.
  final void Function(File? image, DetectedFace? face, CameraLens lens) onCapture;

  /// Callback invoked when camera detects face.
  final void Function(Face? face)? onFaceDetected;

  /// Use this to render a custom widget for capture control.
  final Widget? captureControlIcon;

  /// Use this to build custom widgets for capture control.
  final CaptureControlBuilder? captureControlBuilder;

  /// Use this to render a custom widget for camera lens control.
  final Widget? lensControlIcon;

  /// Use this to build custom widgets for flash control based on camera flash mode.
  final FlashControlBuilder? flashControlBuilder;

  /// Use this to build custom messages based on face position.
  final MessageBuilder? messageBuilder;

  /// Use this to change the shape of the face indicator.
  final IndicatorShape indicatorShape;

  /// Use this to pass an asset image when IndicatorShape is set to image.
  final String? indicatorAssetImage;

  /// Use this to build custom widgets for the face indicator
  final IndicatorBuilder? indicatorBuilder;

  /// Set true to automatically disable capture control widget when no face is detected.
  final bool autoDisableCaptureControl;

  /// Use this to set your preferred performance mode.
  final FaceDetectorMode performanceMode;

  final Function(CameraLens)? onToggleCameraLens;

  /// use this set no camera lens
  final Widget? noCameraWidget;

  //   onTimerStarted
// onTimerFinished

  final void Function(int seconds) onTimerStarted;

  final void Function(int seconds) onTimerFinished;

  final void Function(FaceCameraController)? onInitController;

  const SmartFaceCamera({
    this.imageResolution = ImageResolution.medium,
    this.defaultCameraLens,
    this.enableAudio = true,
    this.autoCapture = false,
    this.showControls = true,
    this.showCaptureControl = true,
    this.showFlashControl = true,
    this.showCameraLensControl = true,
    this.message,
    this.defaultFlashMode = CameraFlashMode.auto,
    this.orientation = CameraOrientation.portraitUp,
    this.messageStyle = const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400),
    required this.onCapture,
    this.onFaceDetected,
    @Deprecated('Use [captureControlBuilder]') this.captureControlIcon,
    this.captureControlBuilder,
    this.lensControlIcon,
    this.flashControlBuilder,
    this.messageBuilder,
    this.indicatorShape = IndicatorShape.defaultShape,
    this.indicatorAssetImage,
    this.indicatorBuilder,
    this.autoDisableCaptureControl = false,
    this.performanceMode = FaceDetectorMode.fast,
    this.noCameraWidget,
    Key? key,
    this.onToggleCameraLens,
    required this.onTimerStarted,
    required this.onTimerFinished,
    this.onInitController,
  })  : assert(indicatorShape != IndicatorShape.image || indicatorAssetImage != null, 'IndicatorAssetImage must be provided when IndicatorShape is set to image.'),
        super(key: key);

  @override
  State<SmartFaceCamera> createState() => _SmartFaceCameraState();
}

class _SmartFaceCameraState extends State<SmartFaceCamera> with WidgetsBindingObserver, TickerProviderStateMixin {
  late FaceCameraController _faceCameraController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceCameraController = FaceCameraController();
    _faceCameraController.getAllAvailableCameraLens(FaceCamera.cameras, widget.defaultCameraLens);
    _faceCameraController.initCamera(FaceCamera.cameras, widget.imageResolution, widget.enableAudio, widget.orientation, widget.defaultFlashMode);
    widget.onInitController?.call(_faceCameraController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceCameraController.disposeController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _faceCameraController.handleAppLifecycleState(state);
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return ChangeNotifierProvider<FaceCameraController>(
      create: (context) => _faceCameraController,
      builder: (context, child) {
        final FaceCameraController faceCameraController = context.watch<FaceCameraController>();
        final CameraController? cameraController = faceCameraController.controller;
        return GestureDetector(
          onScaleStart: faceCameraController.onScaleStart,
          onScaleUpdate: (details) => faceCameraController.onScaleUpdate(details, cameraController),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (cameraController != null && cameraController.value.isInitialized) ...[
                OverflowBox(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size.width,
                    height: size.width * cameraController.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _cameraDisplayWidget(),
                        if (faceCameraController.detectedFace != null && widget.indicatorShape != IndicatorShape.none) ...[
                          SizedBox(
                              width: cameraController.value.previewSize!.width,
                              height: cameraController.value.previewSize!.height,
                              child: widget.indicatorBuilder?.call(
                                      context,
                                      faceCameraController.detectedFace,
                                      Size(
                                        cameraController.value.previewSize!.height,
                                        cameraController.value.previewSize!.width,
                                      )) ??
                                  CustomPaint(
                                    painter: FacePainter(
                                        face: faceCameraController.detectedFace?.face,
                                        indicatorShape: widget.indicatorShape,
                                        indicatorAssetImage: widget.indicatorAssetImage,
                                        imageSize: Size(
                                          cameraController.value.previewSize!.height,
                                          cameraController.value.previewSize!.width,
                                        )),
                                  ))
                        ]
                      ],
                    ),
                  ),
                )
              ] else
                ...(widget.noCameraWidget != null
                    ? [widget.noCameraWidget!]
                    : [
                        const Text('No Camera Detected',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w500,
                            )),
                        CustomPaint(
                          size: size,
                          painter: HolePainter(),
                        )
                      ]),
              if (widget.showControls) ...[
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ZoomCircleRow(cameraController: cameraController),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            const SizedBox(width: 15),
                            if (widget.showFlashControl) ...[_flashControlWidget()],
                            const SizedBox(width: 15),
                            if (widget.showCaptureControl) ...[
                              const Spacer(),
                              _captureControlWidget(),
                              const Spacer(),
                            ],
                            if (widget.showCameraLensControl) ...[_lensControlWidget(faceCameraController: faceCameraController)],
                            const SizedBox(width: 15),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }

  /// Render camera.
  Widget _cameraDisplayWidget() {
    final CameraController? cameraController = _faceCameraController.controller;
    if (cameraController != null && cameraController.value.isInitialized) {
      return CameraPreview(cameraController, child: Builder(builder: (context) {
        if (widget.messageBuilder != null) {
          return widget.messageBuilder!.call(context, _faceCameraController.detectedFace);
        }
        if (widget.message != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 15),
            child: Text(widget.message!, textAlign: TextAlign.center, style: widget.messageStyle),
          );
        }
        return const SizedBox.shrink();
      }));
    }
    return const SizedBox.shrink();
  }

  /// Enables controls only when camera is initialized.
  bool get _enableControls {
    final CameraController? cameraController = _faceCameraController.controller;
    return cameraController != null && cameraController.value.isInitialized;
  }

  /// Determines when to disable the capture control button.
  bool get _disableCapture => widget.autoDisableCaptureControl && _faceCameraController.detectedFace?.face == null;

  /// Determines the camera controls color.
  Color? get iconColor => _enableControls ? null : Theme.of(context).disabledColor;

  /// Display the control buttons to take pictures.

  Widget _captureControlWidget() {
    return GestureDetector(
      onTap: () => _faceCameraController.takePicture().then((file) {
        if (file != null) {
          widget.onCapture(File(file.path), _faceCameraController.detectedFace, _faceCameraController.availableCameraLens[_faceCameraController.currentCameraLens]);
        }
      }),
      onLongPressStart: (_) {
        log("On Long Press started");
        _faceCameraController.onLongPressStart(widget.onTimerStarted);
      },
      onLongPressUp: () {
        log("On Long Press Finished");
        _faceCameraController.onLongPressFinished(widget.onTimerFinished);
      },
      child: widget.captureControlBuilder?.call(context, _faceCameraController.detectedFace) ??
          widget.captureControlIcon ??
          CircleAvatar(
              radius: 35,
              foregroundColor: _faceCameraController.controller != null && !_faceCameraController.controller!.value.isTakingPicture ? null : Theme.of(context).disabledColor,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.camera_alt, size: 35),
              )),
    );
  }

  void showInSnackBar(String message) {
    if (!mounted && !kDebugMode) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Display the control buttons to switch between flash modes.
  Widget _flashControlWidget() {
    final icon = _faceCameraController.availableFlashMode[_faceCameraController.currentFlashMode] == CameraFlashMode.always
        ? Icons.flash_on
        : _faceCameraController.availableFlashMode[_faceCameraController.currentFlashMode] == CameraFlashMode.off
            ? Icons.flash_off
            : Icons.flash_auto;

    return widget.flashControlBuilder?.call(context, _faceCameraController.availableFlashMode[_faceCameraController.currentFlashMode]) ??
        IconButton(
          icon: CircleAvatar(
              radius: 25,
              foregroundColor: iconColor,
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Icon(icon, size: 25),
              )),
          onPressed: _enableControls ? () => _faceCameraController.changeFlashMode((_faceCameraController.currentFlashMode + 1) % _faceCameraController.availableFlashMode.length) : null,
        );
  }

  /// Display the control buttons to switch between camera lens.
  Widget _lensControlWidget({required FaceCameraController faceCameraController}) {
    return IconButton(
        icon: widget.lensControlIcon ??
            CircleAvatar(
                radius: 25,
                foregroundColor: iconColor,
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.switch_camera_sharp, size: 25),
                )),
        onPressed: _enableControls
            ? () {
                _faceCameraController.currentCameraLens = (_faceCameraController.currentCameraLens + 1) % _faceCameraController.availableCameraLens.length;
                _faceCameraController.initCamera(FaceCamera.cameras, widget.imageResolution, widget.enableAudio, widget.orientation, widget.defaultFlashMode);
                faceCameraController.scaleFactor = 1.2;
                widget.onToggleCameraLens?.call(_faceCameraController.availableCameraLens[_faceCameraController.currentCameraLens]);
              }
            : null);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (_faceCameraController.controller == null) {
      return;
    }

    final CameraController cameraController = _faceCameraController.controller!;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  Timer? _timer;
  void onLongPressStart(Function(int) onTimerStarted) async {
    final CameraController? cameraController = _faceCameraController.controller;
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
            (seconds) {
              if (seconds == 15) {
                timer.cancel();
              }
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
    final CameraController? cameraController = _faceCameraController.controller;
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

  void onTakePictureButtonPressed(Function(File?, DetectedFace?, CameraLens) onCapture) async {
    final CameraController? cameraController = _faceCameraController.controller;
    try {
      if (cameraController?.value.isRecordingVideo == true) {
        try {
          await cameraController?.stopVideoRecording();
        } catch (e) {
          logError(e.toString());
        }
      }
      if (cameraController?.value.isStreamingImages == true) {
        cameraController?.stopImageStream().whenComplete(() async {
          await Future.delayed(const Duration(milliseconds: 500));
          _faceCameraController.takePicture().then((XFile? file) {
            if (file != null) {
              onCapture(File(file.path), _faceCameraController.detectedFace, _faceCameraController.availableCameraLens[_faceCameraController.currentCameraLens]);
            }

            Future.delayed(const Duration(seconds: 2)).whenComplete(() {
              if (cameraController.value.isInitialized) {
                _faceCameraController.startImageStream();
              }
            });
          });
        });
      } else {
        _faceCameraController.takePicture().then((XFile? file) async {
          _faceCameraController.detectedFace = await FaceIdentifier.scanXFile(file);
          if (file != null) {
            onCapture(File(file.path), _faceCameraController.detectedFace, _faceCameraController.availableCameraLens[_faceCameraController.currentCameraLens]);
          }
        });
      }
    } catch (e) {
      logError(e.toString());
    }
  }
}
