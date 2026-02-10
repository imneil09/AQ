import 'package:cloud_firestore/cloud_firestore.dart';

// STRICT STATUS ENUM
enum AppointmentStatus { scheduled, waiting, active, skipped, completed, cancelled }

class Appointment {
  final String id;
  final String clinicId;
  final String doctorId;
  final String? userId; // Links to UserModel (Patient ID)
  final String customerName;
  final String phoneNumber;
  final String serviceType;
  final String type; // "live" or "appointment"
  final DateTime appointmentDate;
  final DateTime bookingTimestamp;
  final int tokenNumber;
  AppointmentStatus status;
  DateTime? estimatedTime; // Helper for UI, calculated dynamically in Controller

  Appointment({
    required this.id,
    required this.clinicId,
    required this.doctorId,
    this.userId,
    required this.customerName,
    required this.phoneNumber,
    required this.serviceType,
    required this.type,
    required this.appointmentDate,
    required this.bookingTimestamp,
    required this.tokenNumber,
    this.status = AppointmentStatus.waiting,
    this.estimatedTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'doctorId': doctorId,
      'userId': userId,
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'serviceType': serviceType,
      'type': type,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'bookingTimestamp': Timestamp.fromDate(bookingTimestamp),
      'tokenNumber': tokenNumber,
      'status': status.name,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String docId) {
    DateTime toDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Appointment(
      id: docId,
      clinicId: map['clinicId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      userId: map['userId'],
      customerName: map['customerName'] ?? 'Unknown',
      phoneNumber: map['phoneNumber'] ?? '',
      serviceType: map['serviceType'] ?? 'General',
      type: map['type'] ?? 'live',
      appointmentDate: toDateTime(map['appointmentDate']),
      bookingTimestamp: toDateTime(map['bookingTimestamp']),
      tokenNumber: (map['tokenNumber'] is int) ? map['tokenNumber'] : 0,
      status: AppointmentStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => AppointmentStatus.waiting,
      ),
    );
  }
}