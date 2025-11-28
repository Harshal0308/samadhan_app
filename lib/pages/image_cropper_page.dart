import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math_64.dart' hide Colors;

class ImageCropperPage extends StatefulWidget {
  final File imageFile;

  const ImageCropperPage({super.key, required this.imageFile});

  @override
  State<ImageCropperPage> createState() => _ImageCropperPageState();
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _imageKey = GlobalKey();
  final double _cropBoxSize = 300.0;

  void _setZoom(double scale) {
    // This is a simplified zoom. A more robust implementation would zoom towards the center of the viewport.
    final newMatrix = Matrix4.identity()..scale(scale);
    _transformationController.value = newMatrix;
  }

  void _onConfirm() async {
    // 1. Get image properties
    final imageBytes = await widget.imageFile.readAsBytes();
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return;

    // 2. Get transformation matrix
    final matrix = _transformationController.value;

    // 3. Get the size of the widget holding the image
    final RenderBox imageRenderBox = _imageKey.currentContext!.findRenderObject() as RenderBox;
    final imageWidgetSize = imageRenderBox.size;

    // 4. Calculate scale and offset from the matrix
    final double scale = matrix.getMaxScaleOnAxis();
    final Vector3 translation = matrix.getTranslation();
    final Offset offset = Offset(translation.x, translation.y);

    // 5. Define the crop area in screen coordinates (center of the screen)
    final screenCenter = Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
    final cropRectScreen = Rect.fromCenter(
      center: screenCenter,
      width: _cropBoxSize,
      height: _cropBoxSize,
    );

    // 6. Map the screen crop area back to the coordinate system of the panned/zoomed image *widget*
    final cropRectImageWidget = Rect.fromLTRB(
      (cropRectScreen.left - offset.dx) / scale,
      (cropRectScreen.top - offset.dy) / scale,
      (cropRectScreen.right - offset.dx) / scale,
      (cropRectScreen.bottom - offset.dy) / scale,
    );

    // 7. Map from the image widget coordinates to the original image's pixel coordinates
    // This requires knowing how the image is fitted into its widget space. Assuming BoxFit.contain.
    final double originalAspectRatio = originalImage.width / originalImage.height;
    final double imageWidgetAspectRatio = imageWidgetSize.width / imageWidgetSize.height;
    
    double renderScaleX, renderScaleY;
    if (originalAspectRatio > imageWidgetAspectRatio) {
      // Original is wider than widget area, so it's constrained by width
      renderScaleX = originalImage.width / imageWidgetSize.width;
      renderScaleY = renderScaleX;
    } else {
      // Original is taller or same aspect ratio, so it's constrained by height
      renderScaleY = originalImage.height / imageWidgetSize.height;
      renderScaleX = renderScaleY;
    }
     final topPadding = (imageWidgetSize.height - (originalImage.height / renderScaleY)) / 2;
     final leftPadding = (imageWidgetSize.width - (originalImage.width / renderScaleX)) / 2;


    final cropRectOriginal = Rect.fromLTRB(
      (cropRectImageWidget.left - leftPadding) * renderScaleX,
      (cropRectImageWidget.top - topPadding) * renderScaleY,
      (cropRectImageWidget.right - leftPadding) * renderScaleX,
      (cropRectImageWidget.bottom - topPadding) * renderScaleY,
    );


    // 9. Perform the crop
    final croppedImage = img.copyCrop(
      originalImage,
      x: cropRectOriginal.left.round(),
      y: cropRectOriginal.top.round(),
      width: cropRectOriginal.width.round(),
      height: cropRectOriginal.height.round(),
    );

    // 10. Return the cropped image
    Navigator.of(context).pop(croppedImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Crop Your Photo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _onConfirm,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                widget.imageFile,
                key: _imageKey,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Crop box overlay
          Center(
            child: Container(
              width: _cropBoxSize,
              height: _cropBoxSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
  color: Colors.black,
  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
              onPressed: () => _setZoom(1.0),
              child: const Text('1×', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => _setZoom(1.5),
              child: const Text('1.5×', style: TextStyle(color: Colors.white))),
          TextButton(
              onPressed: () => _setZoom(2.0),
              child: const Text('2×', style: TextStyle(color: Colors.white))),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _onConfirm,
          child: const Text(
            "DONE",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const SizedBox(height: 12),
    ],
  ),
),

    );
  }
}
