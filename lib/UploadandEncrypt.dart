import 'dart:convert';
import 'package:xspace/GoogleAuthClient.dart';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;

class Uploadandencrypt {
   String? akey;
   String? f_Id;
   String? Token;


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
 
  
}


