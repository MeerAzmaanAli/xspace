import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xspace/LoadandDecrypt.dart';
import 'package:xspace/pages/FullscreenImageViewer.dart';
import 'package:xspace/uploadandencrypt.dart';
import 'package:xspace/utils.dart';
import 'package:xspace/xauth.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {

  final int pageSize = 18;
  int currentStartIndex = 0;
  int? selectedMediaIndex;

  bool isLoading = false;

  final uploadEncrypt = Uploadandencrypt();
  late DriveMediaLoader loader;
  final Utils utils=  Utils();
  final ScrollController _scrollController = ScrollController();

  List<MediaFile> allMetadata = [];
  List<MediaFile> visibleMedia = [];
  Map<String, Uint8List> decryptedMedia = {};

  @override
  void initState() {
    super.initState();
    init();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> init() async {
    loader = DriveMediaLoader(
      aesKeyBase64: XAuth.instance.key!,
      folderId: XAuth.instance.folderId!,
      accessToken: XAuth.instance.accessToken!,
    );
    allMetadata = await utils.loadAllMetadata();
    loadNextWindow();
  }

  void loadNextWindow() {
    if (isLoading || currentStartIndex >= allMetadata.length) return;

    setState(() => isLoading = true);

    final endIndex = (currentStartIndex + pageSize).clamp(0, allMetadata.length);
    final nextPage = allMetadata.sublist(currentStartIndex, endIndex);
    visibleMedia.addAll(nextPage);

    loader.decryptFilesSequentially(
      nextPage,
      (int index, Uint8List? thumbBytes) {
        if (!mounted) return;
        final media = nextPage[index];
        setState(() {
          decryptedMedia[media.fileId] = thumbBytes!;
        });
      },
    );

    setState(() {
      currentStartIndex += pageSize;
      isLoading = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      loadNextWindow();
    }
  }

  Future<void> refreshNewMedia() async {
    final updatedMetadata = await utils.loadAllMetadata();
    final newMedia = updatedMetadata
        .where((meta) => !allMetadata.any((existing) => existing.fileId == meta.fileId))
        .toList();

    if (newMedia.isNotEmpty) {
      setState(() {
        allMetadata.insertAll(0, newMedia);
        visibleMedia.insertAll(0, newMedia.take(pageSize));
        currentStartIndex += newMedia.length;
      });

      loader.decryptFilesSequentially(
        newMedia.take(pageSize).toList(),
        (int index, Uint8List? thumbBytes) {
          if (!mounted) return;
          setState(() {
            decryptedMedia[newMedia[index].fileId] = thumbBytes!;
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XSpace')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              controller: _scrollController,
              itemCount: visibleMedia.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final media = visibleMedia[index];
                final bytes = decryptedMedia[media.fileId];

                return GestureDetector(
                  onTap: () {
                    final enrichedMediaList = visibleMedia.map((media) {
                      return MediaFile(
                        fileId: media.fileId,
                        name: media.name,
                        decryptedBytes: decryptedMedia[media.fileId],
                      );
                    }).toList();

                    setState(() {
                      selectedMediaIndex = index;
                    });

                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.9),
                      builder: (_) => FullscreenImageViewer(
                        mediaList: enrichedMediaList,
                        initialIndex: index,
                        onDelete: (currentIndex) async {
                          final fileId = visibleMedia[currentIndex].fileId;
                          await utils.deleteMediaFromDrive(fileId);
                          setState(() {
                            decryptedMedia.remove(fileId);
                            visibleMedia.removeAt(currentIndex);
                            selectedMediaIndex = null;
                          });
                        },
                        onClose: () {
                          setState(() {
                            selectedMediaIndex = null;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.cover)
                          : Container(color: Colors.grey[300]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final mediaFile = await utils.pickMedia();
          if (mediaFile != null) {
            await utils.handleMediaUpload(
              XAuth.instance.accessToken!,
              XAuth.instance.folderId!,
              XAuth.instance.key!,
              mediaFile,
            );
            await refreshNewMedia();
          }
        },
        child: const Icon(Icons.cloud_upload),
      ),
    );
  }
}
