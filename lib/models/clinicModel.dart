// lib/models/clinicModel.dart

class Clinic {
  final String id;
  final String doctorId;
  final String name;
  final String address;
  final Map<String, ClinicSchedule> weeklySchedule;

  Clinic({
    required this.id,
    required this.doctorId,
    required this.name,
    required this.address,
    required this.weeklySchedule,
  });

  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'name': name,
      'address': address,
      'weeklySchedule': weeklySchedule.map(
            (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }

  factory Clinic.fromMap(Map<String, dynamic> map, String id) {
    return Clinic(
      id: id,
      doctorId: map['doctorId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      weeklySchedule: (map['weeklySchedule'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, ClinicSchedule.fromMap(v as Map<String, dynamic>)),
      ) ??
          {},
    );
  }
}

class ClinicSchedule {
  final bool isOpen;
  final String startTime;
  final int avgConsultationTimeMinutes;
  final int maxAppointmentsPerDay;

  ClinicSchedule({
    required this.isOpen,
    required this.startTime,
    this.avgConsultationTimeMinutes = 10, // Default 10 min
    required this.maxAppointmentsPerDay,
  });

  Map<String, dynamic> toMap() => {
    'isOpen': isOpen,
    'startTime': startTime,
    'avgConsultationTimeMinutes': avgConsultationTimeMinutes,
    'maxAppointmentsPerDay': maxAppointmentsPerDay,
  };

  factory ClinicSchedule.fromMap(Map<String, dynamic> map) {
    return ClinicSchedule(
      isOpen: map['isOpen'] ?? false,
      startTime: map['startTime'] ?? "09:00",
      avgConsultationTimeMinutes: map['avgConsultationTimeMinutes'] ?? 10,
      maxAppointmentsPerDay: map['maxAppointmentsPerDay'] ?? 20,
    );
  }
}