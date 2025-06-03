import 'dart:convert';
import 'dart:io';
import 'package:camera/src/camera_image.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Face++ API Service ---
class FaceRecognitionService {
  final String apiKey = 'YB0YrYM2Z-nBzB33RMk8fNCeVCx-Z_au';
  final String apiSecret = 'qrSlTO4fhEGC0TxoRS0izzGwVcvusFZO';
  String? _facesetToken; // Cache token in memory

  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  // Save or retrieve faceset token from persistent storage
  Future<String?> getOrCreateFaceSetToken() async {
    if (_facesetToken != null) return _facesetToken;

    // Check persistent storage first (e.g., SharedPreferences or Firestore)
    final tokenFromStorage = await _loadFaceSetTokenFromFirestore();
    if (tokenFromStorage != null) {
      _facesetToken = tokenFromStorage;
      return _facesetToken;
    }

    // Try to get all facesets
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

    // Create new faceset if not found
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

  Future<String?> detectFace(File imageFile) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/detect');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['api_secret'] = apiSecret
      ..files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['faces'] != null && data['faces'].isNotEmpty) {
        return data['faces'][0]['face_token'];
      }
    }
    return null;
  }

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

  Future detectFaceFromCameraImage(CameraImage image) async {}
}
