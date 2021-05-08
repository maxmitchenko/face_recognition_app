// @dart=2.9
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_face_recognition_test_app/face_detector_painter.dart';
import 'package:flutter_face_recognition_test_app/scan_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Face Recognition',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Face Recognition'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({@required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;
  List<CameraDescription> cameras;
  final FaceDetector _faceDetector = FirebaseVision.instance.faceDetector(
    FaceDetectorOptions(enableClassification: true),
  );
  CameraLensDirection _direction = CameraLensDirection.back;
  CameraController _cameraController;
  bool _isDetecting = false;
  List<Face> _scanResults = <Face>[];
  String faceStateText = '...';

  @override
  void initState() {
    _isLoading = true;
    super.initState();
    _myFaceRecognitionMethod();
  }

  @override
  void dispose() {
    _cameraController.dispose().then((_) {
      _faceDetector.close();
    });
    super.dispose();
  }

  _myFaceRecognitionMethod() async {
    // cameras = await availableCameras();
    final CameraDescription cameraDescription =
        await ScannerUtils.getCamera(_direction);
    _cameraController = CameraController(
      cameraDescription,
      // ResolutionPreset.medium,
      Platform.isIOS ? ResolutionPreset.low : ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController.initialize();
    await _cameraController.startImageStream((CameraImage image) async {
      final List<Face> faces = await ScannerUtils.detectFaces(
        image: image,
        imageRotation: cameraDescription.sensorOrientation,
        detectFaces: _faceDetector.processImage,
      );
      if (!mounted) return;
      setState(() {
        _scanResults = faces;
      });
    });
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    final CameraDescription description =
        await ScannerUtils.getCamera(_direction);

    _cameraController = CameraController(
      description,
      // ResolutionPreset.medium,
      Platform.isIOS ? ResolutionPreset.low : ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController.initialize();

    await _cameraController.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      ScannerUtils.detect(
        image: image,
        detectInImage: _faceDetector.processImage,
        imageRotation: description.sensorOrientation,
      ).then(
        (dynamic results) {
          if (!mounted) return;
          setState(() {
            _scanResults = results;
          });
        },
      ).whenComplete(() => _isDetecting = false);
    });
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _toggleCameraDirection() async {
    setState(() {
      _isLoading = true;
    });
    if (_direction == CameraLensDirection.back) {
      _direction = CameraLensDirection.front;
    } else {
      _direction = CameraLensDirection.back;
    }

    await _cameraController.stopImageStream();
    await _cameraController.dispose();

    await _myFaceRecognitionMethod();
    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: _isLoading
          ? const Center(
              child: Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CameraPreview(_cameraController),
                _buildResults(),
              ],
            ),
    );
  }

  Widget _buildResults() {
    const Text noResultsText = Text('No results!');

    if (_scanResults == null ||
        _cameraController == null ||
        !_cameraController.value.isInitialized) {
      return noResultsText;
    }

    CustomPainter painter;

    final Size imageSize = Size(
      _cameraController.value.previewSize.height,
      _cameraController.value.previewSize.width,
    );

    if (_scanResults is! List<Face>) return noResultsText;
    painter = FaceDetectorPainter(imageSize, _scanResults);
    // print('_scanResults: ${_scanResults.runtimeType} --- ${_scanResults}');
    // (_scanResults).forEach((Face face) {
    // print('_scanResults: $_scanResults');
    if (_scanResults.isNotEmpty) {
      final Face myFace = _scanResults[0];
      print('smilingProbability: ${myFace.smilingProbability}');
      if (myFace.smilingProbability >= 0.6) {
        setState(() {
          print('Smile');
          faceStateText = 'You smile! Great! :)';
        });
      } else {
        setState(() {
          print('Not Smile');
          faceStateText = '...';
        });
      }
    }
    // print('face.leftEyeOpenProbability: ${face.leftEyeOpenProbability}');
    // print('face.smilingProbability: ${face.smilingProbability}');
    // });
    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(faceStateText),
      ),
      body: _buildImage(),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleCameraDirection,
        child: _direction == CameraLensDirection.back
            ? const Icon(Icons.camera_front)
            : const Icon(Icons.camera_rear),
      ),
    );
  }
}
