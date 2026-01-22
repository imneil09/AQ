import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  waiting,    // Active in line
  inProgress, // Currently being served
  completed,  // Done
  cancelled,  // Removed
  skipped     // Parked (The "Secret Sauce")
}

class Appointment {
  final String id;
  final String customerName;
  final String phoneNumber;
  final String serviceType;
  final DateTime bookingTime;
  AppointmentStatus status;
  final int estimatedDurationMinutes;
  int skipCount;
  final String? deviceToken; // For Push Notifications

  Appointment({
    required this.id,
    required this.customerName,
    required this.phoneNumber,
    required this.serviceType,
    required this.bookingTime,
    this.status = AppointmentStatus.waiting,
    this.estimatedDurationMinutes = 30,
    this.skipCount = 0,
    this.deviceToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'serviceType': serviceType,
      'bookingTime': Timestamp.fromDate(bookingTime),
      'status': status.name,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'skipCount': skipCount,
      'deviceToken': deviceToken,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map, String docId) {
    return Appointment(
      id: docId,
      customerName: map['customerName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      serviceType: map['serviceType'] ?? '',
      bookingTime: (map['bookingTime'] as Timestamp).toDate(),
      status: AppointmentStatus.values.firstWhere(
              (e) => e.name == map['status'],
          orElse: () => AppointmentStatus.waiting),
      estimatedDurationMinutes: map['estimatedDurationMinutes'] ?? 30,
      skipCount: map['skipCount'] ?? 0,
      deviceToken: map['deviceToken'],
    );
  }
}