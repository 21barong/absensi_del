// lib/services/api_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart'
    as http; // Pastikan import http ini ada di sini!
import 'package:absensi_del/models/student_data.dart';
import 'package:absensi_del/models/attendance_record.dart'; // Untuk AttendanceMode

class ApiService {
  // GANTI DENGAN IP LOKAL SERVER BACKEND ANDA
  // Contoh: 'http://192.168.1.10:3000'
  // Pastikan firewall tidak memblokir port
  final String _baseUrl =
      'http://192.168.247.209:3000/api'; // <--- GANTI INI DENGAN IP/URL SERVER BACKEND ANDA!

  // Metode untuk mendaftarkan mahasiswa baru
  Future<Map<String, dynamic>> registerStudent(
    StudentData student,
    File imageFile,
    String facesetToken,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/students/register'),
      );
      request.fields['nim'] = student.nim;
      request.fields['fullName'] = student.fullName;
      request.fields['programStudi'] = student.programStudi;
      request.fields['email'] = student.email;
      request.fields['phoneNumber'] = student.phoneNumber;
      request.fields['facesetToken'] =
          facesetToken; // Kirim facesetToken ke backend

      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);
      final Map<String, dynamic> data = jsonDecode(responseData.body);

      if (responseData.statusCode == 201) {
        // 201 Created
        return {
          'success': true,
          'message': data['message'],
          'faceToken': data['faceToken'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error ${responseData.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    } finally {
      if (await imageFile.exists()) {
        await imageFile.delete(); // Hapus file sementara
      }
    }
  }

  // Metode untuk melakukan scan kehadiran
  Future<Map<String, dynamic>> scanAttendance(
    File imageFile,
    AttendanceMode mode,
    String facesetToken,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/attendance/scan'),
      );
      request.fields['scan_type'] = mode == AttendanceMode.masuk ? 'in' : 'out';
      request.fields['facesetToken'] =
          facesetToken; // Kirim facesetToken ke backend

      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );

      var response = await request.send();
      var responseData = await http.Response.fromStream(response);
      final Map<String, dynamic> data = jsonDecode(responseData.body);

      if (responseData.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'nim': data['nim'],
          'studentName': data['studentName'],
          'type': data['type'],
          'timestamp': data['timestamp'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error ${responseData.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    } finally {
      if (await imageFile.exists()) {
        await imageFile.delete(); // Hapus file sementara
      }
    }
  }

  // Metode untuk mendapatkan status kehadiran mahasiswa
  Future<Map<String, dynamic>> getAttendanceStatus(String nim) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/attendance/status?nim=$nim'),
      );
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'student': data['student'],
          'attendanceRecords': data['attendanceRecords'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  // --- TAMBAHKAN FUNGSI INI ---
  // Fungsi ini adalah placeholder. Idealnya, backend Anda akan memiliki endpoint
  // yang bisa mengembalikan faceset token jika sudah dibuat, atau membuatnya jika belum.
  // Untuk tujuan demo ini, kita akan membuat sebuah "mock" atau skenario di mana
  // backend mungkin memiliki endpoint sederhana untuk mengembalikan token.
  // ATAU, Anda bisa menginisialisasi _facesetToken langsung di _FaceRecognitionAppState.
  Future<String?> getInitialFaceSetToken() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/faceset/get_token'),
      ); // Memanggil endpoint backend
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Cek 'success' dari respons backend
          return data['facesetToken'];
        } else {
          print(
            'API Service: Backend failed to provide faceset token: ${data['message']}',
          );
          return null;
        }
      } else {
        print(
          'API Service: Failed to get initial faceset token. Status: ${response.statusCode}, Body: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('API Service: Error getting initial faceset token: $e');
      return null;
    }
  }

  // --- AKHIR FUNGSI BARU ---
}
