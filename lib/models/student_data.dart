// lib/models/student_data.dart
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
