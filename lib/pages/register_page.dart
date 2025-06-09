import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:absensi_del/services/face_recognition_service.dart';
import 'package:absensi_del/widgets/face_detection_painter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nimController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Tambahkan controller baru
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _prodiController = TextEditingController();

  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  String? _detectedFaceToken;
  bool _isLoading = false;

  // 📸 Ambil foto wajah & deteksi face token
  Future<void> _takePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _detectedFaceToken = null;
      _isLoading = true;
    });

    try {
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
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat mendeteksi wajah: $e')),
      );
    }
  }

  // 🔍 Cek apakah NIM sudah terdaftar
  Future<bool> checkIfNIMExists(String nim) async {
    final doc = await _firestore.collection('students').doc(nim).get();
    return doc.exists;
  }

  // 🔍 Cek apakah wajah sudah pernah terdaftar
  Future<bool> checkIfFaceExists(String faceToken) async {
    final result = await _faceService.searchFace(faceToken);
    return result != null &&
        result['confidence'] != null &&
        result['confidence'] > 85;
  }

  // 📝 Daftarkan Mahasiswa
  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate() ||
        _imageFile == null ||
        _detectedFaceToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pastikan semua data dan wajah terisi.')),
      );
      return;
    }

    final String userId = _nimController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 1️⃣ Cek NIM
      if (await checkIfNIMExists(userId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NIM ini sudah terdaftar.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2️⃣ Cek wajah
      if (await checkIfFaceExists(_detectedFaceToken!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wajah ini sudah terdaftar.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3️⃣ Tambahkan wajah ke FaceSet
      final success = await _faceService.addFace(_detectedFaceToken!, userId);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendaftarkan wajah. Coba lagi.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 4️⃣ Simpan ke Firestore
      await _firestore.collection('students').doc(userId).set({
        'nim': userId,
        'name': _nameController.text.trim(),
        'prodi': _prodiController.text.trim(),
        'face_token': _detectedFaceToken,
        'registration_date': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mahasiswa berhasil didaftarkan!')),
      );

      _nameController.clear();
      _prodiController.clear();
      _nimController.clear();
      setState(() {
        _imageFile = null;
        _detectedFaceToken = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat mendaftar: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nimController.dispose();
    _nameController.dispose();
    _prodiController.dispose();

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
              TextFormField(
                controller: _nimController,
                decoration: const InputDecoration(
                  labelText: 'NIM',
                  hintText: 'Masukkan NIM',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'NIM tidak boleh kosong';
                  }
                  if (!RegExp(r'^\d{8}$').hasMatch(value.trim())) {
                    return 'NIM harus terdiri dari 8 digit angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  hintText: 'Masukkan nama lengkap Anda',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prodiController,
                decoration: const InputDecoration(
                  labelText: 'Program Studi',
                  hintText: 'Masukkan program studi',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Program studi tidak boleh kosong';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _registerStudent,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
