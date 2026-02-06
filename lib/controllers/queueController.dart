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

  // Search States
  String _liveSearchQuery = "";
  String _historySearchQuery = "";

  // Getters for Search
  String get liveSearchQuery => _liveSearchQuery;
  String get historySearchQuery => _historySearchQuery;

  QueueController() {
    _fetchClinics();
    // Run cleanup on startup to handle any leftovers from yesterday immediately
    _runAutoCleanup();
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
    _runAutoCleanup(); // Ensure cleanup runs when switching clinics
    notifyListeners();
  }

  Future<void> addClinic(Clinic clinic) async {
    final user = _auth.currentUser;
    Map<String, dynamic> data = clinic.toMap();
    if (user != null) data['doctorId'] = user.uid;
    await _db.collection('clinics').add(data);
  }

  // --- QUEUE ACTIONS (Recall, Status, Emergency) ---

  /// RECALL: Moves a skipped patient back to 'waiting'.
  /// Since the list is sorted by Token Number, and the recalled patient has an
  /// earlier token than current waiting patients, they will automatically appear
  /// at the TOP of the waiting list.
  Future<void> recallPatient(String id) async {
    await _db.collection('appointments').doc(id).update({
      'status': AppointmentStatus.waiting.name,
    });
  }

  /// UPDATE STATUS: Handles moving between Waiting -> Active -> Completed/Skipped
  Future<void> updateStatus(String id, AppointmentStatus newStatus) async {
    await _db.collection('appointments').doc(id).update({
      'status': newStatus.name,
    });
  }

  /// EMERGENCY CLOSE: Cancels all 'active', 'waiting', or 'skipped' for today
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

  /// AUTO CLEANUP: Runs invisibly.
  /// Finds any appointment strictly BEFORE today (12:00 AM) that is still open
  /// (waiting/active/skipped) and marks it as Cancelled.
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
      debugPrint("Auto-Cleanup: Cancelled ${leftovers.docs.length} expired appointments.");
    }
  }

  // --- Live Queue Logic ---

  void _listenToQueue(String clinicId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Queries appointments where appointmentDate == TODAY.
    // This includes appointments booked days ago for today ("earlier appointment").
    _db
        .collection('appointments')
        .where('clinicId', isEqualTo: clinicId)
        .where('appointmentDate', isEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('tokenNumber') // Ensures Recalled (lower token) are at top
        .snapshots()
        .listen((snapshot) {

      var rawList = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .toList();

      // Calculate Estimated Time locally
      _todayQueue = _calculateEstimatedTimes(rawList);

      notifyListeners();
    });
  }

  List<Appointment> _calculateEstimatedTimes(List<Appointment> list) {
    if (selectedClinic == null) return list;

    // Get schedule info
    final dayName = DateFormat('EEEE').format(DateTime.now());
    final schedule = selectedClinic!.weeklySchedule[dayName];

    if (schedule == null || !schedule.isOpen) return list;

    // Parse start time
    final parts = schedule.startTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMin = int.parse(parts[1]);
    final now = DateTime.now();

    // Base rolling time starts at clinic opening or Now (whichever is later)
    DateTime rollingTime = DateTime(now.year, now.month, now.day, startHour, startMin);
    if (rollingTime.isBefore(now)) rollingTime = now;

    return list.map((appt) {
      // Create a copy to modify estimatedTime without mutating original unexpectedly
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
        newAppt.estimatedTime = now; // Active is Now
        // Active patient consumes time
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      } else if (newAppt.status == AppointmentStatus.waiting) {
        newAppt.estimatedTime = rollingTime;
        // Waiting patient consumes time
        rollingTime = rollingTime.add(Duration(minutes: schedule.avgConsultationTimeMinutes));
      }
      // Skipped/Completed/Cancelled do not get a future estimated time
      // and do not add to the rolling time for subsequent waiting patients.

      return newAppt;
    }).toList();
  }

  // --- UI Helpers (Getters) ---

  // Helper to filter the queue based on Search Text
  List<Appointment> get _searchedQueue {
    if (_liveSearchQuery.isEmpty) return _todayQueue;
    return _todayQueue.where((a) =>
    a.customerName.toLowerCase().contains(_liveSearchQuery) ||
        a.phoneNumber.contains(_liveSearchQuery) ||
        a.tokenNumber.toString().contains(_liveSearchQuery)
    ).toList();
  }

  // Public Lists for the TabBarView
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
      // Get the last token number for that specific date to increment
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

  // RENAMED: was adminAddWalkIn
  Future<void> assistantAddWalkIn(String name, String phone, String service) async {
    if (selectedClinic == null) return;
    // Walk-ins are always for Today
    await bookAppointment(
      name: name,
      phone: phone,
      service: service,
      date: DateTime.now(),
      clinicId: selectedClinic!.id,
    );
  }

  // --- History Streams ---

  /// Stream for Patient: Returns all appointments linked to their phone
  // RENAMED: was customerHistory
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

  /// Stream for Assistant/Admin: Returns all appointments for the selected clinic
  // RENAMED: was adminFullHistory
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

  // Helper for "My Visit" in Patient Home
  Appointment? get myAppointment {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      if (user.email != null && user.email!.isNotEmpty) return null; // Doctors don't have "My Visit"
      // Find the first relevant appointment in today's queue
      return _todayQueue.firstWhere((a) => a.phoneNumber == user.phoneNumber);
    } catch (e) {
      return null;
    }
  }
}