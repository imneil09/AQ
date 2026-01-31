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
  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  QueueController() {
    _fetchClinics();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

// Add this helper method to filter any list by phone number
  List<Appointment> filterBySearch(List<Appointment> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((appt) => appt.phoneNumber.contains(_searchQuery)).toList();
  }

  // --- Clinic Management ---

  void _fetchClinics() {
    _db.collection('clinics').snapshots().listen((snapshot) {
      clinics =
          snapshot.docs
              .map((doc) => Clinic.fromMap(doc.data(), doc.id))
              .toList();
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
    // Ensuring the doctorId is linked to the current logged-in user
    final user = _auth.currentUser;
    Map<String, dynamic> data = clinic.toMap();
    if (user != null) data['doctorId'] = user.uid;

    await _db.collection('clinics').add(data);
  }

  // --- RECALL PATIENT ---
  Future<void> recallPatient(String id) async {
    await _db.collection('appointments').doc(id).update({
      'status': AppointmentStatus.waiting.name,
    });
  }

  // --- EMERGENCY CLOSE ---
  Future<void> emergencyClose() async {
    if (selectedClinic == null) return;
    WriteBatch batch = _db.batch();

    // 1. Cancel Today's Queue
    final todaySnap =
        await _db
            .collection('appointments')
            .where('clinicId', isEqualTo: selectedClinic!.id)
            .where('status', whereIn: ['waiting', 'active', 'skipped'])
            .get();

    // 2. Cancel All Future Appointments
    final futureSnap =
        await _db
            .collection('appointments')
            .where('clinicId', isEqualTo: selectedClinic!.id)
            .where(
              'appointmentDate',
              isGreaterThan: Timestamp.fromDate(DateTime.now()),
            )
            .get();

    for (var doc in [...todaySnap.docs, ...futureSnap.docs]) {
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }

    await batch.commit();
    notifyListeners();
  }

  // --- AUTOMATIC MIDNIGHT CLEANUP ---
  // Run this whenever the Doctor Dashboard loads
  Future<void> autoCleanup() async {
    if (selectedClinic == null) return;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final leftovers =
        await _db
            .collection('appointments')
            .where('clinicId', isEqualTo: selectedClinic!.id)
            .where(
              'appointmentDate',
              isLessThan: Timestamp.fromDate(todayStart),
            )
            .where('status', whereIn: ['waiting', 'skipped', 'active'])
            .get();

    if (leftovers.docs.isEmpty) return;
    WriteBatch batch = _db.batch();
    for (var doc in leftovers.docs) {
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }
    await batch.commit();
  }

  Stream<List<Appointment>> get customerHistory {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db.collection('appointments')
        .where('phoneNumber', isEqualTo: user.phoneNumber) // Private filter
        .where('status', whereIn: ['completed', 'cancelled']) // Only final states
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Appointment.fromMap(d.data(), d.id)).toList());
  }

  // --- Live Queue Logic (Today Only) ---

  void _listenToQueue(String clinicId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    _db
        .collection('appointments')
        .where('clinicId', isEqualTo: clinicId)
        .where('appointmentDate', isEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('tokenNumber')
        .snapshots()
        .listen((snapshot) {
          _todayQueue =
              snapshot.docs
                  .map((doc) => Appointment.fromMap(doc.data(), doc.id))
                  .toList();
          notifyListeners();
        });
  }

  // --- History Streams (All Time) ---

  /// Stream for Customer: Returns all appointments linked to their phone number
  Stream<List<Appointment>> get customerHistory {
    final user = _auth.currentUser;
    if (user == null || user.phoneNumber == null) return Stream.value([]);

    return _db
        .collection('appointments')
        .where('phoneNumber', isEqualTo: user.phoneNumber)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => Appointment.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Stream for Admin: Returns all appointments for the selected clinic
  Stream<List<Appointment>> get adminFullHistory {
    if (selectedClinic == null) return Stream.value([]);

    return _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => Appointment.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  // --- UI Helpers & Time Calculations ---

  List<Appointment> get calculatedQueue {
    if (selectedClinic == null) return [];

    final dayName = DateFormat('EEEE').format(DateTime.now());
    final schedule = selectedClinic!.weeklySchedule[dayName];

    if (schedule == null || !schedule.isOpen) return _todayQueue;

    final parts = schedule.startTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMin = int.parse(parts[1]);
    final now = DateTime.now();

    DateTime rollingTime = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMin,
    );

    // FIX: Create a new list to avoid mutating the original stream data
    return _todayQueue.map((appt) {
      // Clone the appointment to avoid side effects
      final calculatedAppt = Appointment(
        id: appt.id,
        clinicId: appt.clinicId,
        customerName: appt.customerName,
        phoneNumber: appt.phoneNumber,
        serviceType: appt.serviceType,
        appointmentDate: appt.appointmentDate,
        bookingTimestamp: appt.bookingTimestamp,
        tokenNumber: appt.tokenNumber,
        status: appt.status,
      );

      if (calculatedAppt.status == AppointmentStatus.completed ||
          calculatedAppt.status == AppointmentStatus.missed) {
        rollingTime = rollingTime.add(
          Duration(minutes: schedule.avgConsultationTimeMinutes),
        );
      } else if (calculatedAppt.status == AppointmentStatus.inProgress) {
        calculatedAppt.estimatedTime = now;
        rollingTime = now.add(
          Duration(minutes: schedule.avgConsultationTimeMinutes),
        );
      } else if (calculatedAppt.status == AppointmentStatus.waiting) {
        if (rollingTime.isBefore(now)) rollingTime = now;
        calculatedAppt.estimatedTime = rollingTime;
        rollingTime = rollingTime.add(
          Duration(minutes: schedule.avgConsultationTimeMinutes),
        );
      }
      return calculatedAppt;
    }).toList();
  }

  Future<void> bookAppointment({
    required String name,
    required String phone,
    required String service,
    required DateTime date,
    required String clinicId,
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);

    try {
      // Get last token for that specific date & clinic
      final qSnap =
          await _db
              .collection('appointments')
              .where('clinicId', isEqualTo: clinicId)
              .where(
                'appointmentDate',
                isEqualTo: Timestamp.fromDate(cleanDate),
              )
              .orderBy('tokenNumber', descending: true)
              .limit(1)
              .get();

      int nextToken = 1;
      if (qSnap.docs.isNotEmpty) {
        nextToken = (qSnap.docs.first.data()['tokenNumber'] as int) + 1;
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

      Map<String, dynamic> data = newAppt.toMap();
      if (_auth.currentUser != null) {
        data['userId'] = _auth.currentUser!.uid;
      }

      await _db.collection('appointments').add(data);
    } catch (e) {
      debugPrint("Error booking appointment: $e");
      rethrow;
    }
  }

  // --- Admin Actions ---

  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({
      'status': newStatus.name,
    });
  }

  Future<void> adminAddWalkIn(String name, String phone, String service) async {
    if (selectedClinic == null) return;
    await bookAppointment(
      name: name,
      phone: phone,
      service: service,
      date: DateTime.now(),
      clinicId: selectedClinic!.id,
    );
  }

  // --- Helpers ---
  List<Appointment> get waitingList =>
      calculatedQueue
          .where((a) => a.status == AppointmentStatus.waiting)
          .toList();
  List<Appointment> get activeQueue =>
      calculatedQueue
          .where((a) => a.status == AppointmentStatus.inProgress)
          .toList();
  List<Appointment> get skippedList =>
      calculatedQueue
          .where((a) => a.status == AppointmentStatus.missed)
          .toList();

  Appointment? get myAppointment {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // If user has email, they are an admin.
      if (user.email != null && user.email!.isNotEmpty) {
        // Admin view doesn't typically "join" their own live queue,
        // but this protects the code from crashing.
        return null;
      }

      // Customer fallback using verified phone number
      return _todayQueue.firstWhere((a) => a.phoneNumber == user.phoneNumber);
    } catch (e) {
      return null;
    }
  }
}
