
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // For Rect
import 'package:image/image.dart' as img;
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// This is a placeholder class. The actual implementation will depend on the face detection model.
class DetectedFace {
  final Rect boundingBox;
  // The score or confidence of the detection
  final double confidence;

  DetectedFace(this.boundingBox, this.confidence);
}

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() {
    return _instance;
  }
  FaceRecognitionService._internal();

  Interpreter? _embedder;
  Interpreter? _detector;

  // USER MUST PROVIDE THESE MODELS
  static const String _embedderModelFile = "assets/ml/mobilefacenet.tflite";
  static const String _detectorModelFile = "assets/ml/face_detector.tflite";

  static const int _embeddingInputSize = 112;
  static const int _embeddingOutputSize = 192;
  static const int _detectorInputSize = 320; // Example input size

  Future<void> loadModel() async {
    try {
      _embedder = await Interpreter.fromAsset(
        _embedderModelFile,
        options: InterpreterOptions()..threads = 4,
      );
      print('✅ Embedder model loaded successfully');

      _detector = await Interpreter.fromAsset(
        _detectorModelFile,
        options: InterpreterOptions()..threads = 4,
      );
      print('✅ Detector model loaded successfully');
    } catch (e) {
      print('❌ Failed to load models: $e');
      print('Ensure you have added "mobilefacenet.tflite" and "face_detector.tflite" to your assets/ml/ folder');
    }
  }

  // This function is a placeholder. Its implementation is highly dependent
  // on the specific face detection TFLite model you use.
  // It assumes a model that outputs boxes, scores, and number of detections.
  Future<List<DetectedFace>> detectFaces(img.Image image) async {
    if (_detector == null) return [];

    var resizedImage = img.copyResize(image, width: _detectorInputSize, height: _detectorInputSize);
    var imageBytes = resizedImage.getBytes();
    var input = Float32List(1 * _detectorInputSize * _detectorInputSize * 3);
    var buffer = Float32List.view(input.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < _detectorInputSize; i++) {
        for (var j = 0; j < _detectorInputSize; j++) {
            var pixel = resizedImage.getPixel(j, i);
            buffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
            buffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
            buffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
        }
    }
    
    // This is a common output structure for models like SSD MobileNet.
    // YOU MUST ADJUST THIS TO YOUR MODEL's OUTPUT.
    final outputBoxes = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]); // 10 detections, 4 coords
    final outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]); // 10 classes
    final outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]); // 10 scores
    final numDetections = List.filled(1, 0.0).reshape([1]);
    Map<int, Object> outputs = {
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    _detector!.runForMultipleInputs([input.reshape([1, _detectorInputSize, _detectorInputSize, 3])], outputs);
    
    List<DetectedFace> faces = [];
    int detectionsCount = numDetections[0].toInt();
    for (int i = 0; i < detectionsCount; i++) {
      final score = outputScores[0][i];
      if (score > 0.5) { // Confidence threshold
        final box = outputBoxes[0][i];
        // Output format is often [ymin, xmin, ymax, xmax] and normalized.
        final top = box[0] * image.height;
        final left = box[1] * image.width;
        final bottom = box[2] * image.height;
        final right = box[3] * image.width;
        faces.add(DetectedFace(Rect.fromLTRB(left, top, right, bottom), score));
      }
    }
    return faces;
  }
  
  List<double>? getEmbedding(img.Image image, Rect faceRect) {
    if (_embedder == null) return null;

    img.Image croppedFace = img.copyCrop(image, x: faceRect.left.toInt(), y: faceRect.top.toInt(), width: faceRect.width.toInt(), height: faceRect.height.toInt());
    img.Image resizedImage = img.copyResize(croppedFace, width: _embeddingInputSize, height: _embeddingInputSize);

    var imageBytes = resizedImage.getBytes();
    var input = Float32List(1 * _embeddingInputSize * _embeddingInputSize * 3);
    var buffer = Float32List.view(input.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < _embeddingInputSize; i++) {
      for (var j = 0; j < _embeddingInputSize; j++) {
        var pixel = resizedImage.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - 127.5) / 128.0;
        buffer[pixelIndex++] = (pixel.g - 127.5) / 128.0;
        buffer[pixelIndex++] = (pixel.b - 127.5) / 128.0;
      }
    }
    
    var reshapedInput = input.reshape([1, _embeddingInputSize, _embeddingInputSize, 3]);
    var output = List.filled(1 * _embeddingOutputSize, 0.0).reshape([1, _embeddingOutputSize]);
    _embedder!.run(reshapedInput, output);

    var embedding = List<double>.from(output[0]);
    final double norm = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    var normalizedEmbedding = embedding.map((e) => e / norm).toList();

    return normalizedEmbedding;
  }
  
  Student? findBestMatch(List<double> emb, List<Student> students, double threshold) {
    Student? bestStudent;
    double bestSim = -1.0;

    for (var student in students) {
      if (student.embedding != null && student.embedding!.isNotEmpty) {
        double sim = cosineSimilarity(emb, student.embedding!);
        if (sim > bestSim) {
          bestSim = sim;
          bestStudent = student;
        }
      }
    }
    
    if (bestSim > threshold) {
      return bestStudent;
    }
    
    return null;
  }

  double cosineSimilarity(List<double> emb1, List<double> emb2) {
    if (emb1.isEmpty || emb2.isEmpty || emb1.length != emb2.length) return 0.0;
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      dotProduct += emb1[i] * emb2[i];
      norm1 += emb1[i] * emb1[i];
      norm2 += emb2[i] * emb2[i];
    }
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }
}
