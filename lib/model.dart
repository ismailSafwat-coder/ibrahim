// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
// import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

// class ImageClassifierScreen extends StatefulWidget {
//   const ImageClassifierScreen({super.key});

//   @override
//   _ImageClassifierScreenState createState() => _ImageClassifierScreenState();
// }

// class _ImageClassifierScreenState extends State<ImageClassifierScreen> {
//   File? _image;
//   String _accuracy = "No prediction";
//   late tfl.Interpreter _interpreter;

//   @override
//   void initState() {
//     super.initState();
//     _loadModel();
//   }

//   Future<void> _loadModel() async {
//     _interpreter = await tfl.Interpreter.fromAsset('model.tflite');
//     setState(() {});
//   }

//   Future<void> _pickImage() async {
//     final pickedFile =
//         await ImagePicker().pickImage(source: ImageSource.gallery);

//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//       });
//       _runModel();
//     }
//   }

//   void _runModel() async {
//     if (_image == null) return;

//     // Prepare the image for the model
//     // Assume input size is 224x224
//     var input = _processImage(_image!);
//     var output = List.filled(1, 0.0).reshape([1, 1]);

//     _interpreter.run(input, output);
//     setState(() {
//       _accuracy = "Accuracy: ${(output[0][0] * 100).toStringAsFixed(2)}%";
//     });
//   }

//   List<List<List<List<double>>>> _processImage(File imageFile) {
//     // Convert the image to a tensor-friendly format (resize to 224x224 and normalize)
//     // This is a placeholder; you need an actual image pre-processing method
//     return List.generate(
//         1,
//         (_) => List.generate(
//             224, (_) => List.generate(224, (_) => List.filled(3, 0.0))));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Image Classifier")),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             _image == null
//                 ? const Text("No image selected")
//                 : Image.file(_image!, height: 300, width: 300),
//             const SizedBox(height: 20),
//             Text(_accuracy, style: const TextStyle(fontSize: 18)),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _pickImage,
//               child: const Text("Select Image"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
