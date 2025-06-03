import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- Status Page ---
class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

// ... di dalam _StatusPageState
class _StatusPageState extends State<StatusPage> {
  final TextEditingController _nimController = TextEditingController();
  List<Map<String, String>> _attendanceHistory = [];
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Inisialisasi Firestore
  bool _isLoadingStatus = false;

  Future<void> _searchAttendance() async {
    final nim = _nimController.text.trim();
    if (nim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon masukkan NIM terlebih dahulu.')),
      );
      return;
    }

    setState(() {
      _isLoadingStatus = true;
      _attendanceHistory = []; // Clear previous results
    });

    try {
      // Ambil data kehadiran dari Firestore
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('nim', isEqualTo: nim)
          .orderBy('timestamp', descending: true)
          .get();

      // Kelompokkan berdasarkan tanggal untuk masuk/keluar
      Map<String, Map<String, String>> dailyAttendance = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        final dateStr = DateFormat('yyyy-MM-dd').format(timestamp);
        final timeStr = DateFormat('HH:mm').format(timestamp);
        final type = data['type'] as String;

        if (!dailyAttendance.containsKey(dateStr)) {
          dailyAttendance[dateStr] = {
            'date': dateStr,
            'time_in': '-',
            'time_out': '-',
          };
        }

        if (type == 'masuk') {
          // Hanya simpan jam masuk pertama untuk hari itu
          if (dailyAttendance[dateStr]!['time_in'] == '-') {
            dailyAttendance[dateStr]!['time_in'] = timeStr;
          }
        } else if (type == 'keluar') {
          // Hanya simpan jam keluar terakhir untuk hari itu
          dailyAttendance[dateStr]!['time_out'] = timeStr;
        }
      }

      setState(() {
        _attendanceHistory = dailyAttendance.values.toList()
          ..sort(
            (a, b) => b['date']!.compareTo(a['date']!),
          ); // Urutkan dari terbaru
      });

      if (_attendanceHistory.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada riwayat kehadiran untuk NIM: $nim'),
          ),
        );
      }
    } catch (e) {
      print('Error fetching attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data kehadiran: $e')),
      );
    } finally {
      setState(() {
        _isLoadingStatus = false;
      });
    }
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
                suffixIcon: _isLoadingStatus
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchAttendance,
                      ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            if (_isLoadingStatus)
              const CircularProgressIndicator()
            else if (_attendanceHistory.isEmpty &&
                _nimController.text.isNotEmpty)
              const Text("Data kehadiran tidak ditemukan.")
            else if (_attendanceHistory
                .isEmpty) // Default state when nothing is searched yet
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
