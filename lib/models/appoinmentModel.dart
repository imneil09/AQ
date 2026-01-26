import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { waiting, inProgress, completed, cancelled, missed }

class Appointment {
  final String id;
  final String clinicId; // NEW: Link to specific clinic
  final String customerName;
  final String phoneNumber;
  final String serviceType;
  final DateTime appointmentDate; // The day of the appointment (00:00 time)
  final DateTime bookingTimestamp; // When they actually clicked "Book"
  final int tokenNumber; // Sequential number for that day/clinic
  AppointmentStatus status;

  // Dynamic fields (not stored, calculated at runtime)
  DateTime? estimatedTime;

  Appointment({
    required this.id,
    required this.clinicId,
    required this.customerName,
    required this.phoneNumber,
    required this.serviceType,
    required this.appointmentDate,
    required this.bookingTimestamp,
    required this.tokenNumber,
    this.status = AppointmentStatus.waiting,
  });

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'serviceType': serviceType,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'bookingTimestamp': Timestamp.fromDate(bookingTimestamp),
      'tokenNumber': tokenNumber,
      'status': status.name,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String docId) {
    return Appointment(
      id: docId,
      clinicId: map['clinicId'] ?? '',
      customerName: map['customerName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      serviceType: map['serviceType'] ?? '',
      appointmentDate: (map['appointmentDate'] as Timestamp).toDate(),
      bookingTimestamp: (map['bookingTimestamp'] as Timestamp).toDate(),
      tokenNumber: map['tokenNumber'] ?? 0,
      status: AppointmentStatus.values.firstWhere(
              (e) => e.name == map['status'], orElse: () => AppointmentStatus.waiting),
    );
  }
}