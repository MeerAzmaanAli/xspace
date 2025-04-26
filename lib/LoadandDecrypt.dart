import 'dart:typed_data';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:xspace/GoogleAuthClient.dart';
import 'package:xspace/UploadandEncrypt.dart';

class MediaFile {
  final String fileId;
  final String name;
  Uint8List? decryptedBytes;

  MediaFile({
    required this.fileId,
    required this.name,
    this.decryptedBytes,
  });
}

class DriveMediaLoader {
  final String aesKeyBase64;
  final String folderId;
  final String accessToken;
  final uploadEncrypt = Uploadandencrypt();

  DriveMediaLoader({
    required this.aesKeyBase64,
    required this.folderId,
    required this.accessToken,
  });

  final algorithm = AesGcm.with256bits();

  Future<void> decryptFilesSequentially(List<MediaFile> mediaList, Function(int, Uint8List?) onDecryptionComplete) async {
    final aesKey = base64Url.decode(aesKeyBase64);
    final secretKey = SecretKey(aesKey);

    for (int i = 0; i < mediaList.length; i++) {
      final file = mediaList[i];

      try {
        final response = await http.get(
          Uri.parse("https://www.googleapis.com/drive/v3/files/${file.fileId}?alt=media"),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        final bytes = response.bodyBytes;
        if (bytes.length < 28) continue;

        final nonce = bytes.sublist(0, 12);
        final mac = bytes.sublist(bytes.length - 16);
        final ciphertext = bytes.sublist(12, bytes.length - 16);

        final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
        final clearBytes = await algorithm.decrypt(secretBox, secretKey: secretKey);

        onDecryptionComplete(i, Uint8List.fromList(clearBytes));
      } catch (e) {
        print("Decryption failed for ${file.name}: $e");
        onDecryptionComplete(i, null);
      }
    }
  }

  Future<Uint8List?> decryptFullFile(String fileId) async {
    final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
    final driveApi = drive.DriveApi(client);

    final aesKey = base64Url.decode(aesKeyBase64);
    final secretKey = SecretKey(aesKey);

    try {
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      final media = response as drive.Media;

      final encryptedBytes = await media.stream.fold<BytesBuilder>(
        BytesBuilder(),
        (b, d) => b..add(d),
      ).then((b) => b.takeBytes());

      if (encryptedBytes.length < 28) return null;

      final nonce = encryptedBytes.sublist(0, 12);
      final mac = encryptedBytes.sublist(encryptedBytes.length - 16);
      final ciphertext = encryptedBytes.sublist(12, encryptedBytes.length - 16);

      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(mac),
      );

      final clearBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(clearBytes);
    } catch (e) {
      print("Full decryption failed: $e");
      return null;
    }
  }
}