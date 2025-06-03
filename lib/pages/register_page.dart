import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:absensi_del/services/face_recognition_service.dart';
import 'package:absensi_del/widgets/face_detection_painter.dart';

// --- Register Page ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nimController = TextEditingController();
  File? _imageFile;
  String? _detectedFaceToken;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _detectedFaceToken = null; // Reset face token
        _isLoading = true;
      });
      final faceToken = await _faceService.detectFace(_imageFile!);
      setState(() {
        _detectedFaceToken = faceToken;
        _isLoading = false;
      });
      if (faceToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wajah tidak terdeteksi. Silakan coba lagi.'),
          ),
        );
      }
    }
  }

  Future<void> _registerStudent() async {
    if (_formKey.currentState!.validate() &&
        _imageFile != null &&
        _detectedFaceToken != null) {
      setState(() {
        _isLoading = true;
      });

      final String userId = _nimController.text
          .trim(); // Menggunakan NIM sebagai user_id

      final bool success = await _faceService.addFace(
        _detectedFaceToken!,
        userId,
      );

      if (success) {
        try {
          // Simpan data mahasiswa ke Firestore
          await _firestore.collection('students').doc(userId).set({
            'nim': userId,
            'face_token': _detectedFaceToken, // Simpan juga face_token
            'registration_date': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mahasiswa berhasil didaftarkan!')),
          );

          _nimController.clear();
          setState(() {
            _imageFile = null;
            _detectedFaceToken = null;
          });
        } catch (e) {
          print('Error saving student data to Firestore: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan data mahasiswa: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendaftarkan wajah. Mohon coba lagi.'),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    } else {
      // ... pesan error lainnya
    }
  }

  @override
  void dispose() {
    _nimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Mahasiswa'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Data Wajah',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _imageFile != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.file(_imageFile!, fit: BoxFit.cover),
                          if (_detectedFaceToken != null)
                            // Anda bisa menambahkan overlay untuk menunjukkan wajah terdeteksi
                            // Ini adalah placeholder, deteksi wajah sebenarnya dari API tidak mengembalikan koordinat
                            // Anda perlu memparsing 'face_rectangle' dari respons detect jika ingin menggambar kotak
                            Positioned.fill(
                              child: CustomPaint(
                                painter: FaceDetectionPainter(
                                  faceDetected: true,
                                ),
                              ),
                            ),
                          if (_detectedFaceToken == null && !_isLoading)
                            const Text(
                              'Wajah tidak terdeteksi',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (_isLoading) const CircularProgressIndicator(),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Ambil foto wajah Anda',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Ambil Foto Wajah'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Wajah terdeteksi: Posisikan wajah di tengah lingkaran dan pastikan pencahayaan cukup.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nimController,
                decoration: const InputDecoration(
                  labelText: 'NIM',
                  hintText: 'Masukkan NIM',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'NIM tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _registerStudent,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
