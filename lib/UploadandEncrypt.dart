import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:xspace/GoogleAuthClient.dart';
import 'dart:io';
import 'package:cryptography/cryptography.dart'; // For AES encryption
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:xspace/LoadandDecrypt.dart';
import 'package:xspace/pages/HomePage.dart';


class Uploadandencrypt {
   String? akey;
   String? f_Id;
   String? Token;

  Future<String?> getAccessToken() async {
    print('getting gsign in info');
  final googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.file'],
  );
   print('getting drive scope');
  final account = await googleSignIn.signInSilently();
  if (account == null) return null;

  final auth = await account.authentication;
  return auth.accessToken;
}

Future<Map<String, String>?> retrieveKeyBundle() async {
  print('getting AccessToken');
  final accessToken = await getAccessToken();
  if (accessToken == null) {
    print("User not signed in.");
    return null;
  }

  print('getting client');
  final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
  final driveApi = drive.DriveApi(client);

  try {
    print('getting xspace_key_bundle.txt from appDataFolder');
    final fileList = await driveApi.files.list(
      q: "name = 'xspace_key_bundle.txt' and trashed = false",
      spaces: 'appDataFolder', // Important: Only search inside appDataFolder
      $fields: 'files(id, name)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      print("Key bundle file not found.");
      return null;
    }

    final keyFile = fileList.files!.first;

    final response = await driveApi.files.get(
      keyFile.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    final mediaStream = response as drive.Media;
    final contents = <int>[];

    await for (final chunk in mediaStream.stream) {
      contents.addAll(chunk);
    }

    final decoded = utf8.decode(contents);
    print("Raw key bundle content:\n$decoded");

    final lines = decoded.trim().split('\n');
    if (lines.length < 2) {
      print("Invalid key bundle format. Expected 2 lines (key + ID).");
      return null;
    }

    print('trimming keys');
    final aesKey = lines[0].trim();
    final folderId = lines[1].trim();

    if (aesKey.isEmpty || folderId.isEmpty) {
      print("aesKey or folderId is empty.");
      return null;
    }

    akey = aesKey;
    f_Id = folderId;
    Token = accessToken;

    return {
      'aesKey': aesKey,
      'folderId': folderId,
      'accessToken': accessToken,
    };
  } catch (e, stacktrace) {
    print("Error reading key bundle: $e");
    print(stacktrace);
  }

  return null;
}


  final ImagePicker _picker = ImagePicker();

  // Function to pick media (image/video)
  Future<File?> pickMedia() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

 Future<List<int>> encryptMedia(File mediaFile, String aesKey) async {
  final algorithm = AesGcm.with256bits();
  final secretKey = await algorithm.newSecretKeyFromBytes(base64.decode(aesKey));

  final inputBytes = await mediaFile.readAsBytes();
  final nonce = algorithm.newNonce(); // use a random nonce (RECOMMENDED)

  final secretBox = await algorithm.encrypt(
    inputBytes,
    secretKey: secretKey,
    nonce: nonce,
  );

  // Store nonce + ciphertext + mac
  return nonce + secretBox.cipherText + secretBox.mac.bytes;
}



  // Function to upload the encrypted media to Google Drive
  Future<void> uploadEncryptedMedia(File encryptedFile, String folderId, String accessToken) async {
    try {
      final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
      final driveApi = drive.DriveApi(client);

      // Create the metadata for the file upload
      final fileMetadata = drive.File()
        ..name = path.basename(encryptedFile.path)
        ..parents = [folderId]; // Specify the folder

      final media = drive.Media(
        encryptedFile.openRead(),
        encryptedFile.lengthSync(),
      );

      // Upload the file to Google Drive
      await driveApi.files.create(fileMetadata, uploadMedia: media);
      print("Encrypted media uploaded successfully.");

    } catch (e) {
      print("Error uploading encrypted media: $e");
    }
  }
 

  // Full flow: pick media -> encrypt -> upload
  Future<void> handleMediaUpload(String accessToken, String folderId, String aesKey, File mediaFile) async {
    try {
      // Step 1: Pick the media
      final mediaFile = await pickMedia();
      if (mediaFile == null) {
        print("No media selected.");
        return;
      }

      // Step 2: Encrypt the media
      final encryptedMedia = await encryptMedia(mediaFile, aesKey);

      // Step 3: Save the encrypted media as a new file
      final encryptedMediaFile = File('${mediaFile.path}.encrypted');
      await encryptedMediaFile.writeAsBytes(encryptedMedia);

      // Step 4: Upload the encrypted file to Google Drive
      await uploadEncryptedMedia(encryptedMediaFile, folderId, accessToken);

    } catch (e) {
      print("Error during media upload process: $e");
    }
  }
}


