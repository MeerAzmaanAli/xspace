import 'dart:typed_data';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:xspace/GoogleAuthClient.dart';
import 'package:xspace/UploadandEncrypt.dart';
import 'package:image/image.dart' as img;

class MediaFile {
  final String fileId;
  final Uint8List? thumbnailBytes; // for preview
  final String name;

  MediaFile({
    required this.fileId,
    required this.name,
    this.thumbnailBytes,
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

  Future<List<MediaFile>> loadThumbnailPreviews() async {
    final accessToken = await uploadEncrypt.getAccessToken();
    final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
    final driveApi = drive.DriveApi(client);

    final encryptedFiles = await driveApi.files.list(
      q: "'$folderId' in parents and trashed = false",
      $fields: 'files(id, name)',
    );

    final aesKey = base64Url.decode(aesKeyBase64);
    final secretKey = SecretKey(aesKey);

    List<MediaFile> thumbnails = [];

    for (var file in encryptedFiles.files ?? []) {
      try {
        // Get only first few KB of the file
        final partialResponse = await http.get(
          Uri.parse("https://www.googleapis.com/drive/v3/files/${file.id}?alt=media"),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Range': 'bytes=0-65535' // adjust if needed
          },
        );

        final partialBytes = partialResponse.bodyBytes;

        if (partialBytes.length < 28) continue;

        final nonce = partialBytes.sublist(0, 12);
        final mac = partialBytes.sublist(partialBytes.length - 16);
        final ciphertext = partialBytes.sublist(12, partialBytes.length - 16);

        final secretBox = SecretBox(
          ciphertext,
          nonce: nonce,
          mac: Mac(mac),
        );

        final clearBytes = await algorithm.decrypt(
          secretBox,
          secretKey: secretKey,
        );

        // Decode image to create a thumbnail
        final original = img.decodeImage(Uint8List.fromList(clearBytes) );
        if (original == null) continue;

        final thumbnail = img.copyResize(original, width: 300);
        final thumbnailBytes = Uint8List.fromList(img.encodeJpg(thumbnail));

        thumbnails.add(MediaFile(
          fileId: file.id!,
          name: file.name ?? 'Unknown',
          thumbnailBytes: thumbnailBytes,
        ));
      } catch (e) {
        print("Thumbnail creation failed for file ${file.name}: $e");
      }
    }

    return thumbnails;
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
