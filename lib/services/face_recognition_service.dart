import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  final String apiKey = 'YB0YrYM2Z-nBzB33RMk8fNCeVCx-Z_au';
  final String apiSecret = 'qrSlTO4fhEGC0TxoRS0izzGwVcvusFZO';
  String? _facesetToken;

  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  // === FACESET HANDLING ===
  Future<String?> getOrCreateFaceSetToken() async {
    if (_facesetToken != null) return _facesetToken;

    final tokenFromStorage = await _loadFaceSetTokenFromFirestore();
    if (tokenFromStorage != null) {
      _facesetToken = tokenFromStorage;
      return _facesetToken;
    }

    final listUri = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/faceset/getfacesets',
    );
    final responseList = await http.post(
      listUri,
      body: {'api_key': apiKey, 'api_secret': apiSecret},
    );

    if (responseList.statusCode == 200) {
      final data = jsonDecode(responseList.body);
      final facesets = data['facesets'] as List<dynamic>?;
      if (facesets != null) {
        for (var fs in facesets) {
          if (fs['display_name'] == 'AttendanceAppSet') {
            _facesetToken = fs['faceset_token'];
            await _saveFaceSetTokenToFirestore(_facesetToken!);
            return _facesetToken;
          }
        }
      }
    }

    // Create new if not found
    final createUri = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/faceset/create',
    );
    final responseCreate = await http.post(
      createUri,
      body: {
        'api_key': apiKey,
        'api_secret': apiSecret,
        'display_name': 'AttendanceAppSet',
      },
    );

    if (responseCreate.statusCode == 200) {
      final data = jsonDecode(responseCreate.body);
      _facesetToken = data['faceset_token'];
      await _saveFaceSetTokenToFirestore(_facesetToken!);
      return _facesetToken;
    } else {
      print('FaceSet creation failed: ${responseCreate.body}');
      return null;
    }
  }

  // === FACE DETECTION ===
  Future<String?> detectFace(File imageFile) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/detect');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['api_secret'] = apiSecret
      ..files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );

    final response = await http.Response.fromStream(await request.send());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['faces'] != null && data['faces'].isNotEmpty) {
        return data['faces'][0]['face_token'];
      }
    }
    return null;
  }

  // === ADD FACE ===
  Future<bool> addFace(String faceToken, String userId) async {
    final facesetToken = await getOrCreateFaceSetToken();
    if (facesetToken == null) return false;

    final uri = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/faceset/addface',
    );
    final response = await http.post(
      uri,
      body: {
        'api_key': apiKey,
        'api_secret': apiSecret,
        'faceset_token': facesetToken,
        'face_tokens': faceToken,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['face_added'] == 1) {
        return await setUserId(faceToken, userId);
      }
    }
    return false;
  }

  Future<bool> setUserId(String faceToken, String userId) async {
    final uri = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/face/setuserid',
    );
    final response = await http.post(
      uri,
      body: {
        'api_key': apiKey,
        'api_secret': apiSecret,
        'face_token': faceToken,
        'user_id': userId,
      },
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>?> searchFace(String faceToken) async {
    final facesetToken = await getOrCreateFaceSetToken();
    if (facesetToken == null) return null;

    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/search');
    final response = await http.post(
      uri,
      body: {
        'api_key': apiKey,
        'api_secret': apiSecret,
        'face_token': faceToken,
        'faceset_token': facesetToken,
        'return_result_count': '1',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        return results[0];
      }
    }
    return null;
  }

  // === SAVE & LOAD FACESET TOKEN ===
  Future<void> _saveFaceSetTokenToFirestore(String token) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('face_config').doc('config').set({
      'faceset_token': token,
    }, SetOptions(merge: true));
  }

  Future<String?> _loadFaceSetTokenFromFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('face_config')
        .doc('config')
        .get();
    return snapshot.exists && snapshot.data() != null
        ? snapshot.data()!['faceset_token']
        : null;
  }

  // === DETECT FROM CAMERA IMAGE ===
  Future<String?> detectFaceFromCameraImage(CameraImage image) async {
    try {
      final file = await _convertCameraImageToFile(image);
      return await detectFace(file);
    } catch (e) {
      print('Error converting CameraImage to File: $e');
      return null;
    }
  }

  Future<File> _convertCameraImageToFile(CameraImage image) async {
    // Convert YUV to RGB (assuming image format is YUV420)
    final img.Image convertedImage = _convertYUV420toImage(image);

    // Encode to JPEG
    final jpegData = img.encodeJpg(convertedImage);
    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/camera_temp.jpg';

    final file = File(imagePath);
    await file.writeAsBytes(jpegData);
    return file;
  }

  img.Image _convertYUV420toImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgBuffer = img.Image(width: width, height: height);

    final y = image.planes[0].bytes;
    final u = image.planes[1].bytes;
    final v = image.planes[2].bytes;

    int uvRowStride = image.planes[1].bytesPerRow;
    int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        int uvIndex = uvPixelStride * (w ~/ 2) + uvRowStride * (h ~/ 2);
        int yIndex = h * width + w;

        final yp = y[yIndex];
        final up = u[uvIndex];
        final vp = v[uvIndex];

        final r = (yp + 1.402 * (vp - 128)).clamp(0, 255).toInt();
        final g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yp + 1.772 * (up - 128)).clamp(0, 255).toInt();

        imgBuffer.setPixelRgb(w, h, r, g, b);
      }
    }

    return imgBuffer;
  }
}
