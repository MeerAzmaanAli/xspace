import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:image_picker/image_picker.dart';
import 'package:xspace/GoogleAuthClient.dart';
import 'package:xspace/LoadandDecrypt.dart';
import 'package:xspace/xauth.dart';
import 'package:xspace/uploadandencrypt.dart';


class Utils{
  final Uploadandencrypt encrypter = Uploadandencrypt();
  final DriveMediaLoader loader = DriveMediaLoader(
      aesKeyBase64: XAuth.instance.key!,
      folderId: XAuth.instance.folderId!,
      accessToken: XAuth.instance.accessToken!);

  Future<File?> pickMedia() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  Future<void> deleteMediaFromDrive(String fileId) async {
    final client = GoogleAuthClient({'Authorization': 'Bearer ${XAuth.instance.accessToken}'});
    final driveApi = drive.DriveApi(client);
    await driveApi.files.delete(fileId);
  }

  Future<List<MediaFile>> loadAllMetadata() async {
      List<MediaFile>  allMetadata;
      final client = GoogleAuthClient({'Authorization': 'Bearer ${XAuth.instance.accessToken}'});
      final driveApi = drive.DriveApi(client);

      final response = await driveApi.files.list(
        q: "'${XAuth.instance.folderId}' in parents and trashed = false",
        $fields: 'files(id, name)',
        spaces: 'drive',
      );

      final files = response.files ?? [];
      allMetadata = files.map((file) {
          return MediaFile(
            fileId: file.id!,
            name: file.name ?? 'Unnamed',
          );
        }).toList();

      return allMetadata;
  }

  Future<void> handleMediaUpload(String accessToken, String folderId, String aesKey, File file) async {
    try {
      // Step 1: Pick the media
      final mediaFile = file;
      if (mediaFile == null) {
        print("No media selected.");
        return;
      }

      // Step 2: Encrypt the media
      final encryptedMedia = await encrypter.encryptMedia(mediaFile, aesKey);

      // Step 3: Save the encrypted media as a new file
      final encryptedMediaFile = File('${mediaFile.path}.encrypted');
      await encryptedMediaFile.writeAsBytes(encryptedMedia);

      // Step 4: Upload the encrypted file to Google Drive
      await encrypter.uploadEncryptedMedia(encryptedMediaFile, folderId, accessToken);

    } catch (e) {
      print("Error during media upload process: $e");
    }
  }
 
}