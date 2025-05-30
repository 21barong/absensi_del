import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart'; // Import ini sudah ada di kode, tapi perlu package di pubspec.yaml

// Variabel global untuk daftar kamera yang tersedia
List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: ${e.code}\nError Message: ${e.description}');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Untuk menyembunyikan banner debug
      home: FaceRecognitionApp(),
    );
  }
}

// Enum untuk mode absensi (masuk/keluar)
enum AttendanceMode { masuk, keluar }

// Enum untuk tab navigasi (TIDAK DIGUNAKAN SECARA LANGSUNG, hanya untuk dokumentasi)
// enum AppTab { register, scan, status }

// --- Model Data ---
class StudentData {
  final String nim;
  final String fullName;
  final String programStudi;
  final String email;
  final String phoneNumber;
  String? faceToken; // faceToken dari Face++

  StudentData({
    required this.nim,
    required this.fullName,
    required this.programStudi,
    required this.email,
    required this.phoneNumber,
    this.faceToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'nim': nim,
      'fullName': fullName,
      'programStudi': programStudi,
      'email': email,
      'phoneNumber': phoneNumber,
      'faceToken': faceToken,
    };
  }

  factory StudentData.fromMap(Map<String, dynamic> map) {
    return StudentData(
      nim: map['nim'],
      fullName: map['fullName'],
      programStudi: map['programStudi'],
      email: map['email'],
      phoneNumber: map['phoneNumber'],
      faceToken: map['faceToken'],
    );
  }
}

class AttendanceRecord {
  final String nim;
  final String studentName;
  final DateTime timestamp;
  final AttendanceMode type; // 'masuk' atau 'keluar'

  AttendanceRecord({
    required this.nim,
    required this.studentName,
    required this.timestamp,
    required this.type,
  });

  String get formattedTimestamp =>
      DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);
}

// --- FaceRecognitionApp (Parent Widget yang mengelola State Global) ---
class FaceRecognitionApp extends StatefulWidget {
  @override
  _FaceRecognitionAppState createState() => _FaceRecognitionAppState();
}

class _FaceRecognitionAppState extends State<FaceRecognitionApp> {
  // PENTING: API Key dan API Secret Anda.
  // Dalam aplikasi PRODUKSI, JANGAN PERNAH menyimpan kunci ini langsung di kode sumber.
  // Gunakan variabel lingkungan atau layanan backend yang aman.
  final apiKey = 'YB0YrYM2Z-nBzB33RMk8fNCeVCx-Z_au';
  final apiSecret = 'qrSlTO4fhEGC0TxoRS0izzGwVcvusFZO';

  String? facesetToken;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Data Global: Mahasiswa terdaftar dan catatan absensi
  Map<String, StudentData> _registeredStudents = {}; // {'NIM': StudentData}
  List<AttendanceRecord> _attendanceRecords = [];

  // PageController untuk PageView
  final PageController _pageController = PageController();
  int _selectedIndex = 0; // Index untuk BottomNavigationBar

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _createFaceSet();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Fungsi Kamera dan Face++ API (Dipindahkan ke Parent State) ---

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      _showSnackBar('Tidak ada kamera yang tersedia di perangkat.');
      return;
    }
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } on CameraException catch (e) {
      _showSnackBar('Gagal menginisialisasi kamera: ${e.description}');
      print('Camera initialization error: $e');
    }
  }

  Future<File?> _captureFrameForProcessing() async {
    if (!_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isTakingPicture) {
      _showSnackBar('Kamera belum siap atau sedang sibuk.');
      return null;
    }

    try {
      final XFile? file = await _cameraController!.takePicture();
      if (file != null) {
        return File(file.path);
      }
      return null;
    } on CameraException catch (e) {
      _showSnackBar('Gagal mengambil gambar: ${e.description}');
      print('Error taking picture: $e');
      return null;
    }
  }

  // Helper function untuk menampilkan SnackBar
  void _showSnackBar(String message) {
    if (mounted) {
      // Pastikan widget masih ada di tree sebelum menampilkan SnackBar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // 1. Fungsi untuk mendeteksi wajah dari gambar
  Future<String?> _detectFace(File imageFile) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/detect');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['api_secret'] = apiSecret
      ..files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );

    try {
      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      if (responseData.statusCode == 200) {
        final data = jsonDecode(responseData.body);
        if (data['faces'] != null && data['faces'].isNotEmpty) {
          return data['faces'][0]['face_token'];
        } else {
          _showSnackBar('Tidak ada wajah terdeteksi dalam gambar.');
          return null;
        }
      } else {
        final errorBody = jsonDecode(responseData.body);
        _showSnackBar(
          'Deteksi wajah gagal: ${errorBody['error_message'] ?? 'Kode: ${responseData.statusCode}'}',
        );
        print('Detect failed: ${responseData.body}');
        return null;
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan saat deteksi wajah: $e');
      print('Detect exception: $e');
      return null;
    } finally {
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    }
  }

  // 2. Fungsi untuk membuat FaceSet
  Future<void> _createFaceSet() async {
    if (facesetToken != null) {
      print('FaceSet sudah ada: $facesetToken');
      _showSnackBar('FaceSet sudah siap!');
      return;
    }

    final uri = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/faceset/create',
    );
    try {
      final response = await http.post(
        uri,
        body: {
          'api_key': apiKey,
          'api_secret': apiSecret,
          'display_name': 'AttendanceAppSet',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          facesetToken = data['faceset_token'];
        });
        _showSnackBar('FaceSet berhasil dibuat!');
        print('FaceSet Created: $facesetToken');
      } else {
        final errorBody = jsonDecode(response.body);
        _showSnackBar(
          'Gagal membuat FaceSet: ${errorBody['error_message'] ?? 'Kode: ${response.statusCode}'}',
        );
        print('Create FaceSet failed: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan saat membuat FaceSet: $e');
      print('Create FaceSet exception: $e');
    }
  }

  // 3. Fungsi untuk menambahkan wajah ke FaceSet
  Future<void> _addFaceToFaceSet(String faceToken, String userId) async {
    if (facesetToken == null) {
      _showSnackBar(
        'FaceSet belum dibuat. Silakan buat FaceSet terlebih dahulu.',
      );
      return;
    }
    final uri = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/faceset/addface',
    );
    try {
      final response = await http.post(
        uri,
        body: {
          'api_key': apiKey,
          'api_secret': apiSecret,
          'faceset_token': facesetToken!,
          'face_tokens': faceToken,
        },
      );

      if (response.statusCode == 200) {
        await _setUserIdForFace(faceToken, userId);
        print('Face added to FaceSet: $userId');
      } else {
        final errorBody = jsonDecode(response.body);
        _showSnackBar(
          'Gagal menambahkan wajah ke FaceSet: ${errorBody['error_message'] ?? 'Kode: ${response.statusCode}'}',
        );
        print('Add Face failed: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan saat menambahkan wajah: $e');
      print('Add Face exception: $e');
    }
  }

  // 4. Fungsi untuk mengatur user_id untuk face_token
  Future<void> _setUserIdForFace(String faceToken, String userId) async {
    final uri = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/face/setuserid',
    );
    try {
      final response = await http.post(
        uri,
        body: {
          'api_key': apiKey,
          'api_secret': apiSecret,
          'face_token': faceToken,
          'user_id': userId,
        },
      );

      if (response.statusCode == 200) {
        print('User ID set for $faceToken to $userId');
      } else {
        final errorBody = jsonDecode(response.body);
        _showSnackBar(
          'Gagal mengatur user ID: ${errorBody['error_message'] ?? 'Kode: ${response.statusCode}'}',
        );
        print('Set user_id failed: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan saat mengatur user ID: $e');
      print('Set user_id exception: $e');
    }
  }

  // 5. Fungsi untuk mencari wajah di FaceSet
  Future<String?> _searchFaceInFaceset(String faceToken) async {
    if (facesetToken == null) {
      _showSnackBar(
        'FaceSet belum dibuat. Silakan buat FaceSet terlebih dahulu.',
      );
      return null;
    }

    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/search');
    try {
      final response = await http.post(
        uri,
        body: {
          'api_key': apiKey,
          'api_secret': apiSecret,
          'face_token': faceToken,
          'faceset_token': facesetToken!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'];

        if (results != null && results.isNotEmpty) {
          final confidence = results[0]['confidence'];
          final userIdFromAPI = results[0]['user_id'];
          final threshold = data['thresholds']['1e-5'];

          if (confidence != null && confidence >= threshold) {
            return userIdFromAPI;
          }
        }
        return null;
      } else {
        final errorBody = jsonDecode(response.body);
        _showSnackBar(
          'Pencarian wajah gagal: ${errorBody['error_message'] ?? 'Kode: ${response.statusCode}'}',
        );
        print('Search failed: ${response.body}');
        return null;
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan saat mencari wajah: $e');
      print('Search exception: $e');
      return null;
    }
  }

  // --- Fungsi yang dipanggil dari halaman anak ---
  void onRegisterStudent(StudentData student) async {
    if (_registeredStudents.containsKey(student.nim)) {
      _showSnackBar('NIM ${student.nim} sudah terdaftar!');
      return;
    }

    _showSnackBar('Mengambil gambar dari kamera...');
    final image = await _captureFrameForProcessing();
    if (image == null) {
      _showSnackBar('Pendaftaran dibatalkan atau kamera tidak siap.');
      return;
    }

    _showSnackBar('Mendeteksi wajah...');
    final faceToken = await _detectFace(image);
    if (faceToken != null) {
      _showSnackBar('Menambahkan wajah ke FaceSet...');
      await _addFaceToFaceSet(faceToken, student.nim);

      setState(() {
        student.faceToken = faceToken; // Simpan faceToken ke data mahasiswa
        _registeredStudents[student.nim] = student;
      });
      _showSnackBar('Mahasiswa ${student.fullName} berhasil didaftarkan!');
      print('Registered student: ${student.toMap()}');
    } else {
      _showSnackBar('Gagal mendaftarkan wajah mahasiswa.');
    }
  }

  void onScanAttendance(AttendanceMode mode) async {
    if (facesetToken == null || _registeredStudents.isEmpty) {
      _showSnackBar('FaceSet belum siap atau belum ada mahasiswa terdaftar.');
      return;
    }

    _showSnackBar(
      'Mengambil gambar dari kamera untuk ${mode == AttendanceMode.masuk ? 'Masuk' : 'Keluar'}...',
    );
    final image = await _captureFrameForProcessing();
    if (image == null) {
      _showSnackBar('Scan dibatalkan atau kamera tidak siap.');
      return;
    }

    _showSnackBar('Mendeteksi wajah...');
    final faceToken = await _detectFace(image);
    if (faceToken != null) {
      _showSnackBar('Mencari kecocokan wajah...');
      final matchedNim = await _searchFaceInFaceset(faceToken);

      if (matchedNim != null && _registeredStudents.containsKey(matchedNim)) {
        final student = _registeredStudents[matchedNim]!;
        setState(() {
          _attendanceRecords.add(
            AttendanceRecord(
              nim: student.nim,
              studentName: student.fullName,
              timestamp: DateTime.now(),
              type: mode,
            ),
          );
        });
        _showSnackBar(
          '✅ ${mode == AttendanceMode.masuk ? 'Selamat Datang' : 'Terima Kasih'}, ${student.fullName}!',
        );
        print('Attendance recorded for ${student.fullName}: ${mode.name}');
      } else {
        _showSnackBar('❌ Wajah tidak terdaftar atau tidak cocok.');
        print('No matching face found during attendance scan.');
      }
    } else {
      _showSnackBar('Tidak dapat mendeteksi wajah untuk scan kehadiran.');
    }
  }

  // --- Fungsi yang dipanggil dari BottomNavigationBar ---
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          RegistrationPage(
            cameraController: _cameraController,
            isCameraInitialized: _isCameraInitialized,
            onRegisterStudent: onRegisterStudent,
          ),
          ScanAttendancePage(
            cameraController: _cameraController,
            isCameraInitialized: _isCameraInitialized,
            onScanAttendance: onScanAttendance,
          ),
          StatusPage(
            registeredStudents: _registeredStudents,
            attendanceRecords: _attendanceRecords,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Register',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Status'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- Halaman Registrasi ---
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

// --- Halaman Scan Kehadiran ---
class ScanAttendancePage extends StatefulWidget {
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final Function(AttendanceMode mode) onScanAttendance;

  const ScanAttendancePage({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.onScanAttendance,
  });

  @override
  State<ScanAttendancePage> createState() => _ScanAttendancePageState();
}

class _ScanAttendancePageState extends State<ScanAttendancePage> {
  AttendanceMode _currentMode = AttendanceMode.masuk;

  void _performScan() {
    widget.onScanAttendance(_currentMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Kehadiran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentMode = AttendanceMode.masuk;
                      });
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Masuk'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentMode == AttendanceMode.masuk
                          ? Colors.blueAccent
                          : Colors.grey[300],
                      foregroundColor: _currentMode == AttendanceMode.masuk
                          ? Colors.white
                          : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentMode = AttendanceMode.keluar;
                      });
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentMode == AttendanceMode.keluar
                          ? Colors.blueAccent
                          : Colors.grey[300],
                      foregroundColor: _currentMode == AttendanceMode.keluar
                          ? Colors.white
                          : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
            ElevatedButton.icon(
              onPressed: _performScan,
              icon: Icon(
                _currentMode == AttendanceMode.masuk
                    ? Icons.login
                    : Icons.logout,
              ),
              label: Text(
                'Scan ${_currentMode == AttendanceMode.masuk ? 'Masuk' : 'Keluar'}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentMode == AttendanceMode.masuk
                    ? Colors.green
                    : Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Petunjuk:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InstructionPoint(text: 'Pastikan wajah Anda terlihat jelas.'),
                _InstructionPoint(
                  text: 'Hindari pencahayaan yang terlalu gelap.',
                ),
                _InstructionPoint(
                  text: 'Lepaskan masker dan penutup wajah lainnya.',
                ),
                _InstructionPoint(
                  text: 'Pastikan wajah Anda berada di dalam lingkaran.',
                ),
                _InstructionPoint(
                  text: 'Jangan gunakan foto atau gambar wajah.',
                ),
                _InstructionPoint(
                  text:
                      'Jangan menutupi sebagian wajah dengan tangan atau objek lain.',
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _InstructionPoint extends StatelessWidget {
  final String text;
  const _InstructionPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.black),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// --- Halaman Status Kehadiran ---
class StatusPage extends StatefulWidget {
  final Map<String, StudentData> registeredStudents;
  final List<AttendanceRecord> attendanceRecords;

  const StatusPage({
    super.key,
    required this.registeredStudents,
    required this.attendanceRecords,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final TextEditingController _nimStatusController = TextEditingController();
  List<AttendanceRecord> _filteredRecords = [];

  @override
  void initState() {
    super.initState();
    _filteredRecords = widget.attendanceRecords; // Tampilkan semua awalnya
  }

  @override
  void dispose() {
    _nimStatusController.dispose();
    super.dispose();
  }

  void _checkStatus() {
    final nimToSearch = _nimStatusController.text.trim().toLowerCase();
    setState(() {
      if (nimToSearch.isEmpty) {
        _filteredRecords =
            widget.attendanceRecords; // Tampilkan semua jika kosong
      } else {
        _filteredRecords = widget.attendanceRecords
            .where((record) => record.nim.toLowerCase() == nimToSearch)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status Kehadiran')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nimStatusController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Masukkan NIM',
                hintText: 'Cari berdasarkan NIM',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _nimStatusController.clear();
                    _checkStatus();
                  },
                ),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _checkStatus(), // Cek saat enter ditekan
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _checkStatus,
              icon: const Icon(Icons.search),
              label: const Text('Cek Status Kehadiran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _filteredRecords.isEmpty
                  ? Center(
                      child: Text(
                        _nimStatusController.text.isEmpty
                            ? 'Belum ada data kehadiran.'
                            : 'Tidak ada data kehadiran untuk NIM "${_nimStatusController.text}".',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = _filteredRecords[index];
                        final student =
                            widget.registeredStudents[record
                                .nim]; // Ambil data mahasiswa dari parent
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nama: ${record.studentName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text('NIM: ${record.nim}'),
                                if (student != null)
                                  Text(
                                    'Program Studi: ${student.programStudi}',
                                  ),
                                Text('Waktu: ${record.formattedTimestamp}'),
                                Text(
                                  'Tipe: ${record.type == AttendanceMode.masuk ? 'Masuk' : 'Keluar'}',
                                  style: TextStyle(
                                    color: record.type == AttendanceMode.masuk
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
