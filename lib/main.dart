import 'package:absensi_del/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Import for date formatting

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Pastikan Flutter binding diinisialisasi
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Kehadiran Mahasiswa',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const RegisterPage(),
    const ScanPage(),
    const StatusPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
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

// --- Face++ API Service ---
class FaceRecognitionService {
  final String apiKey =
      'YB0YrYM2Z-nBzB33RMk8fNCeVCx-Z_au'; // GANTI DENGAN API KEY ANDA
  final String apiSecret =
      'qrSlTO4fhEGC0TxoRS0izzGwVcvusFZO'; // GANTI DENGAN API SECRET ANDA
  String? _facesetToken; // Disimpan sementara di memori

  // Singleton pattern (opsional, bisa juga dibuat instance baru setiap kali)
  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  // Mendapatkan FaceSet Token (atau membuat jika belum ada)
  Future<String?> getOrCreateFaceSetToken() async {
    if (_facesetToken != null) {
      return _facesetToken;
    }

    // Coba dapatkan semua FaceSet
    final uriGetAll = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/faceset/getdetail',
    );
    final responseGetAll = await http.post(
      uriGetAll,
      body: {'api_key': apiKey, 'api_secret': apiSecret},
    );

    if (responseGetAll.statusCode == 200) {
      final data = jsonDecode(responseGetAll.body);
      if (data['facesets'] != null) {
        for (var fs in data['facesets']) {
          if (fs['display_name'] == 'AttendanceAppSet') {
            _facesetToken = fs['faceset_token'];
            print('Existing FaceSet found: $_facesetToken');
            return _facesetToken;
          }
        }
      }
    } else {
      print('Failed to get all facesets: ${responseGetAll.body}');
    }

    // Jika tidak ada atau gagal mendapatkan, buat FaceSet baru
    final uriCreate = Uri.parse(
      'https://api-us.faceplusplus.com/facepp/v3/faceset/create',
    );
    final responseCreate = await http.post(
      uriCreate,
      body: {
        'api_key': apiKey,
        'api_secret': apiSecret,
        'display_name': 'AttendanceAppSet',
      },
    );

    if (responseCreate.statusCode == 200) {
      final data = jsonDecode(responseCreate.body);
      _facesetToken = data['faceset_token'];
      print('FaceSet Created: $_facesetToken');
      return _facesetToken;
    } else {
      print('Create FaceSet failed: ${responseCreate.body}');
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
      } else {
        print('No face detected.');
        return null;
      }
    } else {
      print('Detect failed: ${response.body}');
      return null;
    }
  }

  Future<bool> addFace(String faceToken, String userId) async {
    final facesetToken = await getOrCreateFaceSetToken();
    if (facesetToken == null) {
      print('Failed to get or create faceset token.');
      return false;
    }

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
        // Set user_id immediately after adding face
        return await setUserId(faceToken, userId);
      } else {
        print('Face not added: ${response.body}');
        return false;
      }
    } else {
      print('Add Face failed: ${response.body}');
      return false;
    }
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

    if (response.statusCode == 200) {
      print('User ID "$userId" set for face "$faceToken"');
      return true;
    } else {
      print('Set user_id failed: ${response.body}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> searchFace(String faceToken) async {
    final facesetToken = await getOrCreateFaceSetToken();
    if (facesetToken == null) {
      print('Failed to get or create faceset token.');
      return null;
    }

    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/search');
    final response = await http.post(
      uri,
      body: {
        'api_key': apiKey,
        'api_secret': apiSecret,
        'face_token': faceToken,
        'faceset_token': facesetToken,
        'return_result_count': '1', // Only need the top match
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        return data['results'][0];
      } else {
        print('No matching face found in FaceSet.');
        return null;
      }
    } else {
      print('Search failed: ${response.body}');
      return null;
    }
  }
}

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

      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mahasiswa berhasil didaftarkan!')),
        );
        // Reset form

        _nimController.clear();

        setState(() {
          _imageFile = null;
          _detectedFaceToken = null;
        });
        // TODO: Simpan data mahasiswa ke database lokal/server
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendaftarkan wajah. Mohon coba lagi.'),
          ),
        );
      }
    } else if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon ambil foto wajah terlebih dahulu.'),
        ),
      );
    } else if (_detectedFaceToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wajah belum terdeteksi. Pastikan wajah terlihat jelas.',
          ),
        ),
      );
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

// --- Scan Page ---
enum AttendanceType { masuk, keluar }

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  AttendanceType _currentAttendanceType = AttendanceType.masuk;
  File? _imageFile;
  String? _detectedFaceToken;
  bool _isLoading = false;
  String _scanMessage = '';

  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _scanFace() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _detectedFaceToken = null;
        _isLoading = true;
        _scanMessage = '';
      });

      final faceToken = await _faceService.detectFace(_imageFile!);
      if (faceToken != null) {
        setState(() {
          _detectedFaceToken = faceToken;
        });
        final result = await _faceService.searchFace(faceToken);

        if (result != null) {
          final confidence = result['confidence'];
          final userId = result['user_id'];
          // Ambil threshold dari respons API search (contoh threshold 1e-5)
          // Secara default, API search tidak mengembalikan threshold, Anda perlu menentukannya sendiri
          // atau melihat dokumentasi untuk nilai rekomendasi. Misal kita gunakan 80
          const double recommendedThreshold = 75.0; // Contoh threshold
          print(
            'Confidence: $confidence, User ID: $userId, Threshold: $recommendedThreshold',
          );

          if (confidence != null && confidence >= recommendedThreshold) {
            setState(() {
              _scanMessage =
                  '✅ Wajah cocok! User: $userId (${_currentAttendanceType == AttendanceType.masuk ? "Masuk" : "Keluar"})';
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_scanMessage)));
            // TODO: Simpan data kehadiran (user_id, waktu, jenis_kehadiran) ke database
          } else {
            setState(() {
              _scanMessage =
                  '❌ Wajah tidak cocok atau di bawah ambang batas kepercayaan.';
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_scanMessage)));
          }
        } else {
          setState(() {
            _scanMessage = '❌ Wajah tidak ditemukan di database.';
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_scanMessage)));
        }
      } else {
        setState(() {
          _scanMessage = 'Wajah tidak terdeteksi. Silakan coba lagi.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wajah tidak terdeteksi. Silakan coba lagi.'),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Kehadiran'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentAttendanceType = AttendanceType.masuk;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentAttendanceType == AttendanceType.masuk
                          ? Colors.blueAccent
                          : Colors.grey[300],
                      foregroundColor:
                          _currentAttendanceType == AttendanceType.masuk
                          ? Colors.white
                          : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Masuk'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentAttendanceType = AttendanceType.keluar;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentAttendanceType == AttendanceType.keluar
                          ? Colors.blueAccent
                          : Colors.grey[300],
                      foregroundColor:
                          _currentAttendanceType == AttendanceType.keluar
                          ? Colors.white
                          : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Keluar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 300,
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
                          // Placeholder for face detection overlay
                          Positioned.fill(
                            child: CustomPaint(
                              painter: FaceDetectionPainter(faceDetected: true),
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
                        'Ambil foto untuk scan kehadiran',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _scanFace,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                'Scan ${_currentAttendanceType == AttendanceType.masuk ? "Masuk" : "Keluar"}',
              ),
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
            const Text(
              'Petunjuk:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInstructionPoint('Pastikan wajah Anda terlihat jelas'),
            _buildInstructionPoint('Hindari pencahayaan yang terlalu gelap'),
            _buildInstructionPoint('Lepaskan masker dan penutup wajah lainnya'),
            _buildInstructionPoint(
              'Pastikan wajah Anda berada di dalam lingkaran',
            ),
            _buildInstructionPoint('Jangan gunakan foto atau gambar wajah'),
            _buildInstructionPoint(
              'Jangan menutupi sebagian wajah dengan tangan atau objek lain',
            ),
            const SizedBox(height: 10),
            Text(
              _scanMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _scanMessage.startsWith('✅') ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

// --- Status Page ---
class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final TextEditingController _nimController = TextEditingController();
  List<Map<String, String>> _attendanceHistory =
      []; // Placeholder for attendance data

  void _searchAttendance() {
    final nim = _nimController.text.trim();
    if (nim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon masukkan NIM terlebih dahulu.')),
      );
      return;
    }

    // TODO: Implement logic to fetch attendance data from your backend/database
    // This is just dummy data for demonstration
    setState(() {
      _attendanceHistory = [
        {'date': '2025-05-30', 'time_in': '08:00', 'time_out': '16:00'},
        {'date': '2025-05-29', 'time_in': '08:05', 'time_out': '15:55'},
        {
          'date': '2025-05-28',
          'time_in': '07:58',
          'time_out': '-',
        }, // Contoh belum absen keluar
        {'date': '2025-05-27', 'time_in': '08:10', 'time_out': '17:00'},
      ];
    });

    if (_attendanceHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada riwayat kehadiran untuk NIM: $nim')),
      );
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
        title: const Text('Status Kehadiran'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nimController,
              decoration: InputDecoration(
                labelText: 'Masukkan NIM',
                hintText: 'Masukkan NIM',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchAttendance,
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            if (_attendanceHistory.isEmpty)
              Column(
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cek Status Kehadiran',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Masukkan NIM untuk melihat status dan riwayat kehadiran Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Tanggal',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Jam Masuk',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Jam Keluar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _attendanceHistory.length,
                        itemBuilder: (context, index) {
                          final attendance = _attendanceHistory[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(attendance['date']!),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(attendance['time_in']!),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(attendance['time_out']!),
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
          ],
        ),
      ),
    );
  }
}

// A custom painter for the face detection circle/frame (placeholder)
class FaceDetectionPainter extends CustomPainter {
  final bool faceDetected;

  FaceDetectionPainter({required this.faceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = faceDetected ? Colors.green : Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw the main circle (as seen in the image)
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.4;
    canvas.drawCircle(center, radius, paint);

    // Draw the corner brackets
    final cornerLength = radius * 0.3;
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;

    // Top-left
    canvas.drawLine(
      Offset(halfWidth - radius, halfHeight - radius + cornerLength),
      Offset(halfWidth - radius, halfHeight - radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth - radius + cornerLength, halfHeight - radius),
      Offset(halfWidth - radius, halfHeight - radius),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(halfWidth + radius, halfHeight - radius + cornerLength),
      Offset(halfWidth + radius, halfHeight - radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth + radius - cornerLength, halfHeight - radius),
      Offset(halfWidth + radius, halfHeight - radius),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(halfWidth - radius, halfHeight + radius - cornerLength),
      Offset(halfWidth - radius, halfHeight + radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth - radius + cornerLength, halfHeight + radius),
      Offset(halfWidth - radius, halfHeight + radius),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(halfWidth + radius, halfHeight + radius - cornerLength),
      Offset(halfWidth + radius, halfHeight + radius),
      paint,
    );
    canvas.drawLine(
      Offset(halfWidth + radius - cornerLength, halfHeight + radius),
      Offset(halfWidth + radius, halfHeight + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // Only repaint if properties change
  }
}
