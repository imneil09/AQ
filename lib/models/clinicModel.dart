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
      'weeklySchedule': weeklySchedule.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  factory Clinic.fromMap(Map<String, dynamic> map, String id) {
    return Clinic(
      id: id,
      doctorId: map['doctorId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      weeklySchedule: (map['weeklySchedule'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, ClinicSchedule.fromMap(v)),
      ) ?? {},
    );
  }
}

class ClinicSchedule {
  final bool isOpen;
  final String startTime; // Format "HH:mm" (e.g., "17:00")
  final int avgConsultationTimeMinutes;

  ClinicSchedule({
    required this.isOpen,
    required this.startTime,
    required this.avgConsultationTimeMinutes,
  });

  Map<String, dynamic> toMap() => {
    'isOpen': isOpen,
    'startTime': startTime,
    'avgConsultationTimeMinutes': avgConsultationTimeMinutes,
  };

  factory ClinicSchedule.fromMap(Map<String, dynamic> map) {
    return ClinicSchedule(
      isOpen: map['isOpen'] ?? false,
      startTime: map['startTime'] ?? "09:00",
      avgConsultationTimeMinutes: map['avgConsultationTimeMinutes'] ?? 15,
    );
  }
}