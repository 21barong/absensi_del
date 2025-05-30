// lib/pages/scan_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:absensi_del/models/attendance_record.dart'; // Untuk AttendanceMode

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
