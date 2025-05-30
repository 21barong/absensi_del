// lib/pages/registration_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:absensi_del/models/student_data.dart';

class RegistrationPage extends StatefulWidget {
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final Function(StudentData student) onRegisterStudent;

  const RegistrationPage({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.onRegisterStudent,
  });

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  String? _selectedProdi;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final List<String> _programStudiOptions = [
    'Teknik Informatika',
    'Sistem Informasi',
    'Manajemen',
    'Akuntansi',
    'Hukum',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _register() {
    if (_nameController.text.isEmpty ||
        _nimController.text.isEmpty ||
        _selectedProdi == null ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data!')),
      );
      return;
    }

    final student = StudentData(
      nim: _nimController.text.trim(),
      fullName: _nameController.text.trim(),
      programStudi: _selectedProdi!,
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    widget.onRegisterStudent(student);

    // Bersihkan form setelah pendaftaran
    _nameController.clear();
    _nimController.clear();
    _emailController.clear();
    _phoneController.clear();
    setState(() {
      _selectedProdi = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendaftaran Mahasiswa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data Wajah',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  widget.isCameraInitialized &&
                      widget.cameraController != null &&
                      widget.cameraController!.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: widget.cameraController!.value.aspectRatio,
                      child: CameraPreview(widget.cameraController!),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wajah terdeteksi: Pastikan wajah di tengah lingkaran dan pastikan pencahayaan cukup.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Nama Lengkap',
                hintText: 'Masukkan nama lengkap',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nimController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'NIM',
                hintText: 'Masukkan NIM',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProdi,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Program Studi',
              ),
              hint: const Text('Pilih program studi'),
              items: _programStudiOptions.map((String prodi) {
                return DropdownMenuItem<String>(
                  value: prodi,
                  child: Text(prodi),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedProdi = newValue;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Email',
                hintText: 'nama@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Nomor Telepon',
                hintText: '08xxxxxxxxxx',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Daftar'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
