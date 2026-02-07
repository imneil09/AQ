import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/appoinmentModel.dart';
import '../models/clinicModel.dart';

class QueueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- State Variables ---
  List<Clinic> clinics = [];
  List<Appointment> _todayQueue = [];
  Clinic? selectedClinic;

  // Doctor Status
  bool _isOnBreak = false; // "Tea Break" state

  // Search States
  String _liveSearchQuery = "";
  String _historySearchQuery = "";

  // Getters
  String get liveSearchQuery => _liveSearchQuery;
  String get historySearchQuery => _historySearchQuery;
  bool get isOnBreak => _isOnBreak;

  QueueController() {
    _fetchClinics();
    _runAutoCleanup();
  }

  // --- Doctor Actions ---

  void toggleBreak() {
    _isOnBreak = !_isOnBreak;
    notifyListeners();
  }

  /// LOGOUT ACTION
  Future<void> logout() async {
    // We sign out from Firebase.
    // The View is responsible for navigating to AuthView immediately after awaiting this.
    await _auth.signOut();
    notifyListeners();
  }

  // --- Search Logic ---
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
    _runAutoCleanup();
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

  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({
      'status': newStatus.name,
    });
  }

  Future<void> emergencyClose() async {
    if (selectedClinic == null) return;
    WriteBatch batch = _db.batch();

    final activeSnap = await _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .where('status', whereIn: ['waiting', 'active', 'skipped'])
        .get();

    for (var doc in activeSnap.docs) {
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }

    await batch.commit();
    notifyListeners();
  }

  Future<void> _runAutoCleanup() async {
    if (selectedClinic == null) return;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final leftovers = await _db
        .collection('appointments')
        .where('clinicId', isEqualTo: selectedClinic!.id)
        .where('appointmentDate', isLessThan: Timestamp.fromDate(todayStart))
        .where('status', whereIn: ['waiting', 'skipped', 'active'])
        .get();

    if (leftovers.docs.isNotEmpty) {
      WriteBatch batch = _db.batch();
      for (var doc in leftovers.docs) {
        batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
      }
      await batch.commit();
    }
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

      var rawList = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .toList();

      _todayQueue = _calculateEstimatedTimes(rawList);
      notifyListeners();
    });
  }

  List<Appointment> _calculateEstimatedTimes(List<Appointment> list) {
    if (selectedClinic == null) return list;

    final dayName = DateFormat('EEEE').format(DateTime.now());
    final schedule = selectedClinic!.weeklySchedule[dayName];

    if (schedule == null || !schedule.isOpen) return list;

    final parts = schedule.startTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMin = int.parse(parts[1]);
    final now = DateTime.now();

    DateTime rollingTime = DateTime(now.year, now.month, now.day, startHour, startMin);
    if (rollingTime.isBefore(now)) rollingTime = now;

    // Delay estimates if on break
    if (_isOnBreak) {
      rollingTime = rollingTime.add(const Duration(minutes: 15));
    }

    return list.map((appt) {
      final newAppt = Appointment(
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

      if (newAppt.status == AppointmentStatus.active) {
        newAppt.estimatedTime = now;
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      } else if (newAppt.status == AppointmentStatus.waiting) {
        newAppt.estimatedTime = rollingTime;
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      }
      return newAppt;
    }).toList();
  }

  // --- UI Helpers ---

  List<Appointment> get _searchedQueue {
    if (_liveSearchQuery.isEmpty) return _todayQueue;
    return _todayQueue.where((a) =>
    a.customerName.toLowerCase().contains(_liveSearchQuery) ||
        a.phoneNumber.contains(_liveSearchQuery) ||
        a.tokenNumber.toString().contains(_liveSearchQuery)
    ).toList();
  }

  List<Appointment> get waitingList => _searchedQueue.where((a) => a.status == AppointmentStatus.waiting).toList();
  List<Appointment> get activeQueue => _searchedQueue.where((a) => a.status == AppointmentStatus.active).toList();
  List<Appointment> get skippedList => _searchedQueue.where((a) => a.status == AppointmentStatus.skipped).toList();

  // --- Booking Logic ---

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

  Future<void> assistantAddWalkIn(String name, String phone, String service) async {
    if (selectedClinic == null) return;
    await bookAppointment(
      name: name,
      phone: phone,
      service: service,
      date: DateTime.now(),
      clinicId: selectedClinic!.id,
    );
  }

  // --- History Streams ---
  Stream<List<Appointment>> get patientHistory {
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

  Stream<List<Appointment>> get assistantFullHistory {
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