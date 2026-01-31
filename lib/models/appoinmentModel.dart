enum AppointmentStatus { waiting, active, skipped, completed, cancelled }

class Appointment {
  final String id;
  final String clinicId;
  final String doctorId; // Added for Global Doctor History
  final String customerName;
  final String phoneNumber;
  final String serviceType;
  final String type; // "live" or "appointment"
  final DateTime appointmentDate;
  final DateTime bookingTimestamp;
  final int tokenNumber;
  AppointmentStatus status;
  DateTime? estimatedTime;

  Appointment({
    required this.id,
    required this.clinicId,
    required this.doctorId,
    required this.customerName,
    required this.phoneNumber,
    required this.serviceType,
    required this.type,
    required this.appointmentDate,
    required this.bookingTimestamp,
    required this.tokenNumber,
    this.status = AppointmentStatus.waiting,
  });

  Map<String, dynamic> toMap() {
    return {
      'clinicId': clinicId,
      'doctorId': doctorId,
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
    return Appointment(
      id: docId,
      clinicId: map['clinicId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      customerName: map['customerName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      serviceType: map['serviceType'] ?? '',
      type: map['type'] ?? 'live',
      appointmentDate: (map['appointmentDate'] as Timestamp).toDate(),
      bookingTimestamp: (map['bookingTimestamp'] as Timestamp).toDate(),
      tokenNumber: map['tokenNumber'] ?? 0,
      status: AppointmentStatus.values.firstWhere(
              (e) => e.name == map['status'], orElse: () => AppointmentStatus.waiting),
    );
  }
}