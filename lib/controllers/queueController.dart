import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/appoinmentModel.dart';
import '../models/clinicModel.dart';

class QueueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Clinic> clinics = [];
  List<Appointment> _todayQueue = [];
  Clinic? selectedClinic;

  QueueController() {
    _fetchClinics();
  }

  // --- Clinic Management ---

  void _fetchClinics() {
    _db.collection('clinics').snapshots().listen((snapshot) {
      clinics = snapshot.docs.map((doc) => Clinic.fromMap(doc.data(), doc.id)).toList();
      // Auto-select first clinic if none selected
      if (selectedClinic == null && clinics.isNotEmpty) {
        selectClinic(clinics.first);
      }
      notifyListeners();
    });
  }

  void selectClinic(Clinic clinic) {
    selectedClinic = clinic;
    _listenToQueue(clinic.id);
    notifyListeners();
  }

  Future<void> addClinic(Clinic clinic) async {
    await _db.collection('clinics').add(clinic.toMap());
  }

  // --- Queue Logic ---

  void _listenToQueue(String clinicId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Listens to ANY appointment scheduled for "today"
    _db.collection('appointments')
        .where('clinicId', isEqualTo: clinicId)
        .where('appointmentDate', isEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('tokenNumber')
        .snapshots()
        .listen((snapshot) {
      _todayQueue = snapshot.docs.map((doc) => Appointment.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    });
  }

  // Returns queue with dynamically calculated "Estimated Times"
  List<Appointment> get calculatedQueue {
    if (selectedClinic == null) return [];

    final dayName = DateFormat('EEEE').format(DateTime.now());
    final schedule = selectedClinic!.weeklySchedule[dayName];

    // If clinic is closed today, just return list without times
    if (schedule == null || !schedule.isOpen) return _todayQueue;

    final timeParts = schedule.startTime.split(':');
    final startHour = int.parse(timeParts[0]);
    final startMin = int.parse(timeParts[1]);

    final now = DateTime.now();
    // Base start time for the clinic today
    DateTime rollingTime = DateTime(now.year, now.month, now.day, startHour, startMin);

    for (var appt in _todayQueue) {
      // If completed/missed, they consume a time slot
      if (appt.status == AppointmentStatus.completed || appt.status == AppointmentStatus.missed) {
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      }
      // If in progress, the NEXT slot starts after this one finishes
      else if (appt.status == AppointmentStatus.inProgress) {
        appt.estimatedTime = DateTime.now(); // Currently serving
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      }
      // If waiting, they get the current rolling time
      else if (appt.status == AppointmentStatus.waiting) {
        appt.estimatedTime = rollingTime;
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      }
    }
    return _todayQueue;
  }

  // --- Booking Actions ---

  Future<void> bookAppointment({
    required String name,
    required String phone,
    required String service,
    required DateTime date,
    required String clinicId,
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);

    // Get last token for that specific date & clinic
    final qSnap = await _db.collection('appointments')
        .where('clinicId', isEqualTo: clinicId)
        .where('appointmentDate', isEqualTo: Timestamp.fromDate(cleanDate))
        .orderBy('tokenNumber', descending: true)
        .limit(1)
        .get();

    int nextToken = 1;
    if (qSnap.docs.isNotEmpty) {
      nextToken = qSnap.docs.first.data()['tokenNumber'] + 1;
    }

    final newAppt = Appointment(
      id: '',
      clinicId: clinicId,
      customerName: name,
      phoneNumber: phone,
      serviceType: service,
      appointmentDate: cleanDate,
      bookingTimestamp: DateTime.now(),
      tokenNumber: nextToken,
      status: AppointmentStatus.waiting,
    );

    // FIX: Use .add() to create a NEW unique document.
    // This prevents overwriting the user's previous history.
    // We add the userId to the data map so we can query it later if needed.
    Map<String, dynamic> data = newAppt.toMap();
    if (_auth.currentUser != null) {
      data['userId'] = _auth.currentUser!.uid;
    }

    await _db.collection('appointments').add(data);
  }

  // --- Admin Actions ---

  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({'status': newStatus.name});
  }

  Future<void> adminAddWalkIn(String name, String phone, String service) async {
    if (selectedClinic == null) return;
    await bookAppointment(
      name: name,
      phone: phone,
      service: service,
      date: DateTime.now(), // Walk-in is always today
      clinicId: selectedClinic!.id,
    );
  }

  // --- Helpers ---
  List<Appointment> get waitingList => calculatedQueue.where((a) => a.status == AppointmentStatus.waiting).toList();
  List<Appointment> get activeQueue => calculatedQueue.where((a) => a.status == AppointmentStatus.inProgress).toList();
  List<Appointment> get skippedList => calculatedQueue.where((a) => a.status == AppointmentStatus.missed).toList();

  Appointment? get myAppointment {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // FIX: Since we now use .add() (random IDs), we match by Phone Number.
      // This is robust because AuthView verifies the phone number.
      return _todayQueue.firstWhere(
            (a) => a.phoneNumber == user.phoneNumber,
      );
    } catch (e) {
      return null;
    }
  }
}