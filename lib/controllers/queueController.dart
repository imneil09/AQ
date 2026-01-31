import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/appoinmentModel.dart';
import '../models/clinicModel.dart';

class QueueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Constants ---
  static const List<String> serviceCategories = [
    'New Consultation',
    'Reports Show',
    'Follow up',
    'Fracture check',
    'Post Op Care',
    'General Inquiry',
    'Other'
  ];

  List<Clinic> clinics = [];
  List<Appointment> _todayQueue = [];
  Clinic? selectedClinic;

  // Search States
  String _liveSearchQuery = "";
  String _historySearchQuery = "";
  String get liveSearchQuery => _liveSearchQuery;
  String get historySearchQuery => _historySearchQuery;

  QueueController() {
    _fetchClinics();
  }

  void updateLiveSearch(String query) {
    _liveSearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void updateHistorySearch(String query) {
    _historySearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  // --- Clinic Management ---

  void _fetchClinics() {
    _db.collection('clinics').snapshots().listen((snapshot) {
      clinics = snapshot.docs
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
    final user = _auth.currentUser;
    Map<String, dynamic> data = clinic.toMap();
    if (user != null) data['doctorId'] = user.uid;
    await _db.collection('clinics').add(data);
  }

  // --- QUEUE ACTIONS ---

  Future<void> recallPatient(String id) async {
    await _db.collection('appointments').doc(id).update({
      'status': AppointmentStatus.waiting.name,
    });
  }

  // Update status (Used for Next, Skip, Cancel, and "Call In")
  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({
      'status': newStatus.name,
    });
  }

  // --- EMERGENCY CLOSE ---
  Future<void> emergencyClose() async {
    if (selectedClinic == null) return;
    WriteBatch batch = _db.batch();

    final todaySnap = await _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .where('status', whereIn: ['waiting', 'active', 'skipped'])
        .get();

    final futureSnap = await _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .where('appointmentDate', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .get();

    for (var doc in [...todaySnap.docs, ...futureSnap.docs]) {
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }

    await batch.commit();
    notifyListeners();
  }

  // --- AUTOMATIC CLEANUP ---
  Future<void> autoCleanup() async {
    if (selectedClinic == null) return;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final leftovers = await _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .where('appointmentDate', isLessThan: Timestamp.fromDate(todayStart))
        .where('status', whereIn: ['waiting', 'skipped', 'active'])
        .get();

    if (leftovers.docs.isEmpty) return;
    WriteBatch batch = _db.batch();
    for (var doc in leftovers.docs) {
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }
    await batch.commit();
  }

  // --- Live Queue Logic ---
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
      _todayQueue = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  // --- History Streams (With Search) ---

  /// Stream for Customer: Returns all appointments linked to their phone number
  Stream<List<Appointment>> get customerHistory {
    final user = _auth.currentUser;
    if (user == null || user.phoneNumber == null) return Stream.value([]);

    return _db
        .collection('appointments')
        .where('phoneNumber', isEqualTo: user.phoneNumber)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => Appointment.fromMap(d.data(), d.id)).toList();
      if (_historySearchQuery.isEmpty) return list;
      return list.where((a) =>
      a.customerName.toLowerCase().contains(_historySearchQuery) ||
          a.serviceType.toLowerCase().contains(_historySearchQuery)
      ).toList();
    });
  }

  /// Stream for Admin: Returns all appointments (Doctor History - All Patients)
  Stream<List<Appointment>> get adminFullHistory {
    if (selectedClinic == null) return Stream.value([]);

    return _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .orderBy('appointmentDate', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => Appointment.fromMap(d.data(), d.id)).toList();
      if (_historySearchQuery.isEmpty) return list;
      return list.where((a) =>
      a.customerName.toLowerCase().contains(_historySearchQuery) ||
          a.phoneNumber.contains(_historySearchQuery) ||
          a.tokenNumber.toString().contains(_historySearchQuery)
      ).toList();
    });
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

    DateTime rollingTime = DateTime(now.year, now.month, now.day, startHour, startMin);

    return _todayQueue.map((appt) {
      final calculatedAppt = Appointment(
        id: appt.id,
        clinicId: appt.clinicId,
        doctorId: appt.doctorId,
        customerName: appt.customerName,
        phoneNumber: appt.phoneNumber,
        serviceType: appt.serviceType,
        type: appt.type,
        appointmentDate: appt.appointmentDate,
        bookingTimestamp: appt.bookingTimestamp,
        tokenNumber: appt.tokenNumber,
        status: appt.status,
      );

      if (calculatedAppt.status == AppointmentStatus.completed ||
          calculatedAppt.status == AppointmentStatus.skipped) {
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      } else if (calculatedAppt.status == AppointmentStatus.active) {
        calculatedAppt.estimatedTime = now;
        rollingTime = now.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      } else if (calculatedAppt.status == AppointmentStatus.waiting) {
        if (rollingTime.isBefore(now)) rollingTime = now;
        calculatedAppt.estimatedTime = rollingTime;
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      }
      return calculatedAppt;
    }).toList();
  }

  // Helper to apply search to the *calculated* queue
  List<Appointment> get _searchedCalculatedQueue {
    if (_liveSearchQuery.isEmpty) return calculatedQueue;
    return calculatedQueue.where((a) =>
    a.customerName.toLowerCase().contains(_liveSearchQuery) ||
        a.phoneNumber.contains(_liveSearchQuery) ||
        a.tokenNumber.toString().contains(_liveSearchQuery)
    ).toList();
  }

  // Expose lists based on the *Searched* queue so UI updates correctly
  List<Appointment> get waitingList => _searchedCalculatedQueue.where((a) => a.status == AppointmentStatus.waiting).toList();
  List<Appointment> get activeQueue => _searchedCalculatedQueue.where((a) => a.status == AppointmentStatus.active).toList();
  List<Appointment> get skippedList => _searchedCalculatedQueue.where((a) => a.status == AppointmentStatus.skipped).toList();

  Future<void> bookAppointment({
    required String name,
    required String phone,
    required String service,
    required DateTime date,
    required String clinicId,
  }) async {
    final cleanDate = DateTime(date.year, date.month, date.day);

    try {
      final qSnap = await _db
          .collection('appointments')
          .where('clinicId', isEqualTo: clinicId)
          .where('appointmentDate', isEqualTo: Timestamp.fromDate(cleanDate))
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
        doctorId: '',
        customerName: name,
        phoneNumber: phone,
        serviceType: service,
        type: 'live',
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

  Appointment? get myAppointment {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      if (user.email != null && user.email!.isNotEmpty) return null;
      return _todayQueue.firstWhere((a) => a.phoneNumber == user.phoneNumber);
    } catch (e) {
      return null;
    }
  }
}