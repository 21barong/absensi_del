import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:absensi_del/services/face_recognition_service.dart';
import 'package:absensi_del/widgets/face_detection_painter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImagePicker _picker = ImagePicker();

  static const double kampusLat = 2.385682142007954;
  static const double kampusLng = 99.14797941517467;
  static const double allowedRadius = 150.0; // dalam meter

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi tidak diaktifkan.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak secara permanen');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // meter
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180;

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
          const double recommendedThreshold = 75.0;

          print('Confidence: $confidence, User ID: $userId');

          if (confidence != null && confidence >= recommendedThreshold) {
            try {
              final latestSnapshot = await _firestore
                  .collection('attendance')
                  .where('nim', isEqualTo: userId)
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .get();

              if (latestSnapshot.docs.isNotEmpty) {
                final lastType = latestSnapshot.docs.first['type'];
                final isTryingMasuk =
                    _currentAttendanceType == AttendanceType.masuk;

                if ((lastType == 'masuk' && isTryingMasuk) ||
                    (lastType == 'keluar' && !isTryingMasuk)) {
                  setState(() {
                    _scanMessage =
                        '⚠️ Anda sudah ${lastType == 'masuk' ? 'masuk' : 'keluar'}. Silakan ${lastType == 'masuk' ? 'keluar' : 'masuk'} terlebih dahulu.';
                  });
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(_scanMessage)));
                  setState(() {
                    _isLoading = false;
                  });
                  return;
                }
              }

              // Ambil lokasi GPS
              final position = await _getCurrentPosition();
              final distance = _calculateDistance(
                position.latitude,
                position.longitude,
                kampusLat,
                kampusLng,
              );

              if (distance > allowedRadius) {
                setState(() {
                  _scanMessage =
                      '📍 Anda berada di luar area kampus (jarak: ${distance.toStringAsFixed(2)} meter).';
                  _isLoading = false;
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(_scanMessage)));
                return;
              }

              await _firestore.collection('attendance').add({
                'nim': userId,
                'timestamp': FieldValue.serverTimestamp(),
                'type': _currentAttendanceType == AttendanceType.masuk
                    ? 'masuk'
                    : 'keluar',
                'confidence': confidence,
                'location': {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                },
              });

              setState(() {
                _scanMessage =
                    '✅ Wajah cocok! User: $userId (${_currentAttendanceType == AttendanceType.masuk ? "Masuk" : "Keluar"})';
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(_scanMessage)));
              print('Attendance recorded for $userId');
            } catch (e) {
              print('Error recording attendance: $e');
              setState(() {
                _scanMessage = '❌ Terjadi kesalahan saat mencatat kehadiran.';
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(_scanMessage)));
            }
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
