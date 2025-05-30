// lib/main.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// --- Import file-file Anda dari packages:absensi_mahasiswa ---
import 'package:absensi_del/pages/registration_page.dart';
import 'package:absensi_del/pages/scan_attendance_page.dart';
import 'package:absensi_del/pages/status_page.dart';
import 'package:absensi_del/models/student_data.dart';
import 'package:absensi_del/models/attendance_record.dart';
import 'package:absensi_del/services/api_service.dart';
import 'package:absensi_del/services/camera_service.dart';
// --- AKHIR IMPORTS ---

// ... sisa kode main.dart Anda ...
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: FaceRecognitionApp(),
    );
  }
}

// --- FaceRecognitionApp (Parent Widget yang mengelola State Global) ---
class FaceRecognitionApp extends StatefulWidget {
  @override
  _FaceRecognitionAppState createState() => _FaceRecognitionAppState();
}

class _FaceRecognitionAppState extends State<FaceRecognitionApp> {
  // Instance dari API Service
  late final ApiService _apiService;
  late final CameraService _cameraService;

  // Data Global: Mahasiswa terdaftar dan catatan absensi (masih di lokal untuk demo)
  // CATATAN: Dalam aplikasi nyata, data ini akan diambil dari server.
  // Ini hanya untuk simulasi data di frontend saat backend belum sepenuhnya berjalan.
  Map<String, StudentData> _registeredStudents = {}; // {'NIM': StudentData}
  List<AttendanceRecord> _attendanceRecords = [];

  final PageController _pageController = PageController();
  int _selectedIndex = 0; // Index untuk BottomNavigationBar

  String? _facesetToken; // FaceSet token dari Face++ (didapat dari backend)

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(); // Inisialisasi ApiService
    _cameraService = CameraService(cameras); // Inisialisasi CameraService
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _cameraService.initializeCamera();
    // Panggil API backend untuk mendapatkan faceset token atau membuat jika belum ada
    // Untuk demo ini, kita akan asumsikan backend membuat dan mengelolanya.
    // Jika backend mengembalikan facesetToken saat pertama kali app dijalankan, simpan di sini.
    // Misalnya: _facesetToken = await _apiService.getOrCreateFaceSet();
    // Di sini, kita asumsikan backend sudah mengelola FaceSet dengan ID yang sama.
    // Atau Anda bisa memanggil _apiService.createFaceSet() di sini jika itu tugas frontend.
    // Untuk contoh ini, saya akan pertahankan logika lama untuk memastikan FaceSet dibuat
    // sebagai bagian dari Face++ API (bukan API backend), tetapi idealnya ini juga di backend.
    await _createFaceSetOnFacePlusPlus(); // Memanggil langsung Face++ untuk demo
  }

  // Helper function untuk menampilkan SnackBar
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Fungsi untuk membuat FaceSet (langsung ke Face++ API, idealnya via backend)
  Future<void> _createFaceSetOnFacePlusPlus() async {
    if (_facesetToken != null) {
      print('FaceSet sudah ada: $_facesetToken');
      _showSnackBar('FaceSet sudah siap!');
      return;
    }
    // CATATAN: Idealnya, pembuatan faceset juga dilakukan di backend.
    // Bagian ini hanya untuk demo jika facesetToken belum diatur secara manual di .env backend.
    // Setelah mendapatkan facesetToken dan menyimpannya di .env backend,
    // Anda bisa menghapus panggilan fungsi ini dari initState()
    // atau membuat backend mengembalikan facesetToken di endpoint khusus.

    _showSnackBar('Mencoba membuat/mendapatkan FaceSet dari Face++...');

    // Contoh sederhana untuk mendapatkan facesetToken dari backend jika ada endpoint khusus
    // Atau bisa langsung menggunakan API Key jika masih diperlukan untuk setup awal
    // Untuk tujuan demo ini, kita akan coba memanggil Face++ secara langsung jika belum ada token
    // agar FaceSet bisa terbentuk dan tokennya bisa disalin ke .env
    // Setelah token didapat dan dipindahkan ke .env, bagian ini tidak akan dijalankan lagi karena _facesetToken tidak null.
    final String? initialFaceSetToken = await _apiService
        .getInitialFaceSetToken(); // Anggap ada method di ApiService
    if (initialFaceSetToken != null) {
      setState(() {
        _facesetToken = initialFaceSetToken;
      });
      _showSnackBar('FaceSet sudah siap: $_facesetToken');
    } else {
      _showSnackBar(
        'FaceSet belum bisa diinisialisasi. Pastikan backend berjalan dan token tersedia.',
      );
    }
  }

  // --- Logika yang dipanggil dari halaman Registrasi ---
  void _handleRegisterStudent(StudentData student) async {
    if (_facesetToken == null) {
      _showSnackBar(
        'FaceSet belum siap. Harap tunggu atau buat FaceSet terlebih dahulu.',
      );
      return;
    }
    if (_registeredStudents.containsKey(student.nim)) {
      _showSnackBar('NIM ${student.nim} sudah terdaftar!');
      return;
    }

    _showSnackBar('Mengambil gambar dari kamera...');
    final image = await _cameraService.captureFrame();
    if (image == null) {
      _showSnackBar('Pendaftaran dibatalkan atau kamera tidak siap.');
      return;
    }

    _showSnackBar('Mengirim data pendaftaran ke server...');
    try {
      final response = await _apiService.registerStudent(
        student,
        image,
        _facesetToken!,
      );
      if (response['success'] == true) {
        setState(() {
          student.faceToken = response['faceToken'];
          _registeredStudents[student.nim] = student;
        });
        _showSnackBar('Mahasiswa ${student.fullName} berhasil didaftarkan!');
        print('Registered student: ${student.toMap()}');
      } else {
        _showSnackBar(
          'Gagal daftar: ${response['message'] ?? 'Unknown Error'}',
        );
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan saat mendaftar: $e');
      print('Registration exception: $e');
    }
  }

  // --- Logika yang dipanggil dari halaman Scan Kehadiran ---
  void _handleScanAttendance(AttendanceMode mode) async {
    if (_facesetToken == null || _registeredStudents.isEmpty) {
      _showSnackBar('FaceSet belum siap atau belum ada mahasiswa terdaftar.');
      return;
    }

    _showSnackBar(
      'Mengambil gambar dari kamera untuk ${mode == AttendanceMode.masuk ? 'Masuk' : 'Keluar'}...',
    );
    final image = await _cameraService.captureFrame();
    if (image == null) {
      _showSnackBar('Scan dibatalkan atau kamera tidak siap.');
      return;
    }

    _showSnackBar('Mengirim data scan ke server...');
    try {
      final response = await _apiService.scanAttendance(
        image,
        mode,
        _facesetToken!,
      );
      if (response['success'] == true) {
        final String nim = response['nim'];
        final String studentName = response['studentName'];
        final AttendanceMode type = response['type'] == 'in'
            ? AttendanceMode.masuk
            : AttendanceMode.keluar;
        final DateTime timestamp = DateTime.parse(response['timestamp']);

        setState(() {
          _attendanceRecords.add(
            AttendanceRecord(
              nim: nim,
              studentName: studentName,
              timestamp: timestamp,
              type: type,
            ),
          );
        });
        _showSnackBar('✅ ${response['message']}');
        print('Attendance recorded for ${studentName}: ${type.name}');
      } else {
        _showSnackBar(
          '❌ Gagal scan: ${response['message'] ?? 'Unknown Error'}',
        );
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan jaringan saat scan: $e');
      print('Scan exception: $e');
    }
  }

  // --- Logika yang dipanggil dari halaman Status Kehadiran ---
  // StatusPage akan memanggil ApiService.getAttendanceStatus() langsung.

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
            cameraController: _cameraService.cameraController,
            isCameraInitialized: _cameraService.isInitialized,
            onRegisterStudent: _handleRegisterStudent,
          ),
          ScanAttendancePage(
            cameraController: _cameraService.cameraController,
            isCameraInitialized: _cameraService.isInitialized,
            onScanAttendance: _handleScanAttendance,
          ),
          StatusPage(
            registeredStudents: _registeredStudents, // Untuk tampilan lokal
            attendanceRecords: _attendanceRecords, // Untuk tampilan lokal
            apiService: _apiService, // StatusPage akan memanggil API langsung
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
