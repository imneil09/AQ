import 'package:cloud_firestore/cloud_firestore.dart';

class Prescription {
  final String id;
  final String appointmentId;
  final String? patientId; // Links to UserModel
  final String doctorId;
  final List<String> medicines;
  final String notes;
  final String diagnosis;
  final DateTime timestamp;

  Prescription({
    required this.id,
    required this.appointmentId,
    this.patientId,
    required this.doctorId,
    required this.medicines,
    required this.notes,
    required this.diagnosis,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'patientId': patientId,
      'doctorId': doctorId,
      'medicines': medicines,
      'notes': notes,
      'diagnosis': diagnosis,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Prescription.fromMap(Map<String, dynamic> map, String id) {
    return Prescription(
      id: id,
      appointmentId: map['appointmentId'] ?? '',
      patientId: map['patientId'],
      doctorId: map['doctorId'] ?? '',
      medicines: List<String>.from(map['medicines'] ?? []),
      notes: map['notes'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}