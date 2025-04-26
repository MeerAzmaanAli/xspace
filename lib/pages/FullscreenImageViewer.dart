import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xspace/LoadandDecrypt.dart';
import 'package:permission_handler/permission_handler.dart';


class FullscreenImageViewer extends StatefulWidget {
  final List<MediaFile> mediaList;
  final int initialIndex;
  final void Function(int currentIndex)? onDelete;
  final VoidCallback? onClose;

const FullscreenImageViewer({
  super.key,
  required this.mediaList,
  required this.initialIndex,
  this.onDelete,
  this.onClose,
});

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Delete image function
  Future<void> _deleteImage() async {
    if (widget.onDelete != null) {
      widget.onDelete!(_currentIndex); // Pass current index here!
    }
    Navigator.pop(context); // Close viewer after deleting
  }

  // Save image to Downloads
  Future<void> saveImageToDownloads() async {
    final decryptedBytes = widget.mediaList[_currentIndex].decryptedBytes;
    if (decryptedBytes == null) return;

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required.')),
      );
      return;
    }

    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      final fileName = 'xspace_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(decryptedBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Downloads: $fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView with media images
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaList.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final media = widget.mediaList[index];
              final bytes = media.decryptedBytes;
              if (bytes == null) {
                print("null bytes");
              }
              return ZoomableImage(
                imageBytes: bytes,
              );
            },
          ),
          // Positioned delete button
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white, size: 30),
              onPressed: _deleteImage, // Delete image and trigger callback
            ),
          ),
          // Positioned download button
          Positioned(
            bottom: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.white, size: 30),
              onPressed: saveImageToDownloads, // Save image to Downloads
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                if (widget.onClose != null) widget.onClose!();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ZoomableImage extends StatefulWidget {
  final Uint8List? imageBytes;

  const ZoomableImage({Key? key, this.imageBytes}) : super(key: key);

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> with SingleTickerProviderStateMixin {
  TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageBytes == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return GestureDetector(
      onDoubleTapDown: (details) {
        _doubleTapDetails = details;
      },
      onDoubleTap: () {
        if (_transformationController.value != Matrix4.identity()) {
          // Zoom out
          _transformationController.value = Matrix4.identity();
        } else {
          // Zoom in
          final position = _doubleTapDetails!.localPosition;
          _transformationController.value = Matrix4.identity()
            ..translate(-position.dx * 1.5, -position.dy * 1.5)
            ..scale(3.0);
        }
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true, // Allow dragging
        scaleEnabled: true, // Allow pinch zoom
        minScale: 1.0,
        maxScale: 4.0,
        child: Image.memory(
          widget.imageBytes!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
