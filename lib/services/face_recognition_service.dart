import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// New DetectedFace class that includes landmarks
class DetectedFace {
  final Rect boundingBox;
  final double confidence;
  // 6 keypoints for face alignment: left eye, right eye, nose, mouth, left tragion, right tragion
  final List<Point<double>> landmarks;

  DetectedFace(this.boundingBox, this.confidence, this.landmarks);
}

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() {
    return _instance;
  }
  FaceRecognitionService._internal();

  Interpreter? _embedder;
  Interpreter? _detector;

  static const String _embedderModelFile = "assets/ml/mobilefacenet.tflite";
  // Point to the new MediaPipe BlazeFace detector
  static const String _detectorModelFile = "assets/ml/face_detector.tflite";

  static const int _embeddingInputSize = 112;
  static const int _embeddingOutputSize = 192;
  // Input size for the new BlazeFace model
  static const int _detectorInputSize = 128;

  // Options for BlazeFace model processing
  final _blazeFaceOptions = {
    'num_classes': 1,
    'num_boxes': 896,
    'num_coords': 16,
    'keypoint_coord_offset': 4,
    'x_scale': 128.0,
    'y_scale': 128.0,
    'h_scale': 128.0,
    'w_scale': 128.0,
    'min_score_thresh': 0.50, // Higher confidence threshold
    'min_suppression_threshold': 0.3,
  };

  late List<Anchor> _anchors;

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
      _anchors = _generateAnchors();
    } catch (e) {
      print('❌ Failed to load models: $e');
    }
  }

  // New detectFaces function for MediaPipe BlazeFace model
  Future<List<DetectedFace>> detectFaces(img.Image image) async {
    if (_detector == null) {
      return [];
    }

    var resizedImage = img.copyResize(image, width: _detectorInputSize, height: _detectorInputSize);
    var input = _preProcessInput(resizedImage);
    
    final scores = List.filled(896 * 1, 0.0).reshape([1, 896, 1]);
    final regressions = List.filled(896 * 16, 0.0).reshape([1, 896, 16]);
    Map<int, Object> outputs = {
      0: regressions,
      1: scores,
    };

    _detector!.runForMultipleInputs([input], outputs);

    final rawScores = scores[0].map((e) => e[0] as double).toList();
    final rawRegressions = regressions[0].map((e) => List<double>.from(e)).toList();

    final List<DetectedFace> faces = await _processDetections(rawScores, rawRegressions, image.width, image.height);
    return faces;
  }

  // --- START BLAZEFACE POST-PROCESSING ---
  
  List<Anchor> _generateAnchors() {
    final anchors = <Anchor>[];
    const strides = [8, 16];
    const resolutions = [16, 8];
    for (var i = 0; i < strides.length; i++) {
      final stride = strides[i];
      final resolution = resolutions[i];
      for (var y = 0; y < resolution; y++) {
        for (var x = 0; x < resolution; x++) {
          anchors.add(Anchor(
            (x + 0.5) / resolution,
            (y + 0.5) / resolution,
            1.0, 1.0
          ));
        }
      }
    }
    return anchors;
  }

  Future<List<DetectedFace>> _processDetections(List<double> scores, List<List<double>> regressions, int originalWidth, int originalHeight) async {
    final List<_Candidate> candidates = [];
    for (var i = 0; i < _blazeFaceOptions['num_boxes']!; i++) {
      final score = 1.0 / (1.0 + exp(-scores[i]));
      if (score > _blazeFaceOptions['min_score_thresh']!) {
        candidates.add(_Candidate(score, i));
      }
    }
    
    if (candidates.isEmpty) return [];

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final List<DetectedFace> detections = [];
    for (final candidate in candidates) {
      if (candidate.score < 0) continue; 

      final decoded = _decodeBox(regressions[candidate.index], _anchors[candidate.index]);
      bool suppressed = false;
      for (final detection in detections) {
        final iou = _calculateIoU(decoded.boundingBox, detection.boundingBox);
        if (iou > _blazeFaceOptions['min_suppression_threshold']!) {
          suppressed = true;
          break;
        }
      }

      if (!suppressed) {
        final unnormalizedBox = Rect.fromLTRB(
          decoded.boundingBox.left * originalWidth,
          decoded.boundingBox.top * originalHeight,
          decoded.boundingBox.right * originalWidth,
          decoded.boundingBox.bottom * originalHeight
        );
        final unnormalizedLandmarks = decoded.landmarks.map((p) => Point(p.x * originalWidth, p.y * originalHeight)).toList();
        
        detections.add(DetectedFace(unnormalizedBox, candidate.score, unnormalizedLandmarks));
      }
    }
    return detections;
  }

  DetectedFace _decodeBox(List<double> raw, Anchor anchor) {
    final boxOffsetX = raw[0];
    final boxOffsetY = raw[1];
    final boxWidth = raw[2];
    final boxHeight = raw[3];

    final centerX = boxOffsetX / _blazeFaceOptions['x_scale']! + anchor.x;
    final centerY = boxOffsetY / _blazeFaceOptions['y_scale']! + anchor.y;
    final w = boxWidth / _blazeFaceOptions['w_scale']!;
    final h = boxHeight / _blazeFaceOptions['h_scale']!;

    final left = centerX - w / 2;
    final top = centerY - h / 2;
    final right = centerX + w / 2;
    final bottom = centerY + h / 2;

    final landmarks = <Point<double>>[];
    for (var i = 0; i < 6; i++) {
      final lx = raw[4 + i * 2] / _blazeFaceOptions['x_scale']! + anchor.x;
      final ly = raw[4 + i * 2 + 1] / _blazeFaceOptions['y_scale']! + anchor.y;
      landmarks.add(Point(lx, ly));
    }

    return DetectedFace(Rect.fromLTRB(left, top, right, bottom), 0, landmarks);
  }

  double _calculateIoU(Rect rect1, Rect rect2) {
    final intersectionLeft = max(rect1.left, rect2.left);
    final intersectionTop = max(rect1.top, rect2.top);
    final intersectionRight = min(rect1.right, rect2.right);
    final intersectionBottom = min(rect1.bottom, rect2.bottom);

    final intersectionArea = max(0.0, intersectionRight - intersectionLeft) * max(0.0, intersectionBottom - intersectionTop);
    final area1 = rect1.width * rect1.height;
    final area2 = rect2.width * rect2.height;
    final unionArea = area1 + area2 - intersectionArea;

    return intersectionArea / unionArea;
  }

  // --- END BLAZEFACE POST-PROCESSING ---

  // --- START FACE ALIGNMENT AND EMBEDDING ---

  List<double>? getEmbeddingWithAlignment(img.Image image, DetectedFace face) {
    if (_embedder == null) {
      return null;
    }
    
    // Align the face using landmarks before getting the embedding
    final alignedFace = _alignFace(image, face);
    
    if (alignedFace == null) {
      return null;
    }

    // Pre-process the aligned face and get the embedding
    var input = _preProcessInput(alignedFace, normalize: true, isEmbedder: true);
    var output = List.filled(1 * _embeddingOutputSize, 0.0).reshape([1, _embeddingOutputSize]);
    _embedder!.run(input, output);

    // L2 Normalize the embedding
    var embedding = List<double>.from(output[0]);
    final double norm = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    final normalized = embedding.map((e) => e / norm).toList();
    return normalized;
  }

  img.Image? _alignFace(img.Image image, DetectedFace face) {
    // Get eye landmarks
    final leftEye = face.landmarks[0];
    final rightEye = face.landmarks[1];

    // Calculate angle between eyes for rotation
    final double angle = atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x) * 180 / pi;

    // Rotate the image to make eyes horizontal
    final rotatedImage = img.copyRotate(image, angle: angle, interpolation: img.Interpolation.linear);

    // Re-calculate landmark positions in the rotated image
    final center = Point(image.width / 2, image.height / 2);
    final rotatedLandmarks = face.landmarks.map((p) => _rotatePoint(p, center, -angle * pi / 180)).toList();

    // Define a desired crop size around the center of the face
    final eyeCenter = Point(
      (rotatedLandmarks[0].x + rotatedLandmarks[1].x) / 2,
      (rotatedLandmarks[0].y + rotatedLandmarks[1].y) / 2,
    );
    final eyeDist = sqrt(pow(rotatedLandmarks[1].x - rotatedLandmarks[0].x, 2) + pow(rotatedLandmarks[1].y - rotatedLandmarks[0].y, 2));
    final cropWidth = eyeDist * 2.5;
    final cropHeight = cropWidth; // Keep aspect ratio 1:1

    final cropX = (eyeCenter.x - cropWidth / 2).round();
    final cropY = (eyeCenter.y - cropHeight / 2.5).round(); // Shift up slightly
    final cropW = cropWidth.round();
    final cropH = cropHeight.round();

    // Clamp crop values to be safely within the image bounds.
    final safeCropX = max(0, cropX);
    final safeCropY = max(0, cropY);
    final safeCropW = min(rotatedImage.width - safeCropX, cropW);
    final safeCropH = min(rotatedImage.height - safeCropY, cropH);

    if (safeCropW <= 0 || safeCropH <= 0) {
      return null;
    }

    // Crop the face using the safe dimensions
    final croppedFace = img.copyCrop(
      rotatedImage,
      x: safeCropX,
      y: safeCropY,
      width: safeCropW,
      height: safeCropH
    );
    
    // Resize to the final input size for the embedder model
    return img.copyResize(croppedFace, width: _embeddingInputSize, height: _embeddingInputSize, interpolation: img.Interpolation.linear);
  }
  
  Point<double> _rotatePoint(Point<double> point, Point<double> center, double angle) {
    final s = sin(angle);
    final c = cos(angle);
    final px = point.x - center.x;
    final py = point.y - center.y;
    final xnew = px * c - py * s;
    final ynew = px * s + py * c;
    return Point(xnew + center.x, ynew + center.y);
  }

  // --- END FACE ALIGNMENT AND EMBEDDING ---

  // --- UTILITY AND HELPER FUNCTIONS ---

  Object _preProcessInput(img.Image image, {bool normalize = true, bool isEmbedder = false}) {
    final int inputSize = isEmbedder ? _embeddingInputSize : _detectorInputSize;
    var input = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(input.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
        for (var j = 0; j < inputSize; j++) {
            var pixel = image.getPixel(j, i);
            if (normalize) {
              // Normalize to [-1, 1] for detector and [0, 1] for some embedders, then standardize
              buffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
              buffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
              buffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
            } else {
              buffer[pixelIndex++] = pixel.r.toDouble();
              buffer[pixelIndex++] = pixel.g.toDouble();
              buffer[pixelIndex++] = pixel.b.toDouble();
            }
        }
    }
    return input.reshape([1, inputSize, inputSize, 3]);
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
    return bestSim > threshold ? bestStudent : null;
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

  List<double>? averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return null;
    final int embeddingSize = embeddings.first.length;
    final List<double> averaged = List.filled(embeddingSize, 0.0);
    for (var embedding in embeddings) {
      for (int i = 0; i < embeddingSize; i++) {
        averaged[i] += embedding[i];
      }
    }
    for (int i = 0; i < embeddingSize; i++) {
      averaged[i] /= embeddings.length;
    }
    final double norm = sqrt(averaged.map((e) => e * e).reduce((a, b) => a + b));
    return norm == 0.0 ? averaged : averaged.map((e) => e / norm).toList();
  }

  // New method for directly embedding an already cropped image
  Future<List<double>?> getEmbeddingForCroppedImage(File croppedImageFile) async {
    if (_embedder == null) {
      print('❌ Face embedder model is not loaded!');
      return null;
    }

    final imageBytes = await croppedImageFile.readAsBytes();
    final img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      print('❌ Could not decode cropped image file.');
      return null;
    }

    // Ensure the image is resized to the embedder's input size
    final img.Image resizedImage = img.copyResize(image, width: _embeddingInputSize, height: _embeddingInputSize);

    // Pre-process the aligned face and get the embedding
    var input = _preProcessInput(resizedImage, normalize: true, isEmbedder: true);
    var output = List.filled(1 * _embeddingOutputSize, 0.0).reshape([1, _embeddingOutputSize]);
    _embedder!.run(input, output);

    // L2 Normalize the embedding
    var embedding = List<double>.from(output[0]);
    final double norm = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    final normalized = embedding.map((e) => e / norm).toList();
    return normalized;
  }
}

// Helper classes for BlazeFace post-processing
class Anchor {
  final double x, y, w, h;
  Anchor(this.x, this.y, this.w, this.h);
}

class _Candidate {
  double score;
  final int index;
  _Candidate(this.score, this.index);
}