import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'dart:math' as m; // Add this line

class DetectionResult {
  final double x, y, w, h;
  final double confidence;
  final String label;

  DetectionResult({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.confidence,
    required this.label,
  });
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> results;
  final double imageWidth;
  final double imageHeight;

  const BoundingBoxPainter(this.results, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const textStyle = TextStyle(color: Colors.red, fontSize: 14);

    // Calculate scaling and offset for BoxFit.contain
    double scaleX = size.width / imageWidth;
    double scaleY = size.height / imageHeight;
    double scale = m.min(scaleX, scaleY);

    double displayedWidth = imageWidth * scale;
    double displayedHeight = imageHeight * scale;
    double offsetX = (size.width - displayedWidth) / 2;
    double offsetY = (size.height - displayedHeight) / 2;

    for (final r in results) {
      // Apply scaling and offset
      final rect = Rect.fromLTWH(
        r.x * scale + offsetX,
        r.y * scale + offsetY,
        r.w * scale,
        r.h * scale,
      );

      canvas.drawRect(rect, paint);
      final span = TextSpan(
        text: '${r.label} ${(r.confidence * 100).toStringAsFixed(1)}%',
        style: textStyle,
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(rect.left, rect.top - tp.height));
    }
  }

  @override
  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) =>
      true; // Changed 'old' to 'oldDelegate'
}

class ImagePickerScreen extends StatefulWidget {
  const ImagePickerScreen({super.key});

  @override
  State<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  File? _image;
  List<DetectionResult> _detections = [];
  tfl.Interpreter? _interpreter;
  final List<String> _labels = ['Background', 'soil', 'worm'];
  double _confidenceThreshold = 0.3;
  late int _modelWidth, _modelHeight;
  double _imageWidth = 1, _imageHeight = 1;

  // Counters for each detection type
  int _wormCount = 0;
  int _soilCount = 0;
  int _backgroundCount = 0;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter =
          await tfl.Interpreter.fromAsset('assets/best_float16.tflite');
      final inputTensor = _interpreter!.getInputTensor(0);
      _modelHeight = inputTensor.shape[1];
      _modelWidth = inputTensor.shape[2];
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pi = await ImagePicker().pickImage(source: source);
    if (pi == null) return;
    setState(() {
      _image = File(pi.path);
      _detections.clear();
      _resetCounters();
    });
    await _runModel(_image!);
  }

  void _resetCounters() {
    _wormCount = 0;
    _soilCount = 0;
    _backgroundCount = 0;
  }

  Future<void> _runModel(File file) async {
    if (_interpreter == null) return;

    try {
      // Read and resize the image
      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return;
      _imageWidth = original.width.toDouble();
      _imageHeight = original.height.toDouble();
      final resized =
          img.copyResize(original, width: _modelWidth, height: _modelHeight);

      // Convert image to input tensor format
      final inputBuffer = _imageToByteListFloat32(resized);
      final input = inputBuffer.reshape([1, _modelHeight, _modelWidth, 3]);

      // Prepare output matching [1, 9, 9261]
      final outShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.generate(
        outShape[0],
        (_) => List.generate(
          outShape[1],
          (_) => List.filled(outShape[2], 0.0),
        ),
      );

      // Run inference
      _interpreter!.run(input, output);

      // Process the output
      _processOutput(output[0]);
    } catch (e) {
      debugPrint('Error running model: $e');
    }
  }

  Float32List _imageToByteListFloat32(img.Image image) {
    final len = _modelWidth * _modelHeight * 3;
    final buffer = Float32List(len);
    int idx = 0;
    for (int y = 0; y < _modelHeight; y++) {
      for (int x = 0; x < _modelWidth; x++) {
        final img.Pixel p = image.getPixel(x, y);
        buffer[idx++] = (p.r.toDouble() / 255.0); // Normalize to [0, 1]
        buffer[idx++] = (p.g.toDouble() / 255.0);
        buffer[idx++] = (p.b.toDouble() / 255.0);
      }
    }
    return buffer;
  }

  void _processOutput(List<List<double>> output) {
    final dets = <DetectionResult>[];
    _resetCounters();

    // Loop through all potential detections (9261)
    for (int i = 0; i < output[0].length; i++) {
      final x = output[0][i]; // x-coordinate
      final y = output[1][i]; // y-coordinate
      final w = output[2][i]; // width
      final h = output[3][i]; // height
      final conf = output[4][i]; // confidence score
      final cls = output[5][i].toInt(); // class index

      // Check if the detection is valid and meets the confidence threshold
      if (conf > _confidenceThreshold && cls >= 0 && cls < _labels.length) {
        dets.add(DetectionResult(
          x: x,
          y: y,
          w: w,
          h: h,
          confidence: conf,
          label: _labels[cls],
        ));

        // Update counters
        switch (_labels[cls]) {
          case 'worm':
            _wormCount++;
            break;
          case 'soil':
            _soilCount++;
            break;
          case 'Background':
            _backgroundCount++;
            break;
        }
      }
    }

    setState(() => _detections = dets);
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Soil and Worm Detection')),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: _image == null
                  ? const Center(
                      child: Text('Select an image to detect objects'))
                  : Stack(
                      // Use Stack to layer widgets
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey, width: 2)),
                          margin: const EdgeInsets.symmetric(horizontal: 15),
                          child: Image.file(
                            _image!,
                            fit: BoxFit.cover,
                            width: MediaQuery.sizeOf(context).height * 0.4,
                            height: MediaQuery.sizeOf(context).height * 0.3,
                          ),
                        ),
                        CustomPaint(
                          // Draw painter on top
                          painter: BoundingBoxPainter(
                              _detections, _imageWidth, _imageHeight),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      child: const Text('Camera')),
                  ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      child: const Text('Gallery')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Confidence Threshold:'),
                  Expanded(
                      child: Slider(
                          value: _confidenceThreshold,
                          min: 0,
                          max: 1,
                          divisions: 100,
                          label: _confidenceThreshold.toStringAsFixed(2),
                          onChanged: (v) =>
                              setState(() => _confidenceThreshold = v))),
                ],
              ),
            ),
            // Detection counters
            Container(
              margin: const EdgeInsets.only(bottom: 55),
              child: Column(
                children: [
                  Text(
                    'Worms detected: $_wormCount',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Soil areas detected: $_soilCount',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Background areas detected: $_backgroundCount',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
