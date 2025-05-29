import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Face Recognition App', home: FaceDetectPage());
  }
}

class FaceDetectPage extends StatefulWidget {
  @override
  _FaceDetectPageState createState() => _FaceDetectPageState();
}

class _FaceDetectPageState extends State<FaceDetectPage> {
  File? _image;
  String _result = "";

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = "Memproses...";
      });
      final resized = await resizeImage(_image!);
      if (resized != null) {
        await detectFace(resized);
      } else {
        setState(() => _result = "❌ Gagal resize gambar");
      }
    }
  }

  /// Fungsi resize gambar
  Future<File?> resizeImage(
    File file, {
    int maxWidth = 1024,
    int quality = 85,
  }) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(
      dir.path,
      "resized_${path.basename(file.path)}",
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
      keepExif: true,
    );

    // Konversi XFile? ke File?
    return result?.path != null ? File(result!.path) : null;
  }

  Future<void> detectFace(File imageFile) async {
    try {
      var uri = Uri.parse("https://api-us.faceplusplus.com/facepp/v3/detect");

      var request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = 'YB0YrYM2Z-nBzB33RMk8fNCeVCx-Z_au'
        ..fields['api_secret'] = 'qrSlTO4fhEGC0TxoRS0izzGwVcvusFZO'
        ..fields['return_attributes'] = 'gender,age,emotion,smile'
        ..files.add(
          await http.MultipartFile.fromPath('image_file', imageFile.path),
        );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);

        if (data['faces'].isNotEmpty) {
          final face = data['faces'][0];
          final attributes = face['attributes'];
          final gender = attributes['gender']['value'];
          final age = attributes['age']['value'];
          final emotion = attributes['emotion'];
          final smiling = attributes['smile']['value'] as num;

          final topEmotion = emotion.entries.reduce(
            (a, b) => (a.value as num) > (b.value as num) ? a : b,
          );

          setState(() {
            _result =
                '''
✅ Wajah terdeteksi
👤 Gender: $gender
🎂 Usia: $age
😊 Senyum: ${smiling.toStringAsFixed(2)}
😄 Emosi dominan: ${topEmotion.key} (${(topEmotion.value as num).toStringAsFixed(2)})
''';
          });
        } else {
          setState(() {
            _result = "❌ Tidak ada wajah terdeteksi.";
          });
        }
      } else {
        setState(() {
          _result = "❌ Gagal: ${response.statusCode}\n$responseBody";
        });
      }
    } catch (e) {
      setState(() {
        _result = "❌ Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Face Recognition")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _image != null
                ? Image.file(_image!)
                : Placeholder(fallbackHeight: 200),
            SizedBox(height: 20),
            Text(_result),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: pickImage,
              child: Text("Ambil Gambar Wajah"),
            ),
          ],
        ),
      ),
    );
  }
}
