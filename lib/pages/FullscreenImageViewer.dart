import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xspace/LoadandDecrypt.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FullscreenImageViewer extends StatefulWidget {
  final List<MediaFile> mediaList;
  final int initialIndex;
  final String aesKey;
  final String accessToken;

  const FullscreenImageViewer({
    super.key,
    required this.mediaList,
    required this.initialIndex,
    required this.aesKey,
    required this.accessToken,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool loading = true;
  Uint8List? decryptedBytes;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    decryptImage();
  }

Future<void> requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
}

  Future<void> decryptImage() async {
    final loader = DriveMediaLoader(
      aesKeyBase64: widget.aesKey,
      folderId: '',
      accessToken: widget.accessToken,
    );

    final media = widget.mediaList[_currentIndex];
    final result = await loader.decryptFullFile(media.fileId);

    if (result != null) {
      setState(() {
        decryptedBytes = result;
        loading = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      loading = true;
    });
    decryptImage();
  }

  Future<void> saveImageToDownloads() async {
    if (decryptedBytes == null) return;

    // Request permission
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission is required.')),
      );
      return;
    }

    try {
      final directory = Directory('/storage/emulated/0/Download'); // Android downloads folder
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }

      final fileName = 'xspace_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(decryptedBytes!);

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
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaList.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return Center(
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : InteractiveViewer(child: Image.memory(decryptedBytes!)),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.pop(context, _currentIndex);
              },
            ),
          ),
          Positioned(
            bottom: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.white, size: 30),
              onPressed: saveImageToDownloads,
            ),
          ),
        ],
      ),
    );
  }
}
