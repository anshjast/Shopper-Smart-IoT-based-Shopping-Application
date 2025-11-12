import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // CRITICAL FIX: Import main.dart to access the global 'cameras' variable

// REMOVED: The redundant 'late List<CameraDescription> cameras;' declaration that was causing the crash

// --- UTILITY: YUV420 to RGB Image Conversion ---
img.Image? convertYUV420ToImage(CameraImage cameraImage) {
  final int width = cameraImage.width;
  final int height = cameraImage.height;
  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

  final image = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvRowStride * (y ~/ 2) + uvPixelStride * (x ~/ 2);
      final int index = y * width + x;

      final yValue = cameraImage.planes[0].bytes[index];
      final uValue = cameraImage.planes[1].bytes[uvIndex];
      final vValue = cameraImage.planes[2].bytes[uvIndex];

      int r = (yValue + 1.370705 * (vValue - 128)).round();
      int g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128)).round();
      int b = (yValue + 1.732446 * (uValue - 128)).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return image;
}

// --- TFLite Model Input Preparation ---
Uint8List imageToByteList(img.Image image, int inputSize) {
  final resizedImage = img.copyResize(image, width: inputSize, height: inputSize );
  final floatList = Float32List(1 * inputSize * inputSize * 3);
  int pixelIndex = 0;

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final pixel = resizedImage.getPixel(x, y);

      floatList[pixelIndex++] = (pixel.r / 255.0);
      floatList[pixelIndex++] = (pixel.g / 255.0);
      floatList[pixelIndex++] = (pixel.b / 255.0);
    }
  }
  return floatList.buffer.asUint8List();
}


// --- MAIN SCANNER WIDGET ---

class ScannerScreen extends StatefulWidget {
  final String username;
  final String uid;

  const ScannerScreen({Key? key, required this.username, required this.uid}) : super(key: key);

  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // Model Setup
  Interpreter? _interpreter;
  List<String>? _labels;
  final int _inputSize = 224;
  final double _confidenceThreshold = 0.85;
  final String _modelPath = 'assets/shopper_model.tflite';
  final String _labelsPath = 'assets/labels.txt';

  // Camera & State Setup
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  String _currentProductName = "Point camera at item...";
  double _currentConfidence = 0.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadModelAndLabels();

    // CRITICAL FIX: This now uses the 'cameras' list from main.dart
    if (cameras.isEmpty) {
      print("FATAL: No cameras available.");
      setState(() {
        _isCameraInitialized = false;
        _currentProductName = "Error: No cameras found.";
      });
      return;
    }

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _cameraController!.initialize().then((_) {
      if (!mounted) return;
      _isCameraInitialized = true;
      setState(() {});

      _cameraController!.startImageStream(_processCameraImage);
    });
  }

  Future<void> _loadModelAndLabels() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      final labelFile = await DefaultAssetBundle.of(context).loadString(_labelsPath);
      _labels = labelFile.split('\n').where((l) => l.isNotEmpty).toList();
      print("Model loaded successfully. Input Shape: ${_interpreter?.getInputTensor(0).shape}");
    } catch (e) {
      print("FATAL: Failed to load model or labels: $e. Using fallback mode.");
      setState(() {
        _currentProductName = "AI Model Error. Using fallback.";
      });
      _interpreter = null;
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (!_isCameraInitialized || _interpreter == null || _isDetecting) return;

    _isDetecting = true;

    final img.Image? preprocessedImage = await Future.microtask(() {
      return convertYUV420ToImage(image);
    });

    if (preprocessedImage != null) {
      _runInference(preprocessedImage);
    } else {
      _isDetecting = false;
    }
  }

  Future<void> _runInference(img.Image image) async {
    if (_interpreter == null) {
      _isDetecting = false;
      return;
    }

    final inputBytes = imageToByteList(image, _inputSize);
    // Ensure labels are loaded before running inference
    if (_labels == null) {
      _isDetecting = false;
      return;
    }
    final output = List.filled(_labels!.length, 0.0).reshape([1, _labels!.length]);

    _interpreter!.run(inputBytes, output);

    double maxConfidence = 0.0;
    int predictedIndex = -1;

    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxConfidence) {
        maxConfidence = output[0][i];
        predictedIndex = i;
      }
    }

    String rawPrediction = "Unknown";
    if (predictedIndex != -1 && predictedIndex < _labels!.length) {
      rawPrediction = _labels![predictedIndex];
    }

    final name = rawPrediction.replaceFirst(RegExp(r'^\d+\s*'), '');

    if (predictedIndex != -1 && maxConfidence > _currentConfidence) {
      if(mounted) {
        setState(() {
          _currentProductName = name;
          _currentConfidence = maxConfidence;
        });
      }
    } else if (maxConfidence < 0.2) {
      if(mounted) {
        setState(() {
          _currentProductName = "Searching for product...";
          _currentConfidence = maxConfidence;
        });
      }
    }

    _isDetecting = false;
  }

  Future<void> _addItemToCart(String productName) async {

    final String firestoreDocId;

    switch (productName) {
      case "Coca-Cola Can":
        firestoreDocId = "CocaColaCan";
        break;
      case "KitKat Bar":
        firestoreDocId = "Kitakatbar";
        break;
      case "Lays Chile Lemon Chips":
        firestoreDocId = "Lays_chips";
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Product "$productName" is not in the database.')),
        );
        return;
    }

    final productDoc = await _firestore.collection('products').doc(firestoreDocId).get();

    if (!productDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Product data for "$productName" is missing.')),
      );
      return;
    }

    final productData = productDoc.data()!;

    final double price = (productData['Price'] as num? ?? 0.0).toDouble();
    final double weight = (productData['Weight'] as num? ?? productData['weight'] as num? ?? 0.0).toDouble();
    final String savedName = productData['Name'] ?? productName;

    final cartItemRef = _firestore.collection('carts').doc(widget.uid).collection('items').doc(firestoreDocId);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot cartSnapshot = await transaction.get(cartItemRef);

        int currentQuantity = 0;
        if (cartSnapshot.exists) {
          currentQuantity = (cartSnapshot.data() as Map<String, dynamic>)['quantity'] ?? 0;
        }

        transaction.set(cartItemRef, {
          'productId': firestoreDocId,
          'name': savedName,
          'price': price,
          'weight_grams': weight,
          'quantity': currentQuantity + 1,
          'scan_confidence': _currentConfidence,
          'addedAt': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$savedName added to cart! Price: ₹${price.toStringAsFixed(2)}')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add item to cart: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        appBar: AppBar(title: Text("AI Scanner - User: ${widget.username}")),
        body: Center(child: Text(_currentProductName, style: const TextStyle(fontSize: 18))),
      );
    }

    final size = MediaQuery.of(context).size;
    // Ensure controller is initialized before accessing value
    if (!_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text("AI Scanner - User: ${widget.username}")),
        body: const Center(child: Text("Camera not initialized...", style: TextStyle(fontSize: 18))),
      );
    }
    final scale = size.aspectRatio * _cameraController!.value.aspectRatio;

    return Scaffold(
      appBar: AppBar(title: Text("AI Scanner - User: ${widget.username}")),
      body: Stack(
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_cameraController!),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentProductName,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Confidence: ${_currentConfidence > 0.0 ? (_currentConfidence * 100).toStringAsFixed(2) + '%' : '---'}",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: (_currentConfidence >= _confidenceThreshold && _currentProductName != "Background")
                        ? () {
                      _addItemToCart(_currentProductName);

                      setState(() {
                        _currentProductName = "Item added! Scan next...";
                        _currentConfidence = 0.0;
                      });
                    }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text("Add to Cart"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }
}