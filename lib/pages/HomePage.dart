 import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:xspace/GoogleAuthClient.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart'; // For AES encryption
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:xspace/UploadandEncrypt.dart';
import 'package:xspace/LoadandDecrypt.dart';
import 'package:xspace/pages/FullscreenImageViewer.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {

  String? aesKey;
  String? folderId;
  String? accessToken;
  List<int> keyBytes=[];

  final uploadEncrypt = Uploadandencrypt();
  late DriveMediaLoader loader;
  
  int currentIndex = 0;  // Define currentIndex here
  final batchSize = 10;
  List<MediaFile> mediaFiles = [];
  
  Future<void> loadKeys() async {
    print('loading bundle');
    final bundle = await uploadEncrypt.retrieveKeyBundle();
    if (bundle != null) {
      print('loading keys');
      setState(() {
        aesKey = bundle['aesKey'];
        folderId = bundle['folderId'];
        accessToken= bundle['accessToken'];
      });
      keyBytes = base64Decode(aesKey.toString());
      print(' keys loaded');
    } else {
      print('Failed to load encryption key or folder ID');
    }
  }

Future<void> deleteMediaFromDrive(String fileId) async {
  try {
    final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
    final driveApi = drive.DriveApi(client);
    await driveApi.files.delete(fileId);
    print('Deleted file: $fileId');
  } catch (e) {
    print('Error deleting: $e');
  }
}
 
 
  final List<String> imageUrls = [
    // Add your image paths or URLs here
    'https://picsum.photos/200/300',
    'https://picsum.photos/201/300',
    'https://picsum.photos/202/300',
    'https://picsum.photos/203/300',
    'https://picsum.photos/204/300',
    'https://picsum.photos/205/300',
  ];

  // Function to pick media (image/video)
  Future<File?> pickMedia() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }
void refreshMedia() {
    loadMedia();  // Calls the loadMedia method to refresh the images
  }
@override
  void initState () {
    super.initState();
    init();
  }
  Future<void> init() async {
  await loadKeys(); // wait until keys are loaded
  await loadMedia(); // now safe to use keys
}
  Future loadMedia() async {
  final loader = DriveMediaLoader(
    aesKeyBase64: aesKey.toString(),
    folderId: folderId.toString(),
    accessToken: accessToken.toString(),
  );
  final previews = await loader.loadThumbnailPreviews();
  setState(() {
    mediaFiles = previews;
  });
}
 
 
 
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('XSpace'),
      ),
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
           itemCount: mediaFiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
            final media = mediaFiles[index];
            return GestureDetector(
              onTap: () async {
                final deletedIndex = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenImageViewer(
                      mediaList: mediaFiles,
                      initialIndex:index,
                      aesKey: aesKey!,
                      accessToken: accessToken!,
                    ),
                  ),
                );
                if (deletedIndex != null) {
                  await deleteMediaFromDrive(media.fileId);
                  setState(() {
                    mediaFiles.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Media deleted')),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: media.thumbnailBytes != null
                    ? Image.memory(media.thumbnailBytes!, fit: BoxFit.cover)
                    : Container(color: Colors.grey),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Step 1: Pick the media
          final File? mediaFile = await pickMedia();
          if (mediaFile == null) {
            // No media selected
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No media selected')),
            );
            return;
          }
         
          await uploadEncrypt.handleMediaUpload(accessToken.toString(), folderId.toString(), aesKey.toString(), mediaFile);
          refreshMedia();
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Media uploaded successfully')),
          );
        },
        child: const Icon(Icons.cloud_upload),
      ),
    );
  }
}