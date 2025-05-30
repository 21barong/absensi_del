// lib/pages/status_page.dart
import 'package:flutter/material.dart';
import 'package:absensi_del/models/student_data.dart';
import 'package:absensi_del/models/attendance_record.dart';
import 'package:absensi_del/services/api_service.dart';

class StatusPage extends StatefulWidget {
  // registeredStudents dan attendanceRecords di sini masih dari parent untuk demo lokal
  // Dalam aplikasi nyata, data ini akan diambil langsung dari backend melalui apiService.
  final Map<String, StudentData> registeredStudents;
  final List<AttendanceRecord> attendanceRecords;
  final ApiService apiService; // ApiService untuk memanggil API backend

  const StatusPage({
    super.key,
    required this.registeredStudents,
    required this.attendanceRecords,
    required this.apiService,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final TextEditingController _nimStatusController = TextEditingController();
  List<AttendanceRecord> _filteredRecords = [];
  StudentData? _searchedStudent;
  bool _isLoading = false;
  String _statusMessage = 'Masukkan NIM untuk melihat status kehadiran.';

  @override
  void initState() {
    super.initState();
    _filteredRecords =
        widget.attendanceRecords; // Awalnya tampilkan semua dari cache lokal
  }

  @override
  void dispose() {
    _nimStatusController.dispose();
    super.dispose();
  }

  void _checkStatus() async {
    final nimToSearch = _nimStatusController.text.trim();
    if (nimToSearch.isEmpty) {
      setState(() {
        _filteredRecords = [];
        _searchedStudent = null;
        _statusMessage = 'Masukkan NIM untuk melihat status kehadiran.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan NIM untuk cek status.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Mencari data...';
      _filteredRecords = []; // Kosongkan tampilan lama
      _searchedStudent = null;
    });

    try {
      final response = await widget.apiService.getAttendanceStatus(nimToSearch);

      if (response['success'] == true) {
        final Map<String, dynamic> studentData = response['student'];
        final List<dynamic> recordsData = response['attendanceRecords'];

        final student = StudentData.fromMap(studentData);
        final List<AttendanceRecord> records = recordsData.map((record) {
          return AttendanceRecord(
            nim: student.nim,
            studentName: student.fullName,
            timestamp: DateTime.parse(record['timestamp']),
            type: record['type'] == 'in'
                ? AttendanceMode.masuk
                : AttendanceMode.keluar,
          );
        }).toList();

        setState(() {
          _searchedStudent = student;
          _filteredRecords = records;
          _statusMessage = records.isEmpty
              ? 'Tidak ada riwayat kehadiran untuk ${student.fullName}.'
              : 'Riwayat kehadiran untuk ${student.fullName}:';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data kehadiran untuk ${student.fullName} ditemukan.',
            ),
          ),
        );
      } else {
        setState(() {
          _filteredRecords = [];
          _searchedStudent = null;
          _statusMessage = response['message'] ?? 'Gagal cek status.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cek status: ${response['message']}')),
        );
      }
    } catch (e) {
      setState(() {
        _filteredRecords = [];
        _searchedStudent = null;
        _statusMessage = 'Terjadi kesalahan jaringan: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan jaringan: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                    setState(() {
                      _filteredRecords = [];
                      _searchedStudent = null;
                      _statusMessage =
                          'Masukkan NIM untuk melihat status kehadiran.';
                    });
                  },
                ),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _checkStatus(),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
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
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredRecords.length,
                itemBuilder: (context, index) {
                  final record = _filteredRecords[index];
                  // Gunakan _searchedStudent jika tersedia, atau fallback ke data record
                  final studentName = record.studentName;
                  final studentNim = record.nim;
                  final studentProdi = _searchedStudent?.programStudi ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nama: $studentName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text('NIM: $studentNim'),
                          Text('Program Studi: $studentProdi'),
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
