
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'kofpvoxr';
  static const String uploadPreset = 'nexaura_posts';

  Uri _uploadUri(String resourceType) {
    return Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
    );
  }

  Future<String> _uploadBytes({
    required Uint8List fileBytes,
    required String fileName,
    required String resourceType,
    required String folder,
    required Function(double progress) onProgress,
  }) async {
    if (fileBytes.isEmpty) {
      throw Exception('Cannot upload an empty file.');
    }

    if (fileName.trim().isEmpty) {
      throw Exception('File name cannot be empty.');
    }

    final request = http.MultipartRequest(
      'POST',
      _uploadUri(resourceType),
    );

    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = folder;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );

    onProgress(0);

    final streamedResponse = await request.send();
    final responseBody =
        await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200 ||
        streamedResponse.statusCode == 201) {
      final data = jsonDecode(responseBody);

      final secureUrl = data['secure_url'];

      if (secureUrl is! String || secureUrl.isEmpty) {
        throw Exception('Cloudinary returned an invalid URL.');
      }

      onProgress(1);
      return secureUrl;
    }

    throw Exception(
      'Cloudinary Upload Failed: '
      '${streamedResponse.statusCode} - $responseBody',
    );
  }

  // =====================================================
  // IMAGE UPLOAD
  // =====================================================

  Future<String> uploadImage({
    required Uint8List imageBytes,
    required String fileName,
    required Function(double progress) onProgress,
    String folder = 'nexaura/posts',
  }) {
    return _uploadBytes(
      fileBytes: imageBytes,
      fileName: fileName,
      resourceType: 'image',
      folder: folder,
      onProgress: onProgress,
    );
  }

  // =====================================================
  // AUDIO UPLOAD FROM BYTES
  // =====================================================

  Future<String> uploadAudioBytes({
    required Uint8List audioBytes,
    required String fileName,
    required Function(double progress) onProgress,
    String folder = 'nexaura/audio',
  }) {
    return _uploadBytes(
      fileBytes: audioBytes,
      fileName: fileName,
      resourceType: 'video',
      folder: folder,
      onProgress: onProgress,
    );
  }

  // =====================================================
  // AUDIO UPLOAD FROM FILE PATH
  // =====================================================

  Future<String> uploadAudio({
    required String filePath,
    required String fileName,
    required Function(double progress) onProgress,
  }) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('Audio file not found.');
    }

    if (await file.length() == 0) {
      throw Exception('Audio file is empty.');
    }

    final request = http.MultipartRequest(
      'POST',
      _uploadUri('video'),
    );

    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'nexaura/audio';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ),
    );

    onProgress(0);

    final streamedResponse = await request.send();
    final responseBody =
        await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200 ||
        streamedResponse.statusCode == 201) {
      final data = jsonDecode(responseBody);

      final secureUrl = data['secure_url'];

      if (secureUrl is! String || secureUrl.isEmpty) {
        throw Exception('Cloudinary returned an invalid audio URL.');
      }

      onProgress(1);
      return secureUrl;
    }

    throw Exception(
      'Cloudinary Audio Upload Failed: '
      '${streamedResponse.statusCode} - $responseBody',
    );
  }

  // =====================================================
  // VIDEO UPLOAD
  // =====================================================

  Future<String> uploadVideo({
    required Uint8List videoBytes,
    required String fileName,
    required Function(double progress) onProgress,
    String folder = 'nexaura/videos',
  }) {
    return _uploadBytes(
      fileBytes: videoBytes,
      fileName: fileName,
      resourceType: 'video',
      folder: folder,
      onProgress: onProgress,
    );
  }

  // =====================================================
  // DOCUMENT UPLOAD
  // =====================================================

  Future<String> uploadDocument({
    required Uint8List documentBytes,
    required String fileName,
    required Function(double progress) onProgress,
  }) {
    return _uploadBytes(
      fileBytes: documentBytes,
      fileName: fileName,
      resourceType: 'raw',
      folder: 'nexaura/documents',
      onProgress: onProgress,
    );
  }
}
