// lib/models/attendance_record.dart
import 'package:intl/intl.dart'; // Pastikan intl ada di pubspec.yaml

enum AttendanceMode { masuk, keluar }

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
