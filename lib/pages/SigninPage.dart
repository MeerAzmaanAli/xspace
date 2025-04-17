import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:xspace/GoogleAuthClient.dart';
import 'package:xspace/pages/HomePage.dart';
import 'dart:convert';
import 'dart:math';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:xspace/pages/app_lock.dart';

String generateAESKey() {
  final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return base64UrlEncode(key); // 256-bit AES key
}


class SigninPage extends StatelessWidget{
  const SigninPage({super.key});
 Future<String?> getOrCreateFolder(String folderName, String accessToken) async {
  try {
    final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
    final driveApi = drive.DriveApi(client);

    // Search for the folder
    final searchResult = await driveApi.files.list(
      q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)', // Only fetch necessary fields
    );

    if (searchResult.files != null && searchResult.files!.isNotEmpty) {
      final existingFolder = searchResult.files!.first;
      print("Folder already exists: ${existingFolder.name} (${existingFolder.id})");
      return existingFolder.id;
    }

    // Folder doesn't exist - create it
    final folderMetadata = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await driveApi.files.create(folderMetadata);
    print("Folder created: ${createdFolder.id}");
    return createdFolder.id;
  } catch (e) {
    print("Error in getOrCreateFolder: $e");
    return null;
  }
}

  Future<void> _signInWithGoogle(BuildContext context) async {
  try {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/drive.appdata',
      ],
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);

    final driveAccessToken = googleAuth.accessToken!;
    final authHeaders = {
      'Authorization': 'Bearer $driveAccessToken',
      'X-Goog-AuthUser': '0',
    };

    final client = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(client);

    // Step 1: Check if encryption key exists
   final fileList = await driveApi.files.list(
      q: "name = 'xspace_key_bundle.txt' and trashed = false",
      spaces: 'appDataFolder',
    );

    drive.File? keyFile;
    try {
      keyFile = fileList.files?.firstWhere((f) => f.name == 'xspace_key_bundle.txt');
    } catch (e) {
      keyFile = null;
    }

    late String aesKey;

    if (keyFile == null) {
      // Step 2: Create a new key
     final folderId = await getOrCreateFolder("XSpaceVault", driveAccessToken);
      aesKey = generateAESKey();

      final bundleContent = '$aesKey\n$folderId';

      final media = drive.Media(
        Stream.value(utf8.encode(bundleContent)),
        bundleContent.length,
      );
     final drive.File fileMeta = drive.File()
        ..name = 'xspace_key_bundle.txt'
        ..parents = ['appDataFolder'];


      await driveApi.files.create(fileMeta, uploadMedia: media);
      print('Key bundle created and uploaded.');
      print(folderId);


    } else {
      print('Encryption key found in Drive.');  
    }
    // Now you have `aesKey` to use for encryption/decryption.

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AppLockScreen()),
    );

  } catch (e) {
    print('Error during Google sign-in or key setup: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign in failed')),
    );
  }
 
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Spacer(),
              SizedBox(height: 48),
              Text('XSpace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text(
                'Sign in with your Google account to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed:() => _signInWithGoogle(context),
                //icon: Image.asset('assets/google_icon.png', height: 24),
                label: Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  side: BorderSide(color: Colors.grey),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              Spacer(),
              Text(
                'By continuing, you agree to our Terms & Privacy Policy',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 